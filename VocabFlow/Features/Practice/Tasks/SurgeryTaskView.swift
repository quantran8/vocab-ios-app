import SwiftUI

/// Fix one or more graphemes: select a slot, then tap its replacement on the letter keyboard; the key's
/// letter flies up into the slot and the old one is thrown away. The delete key removes the grapheme.
/// Fixes stay put while other slots are selected; picking the original letter again undoes a fix.
struct SurgeryTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var selectedIndex: Int?
    /// Grapheme index → its fix; "" when the letter is deleted. Slots without an entry keep their letter.
    @State private var fixes: [Int: String] = [:]
    /// The keyboard closes once a key is picked and reopens when the selected slot is tapped again.
    @State private var isKeyboardOpen = true
    /// The slot a letter is flying into; it is a grey stand-in until the letter lands.
    @State private var landingIndex: Int?
    @State private var isSwapping = false
    @State private var frames: [FrameID: CGRect] = [:]
    @State private var flyers: [Flyer] = []

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .surgery(let word, _, _) = attempt.task.body {
                let letters = PracticeAnswer.graphemes(word)
                VStack(spacing: Spacing.l) {
                    HStack(spacing: Self.letterGap) {
                        ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                            letterBox(letter, index: index, total: letters.count)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    // mt-10 below the question (the scaffold already gives 24).
                    .padding(.top, Spacing.m)

                    if selectedIndex != nil, isKeyboardOpen, !attempt.isFinished {
                        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                            Eyebrow(text: "Replace with")
                                .padding(.horizontal, Spacing.xxs)
                            LetterKeyboard(
                                isEnabled: attempt.status == .answering && !isSwapping,
                                onLetter: { pick($0) },
                                onDelete: { pick("") }
                            )
                        }
                        .padding(Spacing.s)
                        .cardSurface()
                        .transition(motion.reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .coordinateSpace(name: Self.space)
                .onPreferenceChange(FramePreference.self) { frames = $0 }
                .overlay(alignment: .topLeading) {
                    ForEach(flyers) { FlyingPiece(flyer: $0) }
                        .allowsHitTesting(false)
                }
            }
        } action: {
            TaskActionBar(
                attempt: attempt,
                checkTitle: "Check fix",
                canCheck: !fixes.isEmpty && !isSwapping,
                onCheck: commitRepair
            )
        }
        .onChange(of: attempt.status) { _, status in
            // On "Try again" the fixes stay, so the learner only changes what was wrong.
            guard status == .answering else { return }
            motion.perform(MotionTokens.snap) {
                selectedIndex = nil
                isKeyboardOpen = true
            }
        }
    }

    private func select(_ index: Int) {
        guard !isSwapping else { return }
        store.answerPicked()
        motion.perform(MotionTokens.snap) {
            if selectedIndex == index {
                // The selected slot toggles the keyboard: closing it deselects, reopening keeps the fix.
                if isKeyboardOpen { selectedIndex = nil } else { isKeyboardOpen = true }
            } else {
                selectedIndex = index
                isKeyboardOpen = true
            }
        }
    }

    /// Throws the slot's current letter away, then flies the tapped key's letter into the slot.
    /// `letter` is "" for the delete key: the slot is left empty.
    private func pick(_ letter: String) {
        guard let index = selectedIndex, !isSwapping, let original = originalLetter(at: index) else { return }
        store.answerPicked()
        let outgoing = fixes[index] ?? original
        // Picking the original letter back undoes the fix.
        let fix: String? = PracticeAnswer.normalize(letter) == PracticeAnswer.normalize(original) && !letter.isEmpty ? nil : letter
        let apply = {
            motion.perform(MotionTokens.snap) {
                fixes[index] = fix
                isKeyboardOpen = false
            }
        }
        guard letter != outgoing else {
            apply()
            return
        }
        guard !motion.reduceMotion, let box = frames[.letter(index)] else {
            apply()
            return
        }
        isSwapping = true
        let center = CGPoint(x: box.midX, y: box.midY)

        if !outgoing.isEmpty {
            // Lobbed up in a parabola: the apex sits well above the box, then it drops away off one side.
            let side: CGFloat = Bool.random() ? 1 : -1
            let lift = CGFloat.random(in: 420...560)
            launch(Flyer(
                letter: outgoing,
                from: center,
                control: CGPoint(x: center.x + side * 260, y: center.y - lift * 2),
                to: CGPoint(x: center.x + side * 640, y: center.y + 80),
                size: box.size,
                spin: Double(side) * Double.random(in: 120...240),
                isThrown: true
            ), for: Self.throwDuration)
        }

        guard !letter.isEmpty, let key = frames[.key(letter)] else {
            apply()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.deleteSettle) { isSwapping = false }
            return
        }
        landingIndex = index
        // The key's frame is already captured, so the keyboard can leave while the letter flies.
        apply()
        let start = CGPoint(x: key.midX, y: key.midY)
        // Rises from the key and arcs over into the slot.
        let incoming = Flyer(
            letter: letter,
            from: start,
            control: CGPoint(x: (start.x + center.x) / 2, y: min(start.y, center.y) - 60),
            to: center,
            size: box.size,
            spin: 0,
            isThrown: false
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.incomingDelay) {
            flyers.append(incoming)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.incomingFlight) {
                landingIndex = nil
                flyers.removeAll { $0.id == incoming.id }
                isSwapping = false
            }
        }
    }

    private func launch(_ flyer: Flyer, for duration: Double) {
        flyers.append(flyer)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            flyers.removeAll { $0.id == flyer.id }
        }
    }

    private func commitRepair() {
        guard !fixes.isEmpty, !isSwapping else { return }
        motion.perform(MotionTokens.snap) { selectedIndex = nil }
        store.submitRepair(edits: fixes)
    }

    private func originalLetter(at index: Int) -> String? {
        guard case .surgery(let word, _, _) = attempt.task.body else { return nil }
        let letters = PracticeAnswer.graphemes(word)
        return letters.indices.contains(index) ? letters[index] : nil
    }

    private static let space = "surgery"
    private static let throwDuration: Double = 0.7
    /// The key's letter leaves just after the old one is thrown, so the two don't overlap in the slot.
    private static let incomingDelay: Double = 0.12
    /// `MotionTokens.snap` mostly settles in this time; the slot then shows the letter for real.
    private static let incomingFlight: Double = 0.42
    private static let deleteSettle: Double = 0.3
    /// A letter box: 38 × 50 at most, 6 pt apart.
    private static let letterWidth: CGFloat = 38
    private static let letterHeight: CGFloat = 50
    private static let letterGap = Spacing.xxs + 2

    private func letterBox(_ letter: String, index: Int, total: Int) -> some View {
        let isSelected = selectedIndex == index
        let fix = fixes[index]
        let isFixed = fix != nil
        let shown = fix ?? letter
        // A deleted slot, or one a letter is landing in, is a grey stand-in like the reorder drop preview.
        let isPlaceholder = landingIndex == index || fix == ""
        let isTinted = isSelected || isFixed
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        return Button {
            select(index)
        } label: {
            Text(verbatim: isPlaceholder ? " " : shown)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(isTinted ? Color.selectedInk : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 2)
                .frame(minWidth: 0, maxWidth: Self.letterWidth, minHeight: Self.letterHeight)
                .background(isPlaceholder ? Color.neutralSurface : (isTinted ? Color.selectedSurface : Color.surface), in: shape)
                .overlay {
                    if isSelected {
                        shape.strokeBorder(Color.interactive, lineWidth: Borders.card)
                    } else if !isPlaceholder {
                        shape.strokeBorder(isFixed ? Color.selectedDepth : Color.stroke, lineWidth: Borders.card)
                    }
                }
                // The selected box gets a 4 pt Blue 100 halo, like a focused field.
                .background {
                    if isSelected {
                        shape.inset(by: -Borders.focusHalo).fill(Color.focusHalo)
                    }
                }
        }
        .buttonStyle(.plain)
        .trackFrame(.letter(index))
        .disabled(attempt.isFinished || attempt.status != .answering || isSwapping)
        .accessibilityLabel(Text("Letter \(index + 1) of \(total), \(shown)"))
        .accessibilityValue(fix == "" ? Text("Deleted") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A QWERTY letter pad for the fix; the last row ends with a delete key that removes the letter.
private struct LetterKeyboard: View {
    let isEnabled: Bool
    let onLetter: (String) -> Void
    let onDelete: () -> Void

    private static let rows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    private static let gap = Spacing.xxs
    private static let rowGap = Spacing.xxs + 2
    private static let keyHeight: CGFloat = 36
    private static let keyRadius: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let columns = CGFloat(Self.rows[0].count)
            let keyWidth = max(0, (proxy.size.width - Self.gap * (columns - 1)) / columns)
            VStack(spacing: Self.rowGap) {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: Self.gap) {
                        ForEach(row, id: \.self) { letter in
                            key(width: keyWidth) {
                                Text(verbatim: letter)
                                    .font(Typography.secondary.weight(.semibold))
                                    .foregroundStyle(Color.ink)
                            } action: {
                                onLetter(letter)
                            }
                            .trackFrame(.key(letter))
                            .accessibilityLabel(Text(verbatim: letter))
                        }
                        if rowIndex == Self.rows.count - 1 {
                            // Two keys wide, the row centered under the others.
                            key(width: keyWidth * 2 + Self.gap, fill: .stroke) {
                                Text("Remove")
                                    .font(Typography.micro.weight(.semibold))
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            } action: {
                                onDelete()
                            }
                            .accessibilityLabel(Text("Delete letter"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: Self.keyHeight * CGFloat(Self.rows.count) + Self.rowGap * CGFloat(Self.rows.count - 1))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }

    /// A flat key: Ink 100 face (the delete key Ink 200), no border or depth.
    private func key<Label: View>(width: CGFloat, fill: Color = .neutralSurface, @ViewBuilder label: () -> Label, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous)
        return Button(action: action) {
            label()
                .frame(width: width, height: Self.keyHeight)
                .background(fill, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private enum FrameID: Hashable {
    case letter(Int)
    case key(String)
}

private struct Flyer: Identifiable {
    let id = UUID()
    let letter: String
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint
    let size: CGSize
    let spin: Double
    /// True for the discarded letter (flies off screen); false for the key's letter flying into the slot.
    let isThrown: Bool
}

private struct FlyingPiece: View {
    let flyer: Flyer
    @State private var arrived = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        // Both pieces wear the selected look: the slot they leave or land in is the selected one.
        Text(verbatim: flyer.letter)
            .font(.system(.title2, design: .monospaced, weight: .bold))
            .foregroundStyle(Color.selectedInk)
            .frame(width: flyer.size.width, height: flyer.size.height)
            .background(Color.selectedSurface, in: shape)
            .overlay(shape.strokeBorder(Color.interactive, lineWidth: Borders.card))
            .scaleEffect(arrived ? (flyer.isThrown ? 1.4 : 1) : (flyer.isThrown ? 1.3 : 0.8))
            .rotationEffect(.degrees(arrived ? flyer.spin : 0))
            .opacity(arrived && flyer.isThrown ? 0 : 1)
            .position(flyer.from)
            .modifier(ArcEffect(progress: arrived ? 1 : 0, from: flyer.from, control: flyer.control, to: flyer.to))
            .onAppear {
                withAnimation(flyer.isThrown ? .easeIn(duration: 0.65) : MotionTokens.snap) { arrived = true }
            }
    }
}

/// Moves a view along a quadratic Bézier from `from` to `to`; `progress` is animatable.
private struct ArcEffect: GeometryEffect {
    var progress: CGFloat
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress, u = 1 - t
        let x = u * u * from.x + 2 * u * t * control.x + t * t * to.x
        let y = u * u * from.y + 2 * u * t * control.y + t * t * to.y
        return ProjectionTransform(CGAffineTransform(translationX: x - from.x, y: y - from.y))
    }
}

private struct FramePreference: PreferenceKey {
    static var defaultValue: [FrameID: CGRect] = [:]
    static func reduce(value: inout [FrameID: CGRect], nextValue: () -> [FrameID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private extension View {
    func trackFrame(_ id: FrameID) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: FramePreference.self, value: [id: proxy.frame(in: .named("surgery"))])
            }
        )
    }
}
