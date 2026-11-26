import SwiftUI

/// `select`. Options keep the backend's order; their ids aren't positions.
struct ChoiceTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @State private var selectedID: Int?
    /// Per option, so only the option just picked wrongly moves.
    @State private var shakes: [Int: CGFloat] = [:]
    @Environment(\.motion) private var motion

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .choice(let options, _, let correct) = attempt.task.body {
                VStack(spacing: Spacing.s) {
                    ForEach(options) { option in
                        ChoiceOptionButton(text: option.text, state: state(option.id, correct: correct)) {
                            selectedID = selectedID == option.id ? nil : option.id
                            store.answerPicked()
                        }
                        .modifier(ShakeEffect(animatableData: shakes[option.id, default: 0]))
                    }
                }
            }
        } action: {
            TaskActionBar(attempt: attempt, canCheck: selectedID != nil) {
                guard let selectedID else { return }
                store.submitOption(selectedID)
                self.selectedID = nil
            }
        }
        .onChange(of: attempt.status) { _, status in
            guard status == .wrong || status == .exhausted, let id = attempt.lastWrongOptionID else { return }
            withAnimation(motion.travel(MotionTokens.shake)) { shakes[id, default: 0] += 1 }
        }
    }

    private func state(_ id: Int, correct: Int) -> WordTileVisualState {
        if attempt.status == .exhausted { return attempt.lastWrongOptionID == id ? .incorrect : .disabled }
        if attempt.isFinished { return id == correct ? .correct : .disabled }
        if attempt.status == .wrong, attempt.lastWrongOptionID == id { return .incorrect }
        return selectedID == id ? .selected : .idle
    }
}

/// A select option: 60 pt, radius 16, 2 pt border and a depth edge; the text sits left and a right or
/// wrong answer gets a ✓ / ✕ at the trailing edge.
private struct ChoiceOptionButton: View {
    let text: String
    let state: WordTileVisualState
    let action: () -> Void
    @Environment(\.motion) private var motion
    @State private var bounce = 0

    var body: some View {
        Button {
            if !motion.reduceMotion { bounce += 1 }
            action()
        } label: {
            EmptyView()
        }
        // A quick tap inside a ScrollView often never reports isPressed, so the tile also sinks on tap.
        .buttonStyle(ChoiceOptionPressStyle(text: text, state: state, bounce: bounce))
        .disabled(state == .disabled || state == .correct)
        .accessibilityLabel(Text("\(text), option"))
        .accessibilityValue(choiceValue)
        .accessibilityAddTraits(state == .selected ? [.isSelected] : [])
    }

    private var choiceValue: Text {
        switch state {
        case .selected: Text("Selected")
        case .correct: Text("Correct")
        case .incorrect: Text("Incorrect, already checked")
        case .disabled: Text("Unavailable")
        default: Text(verbatim: "")
        }
    }
}

/// Drives the option's pressed face while a finger is down on an idle or selected option.
private struct ChoiceOptionPressStyle: ButtonStyle {
    let text: String
    let state: WordTileVisualState
    let bounce: Int

    func makeBody(configuration: Configuration) -> some View {
        let canPress = state == .idle || state == .selected
        ChoiceOptionFace(text: text, state: configuration.isPressed && canPress ? .pressed : state, bounceTrigger: bounce)
    }
}

private struct ChoiceOptionFace: View {
    let text: String
    let state: WordTileVisualState
    /// Each change sinks the face into its depth and springs it back up.
    let bounceTrigger: Int
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        // Read on the main actor; the keyframe content closure is Sendable.
        let faceDrop: CGFloat = state == .pressed ? Spacing.tileDepth - 1 : 0
        Text(verbatim: text)
            // One weight in every state: a bolder face would reflow the text when the tile is picked.
            .font(Typography.choiceOption)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            // The colour switches at once with the tap, not with the tile's lift animation.
            .transaction { $0.animation = nil }
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, minHeight: Spacing.tileMinHeight)
        .background(face, in: shape)
        .overlay(shape.strokeBorder(border, lineWidth: Borders.card))
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: bounceTrigger) { face, sink in
            face.offset(y: min(faceDrop + sink, Spacing.tileDepth - 1))
        } keyframes: { _ in
            CubicKeyframe(Spacing.tileDepth - 1, duration: 0.07)
            SpringKeyframe(0, duration: 0.15, spring: .bouncy(duration: 0.1, extraBounce: 0.05))
        }
        .background(shape.fill(depth).offset(y: Spacing.tileDepth))
        .padding(.bottom, Spacing.tileDepth)
        .contentShape(shape)
        .animation(motion.animation(state == .pressed ? MotionTokens.press : MotionTokens.lift), value: state)
    }

    private var foreground: Color {
        switch state {
        case .correct: .successInk
        case .incorrect: .errorInk
        case .selected, .dragging: .selectedInk
        case .disabled: .disabledInk
        default: .ink
        }
    }

    private var face: Color {
        switch state {
        case .selected, .dragging: .selectedSurface
        case .correct: .successSurface
        case .incorrect: .errorSurface
        default: .surface
        }
    }

    private var depth: Color {
        switch state {
        case .selected: .selectedDepth
        case .correct: .successDepth
        case .incorrect: .errorDepth
        default: .tileDepth
        }
    }

    private var border: Color {
        switch state {
        case .pressed, .selected, .dragging: .interactive
        case .correct: .success
        case .incorrect: .error
        default: .stroke
        }
    }
}
