import SwiftUI

// Controls that replace the iOS defaults (docs/app-redesign-v1.html, "Điều khiển").

// MARK: - Segmented control

/// The iOS segmented control (docs/DESIGN_SYSTEM.md: system controls stay native, tinted only).
struct SegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, title: LocalizedStringKey)]
    @Binding var selection: Value

    var body: some View {
        Picker(selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.title).tag(option.value)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Chips and pills

/// 36 pt selectable chip. Off: 1.5 pt Ink 200 border; on: 2 pt Blue 500 border, Blue 50 fill, Blue 700 text.
struct SelectChip: View {
    let title: Text
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs - 2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                title
                    .font(Typography.secondary.weight(.semibold))
                    .lineLimit(1)
            }
            .chipSurface(isSelected: isSelected)
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// The chip's shape and colours, for chips that aren't plain buttons.
    /// `selectedFill` replaces Blue 50 for chips that sit on a Blue 50 panel.
    func chipSurface(isSelected: Bool, selectedFill: Color = .selectedSurface) -> some View {
        self
            .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
            .padding(.horizontal, Spacing.s + 2)
            .frame(minHeight: Spacing.buttonSmallHeight)
            .background(isSelected ? selectedFill : Color.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.interactive : Color.stroke,
                    lineWidth: isSelected ? Borders.card : Borders.hairline
                )
            )
            .contentShape(Capsule())
    }
}

/// 24 pt status label ("Đã học", "Chưa học", "Cần luyện lại", "Bạn").
struct StatusPill: View {
    enum Tone { case success, neutral, error, accent, accentSolid, reward }

    let text: Text
    var tone: Tone = .neutral
    var systemImage: String?

    init(_ text: Text, tone: Tone = .neutral, systemImage: String? = nil) {
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
    }

    init(_ key: LocalizedStringKey, tone: Tone = .neutral, systemImage: String? = nil) {
        self.init(Text(key), tone: tone, systemImage: systemImage)
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .heavy))
                    .accessibilityHidden(true)
            }
            text.lineLimit(1)
        }
        .font(Typography.caption.weight(.bold))
        .foregroundStyle(colors.fg)
        .padding(.horizontal, Spacing.s - 2)
        .frame(minHeight: 24)
        .background(colors.bg, in: Capsule())
    }

    private var colors: (bg: Color, fg: Color) {
        switch tone {
        case .success: (.green50, .green800)
        case .neutral: (.ink100, .ink600)
        case .error: (.coral50, .coral800)
        case .accent: (.blue50, .blue700)
        case .accentSolid: (.blue500, .white)
        case .reward: (.sun50, .sun800)
        }
    }
}

// MARK: - Icons

/// 36 pt round Ink 100 button (back, close, settings), inside a 44 pt touch target.
struct IconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = Spacing.iconButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconButtonLabel(systemImage: systemImage, size: size)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(label))
    }
}

struct IconButtonLabel: View {
    let systemImage: String
    var size: CGFloat = Spacing.iconButton

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Color.ink800)
            .frame(width: size, height: size)
            .background(Color.neutralSurface, in: Circle())
            .frame(width: max(size, Spacing.minTouchTarget), height: max(size, Spacing.minTouchTarget))
            .contentShape(Rectangle())
    }
}

/// 40 pt rounded-square icon on a tinted fill, leading a row or card.
struct IconBadge: View {
    enum Tone { case neutral, accent, success, error, reward, onAccent }

    let systemImage: String
    var tone: Tone = .neutral
    var size: CGFloat = Spacing.iconBadge

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(colors.fg)
            .frame(width: size, height: size)
            .background(colors.bg, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
            .accessibilityHidden(true)
    }

    private var colors: (bg: Color, fg: Color) {
        switch tone {
        case .neutral: (.ink50, .ink700)
        case .accent: (.blue50, .blue600)
        case .success: (.green50, .green700)
        case .error: (.coral50, .coral600)
        case .reward: (.sun50, .sun600)
        case .onAccent: (.white, .blue600)
        }
    }
}

/// Round selection mark: a filled Blue check when on, an Ink 300 ring when off.
struct SelectionMark: View {
    let isOn: Bool

    var body: some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(isOn ? Color.interactive : Color.ink300)
            .symbolReplace(value: isOn)
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }
}

// MARK: - Titles

/// 34 pt extrabold screen title (one per screen).
struct ScreenTitle: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(Typography.display)
            .tracking(Typography.displayTracking)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 26 pt extrabold sheet title.
struct SheetTitle: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(Typography.sheetTitle)
            .tracking(Typography.sheetTracking)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 19 pt bold section header with an optional trailing link or label.
struct SectionTitle<Trailing: View>: View {
    let text: Text
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            text
                .font(Typography.sectionTitle)
                .tracking(Typography.tightTracking / 2)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.s)
            trailing
        }
        .staticLabelRow()
        .padding(.bottom, Spacing.s)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ key: LocalizedStringKey) {
        self.init(text: Text(key)) { EmptyView() }
    }
}

extension SectionTitle {
    init(_ key: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.init(text: Text(key), trailing: trailing)
    }
}

/// A 15 pt semibold Blue 600 text action ("Sửa", "Chọn tất cả").
struct TextLink: View {
    let title: LocalizedStringKey
    var color: Color = .link
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(color)
                .frame(minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// A header row whose text swaps ("Select all" ⇄ "Clear all", "3/12") snaps instead of fading and sliding
    /// with the caller's animation, which is meant for the content below. See memory no-text-label-animation.
    func staticLabelRow() -> some View {
        transaction { $0.animation = nil }
    }
}

// MARK: - Rows, dividers, fields

/// ⓘ beside a label: the explanation opens in a 280 pt popover, like "Today’s lesson" on Home, so rows keep
/// a single line instead of a subtitle. Full 44 pt touch target without making the row taller.
struct InfoPopoverButton: View {
    let text: LocalizedStringKey
    let accessibilityLabel: LocalizedStringKey
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "info.circle")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.mutedInk)
                .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -Spacing.s)
        .accessibilityLabel(Text(accessibilityLabel))
        .popover(isPresented: $isShowing) {
            Text(text)
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.m)
                .frame(width: 280, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// 1.5 pt Ink 100 line between rows inside a card.
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: Borders.hairline)
            .accessibilityHidden(true)
    }
}

/// A row in a card: 56 pt minimum, 16 pt side padding.
struct CardRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Spacing.s) { content }
            .font(Typography.body)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
    }
}

extension View {
    /// Text-field surface: 48 pt, radius 16, 2 pt Ink 200 border; focused: Blue 500 border and a 4 pt Blue 100 halo.
    func fieldSurface(isFocused: Bool, minHeight: CGFloat = Spacing.fieldHeight, isError: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.field, style: .continuous)
        let border: Color = isError ? .error : (isFocused ? .focusRing : .stroke)
        return self
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: minHeight)
            .background(Color.surface, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: Borders.card))
            .background(
                shape
                    .inset(by: -Borders.focusHalo)
                    .fill(isFocused ? (isError ? Color.coral100 : Color.focusHalo) : .clear)
            )
    }
}

/// A 0…1 bar on an Ink 100 track.
struct ProgressBar: View {
    let fraction: CGFloat
    var color: Color = .interactive
    var height: CGFloat = 8
    @Environment(\.motion) private var motion

    var body: some View {
        Capsule()
            .fill(Color.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .clipShape(Capsule())
            .animation(motion.animation(MotionTokens.progress), value: fraction)
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var on = true
    @Previewable @State var seg = 0
    VStack(alignment: .leading, spacing: Spacing.m) {
        Toggle("Haptics", isOn: $on)
        SegmentedControl(options: [(0, "All"), (1, "Around me")], selection: $seg)
        HStack {
            SelectChip(title: Text(verbatim: "Travel"), systemImage: "airplane", isSelected: true) {}
            SelectChip(title: Text(verbatim: "Shopping"), systemImage: "cart", isSelected: false) {}
        }
        HStack {
            StatusPill("Learned", tone: .success, systemImage: "checkmark")
            StatusPill("Not learned")
            StatusPill("Needs practice", tone: .error)
            StatusPill("You", tone: .accent)
        }
        HStack {
            IconButton(systemImage: "chevron.left", label: "Back") {}
            IconBadge(systemImage: "shuffle", tone: .accent)
            IconBadge(systemImage: "scope", tone: .error)
            SelectionMark(isOn: true)
            SelectionMark(isOn: false)
        }
        Text(verbatim: "resilient").fieldSurface(isFocused: true)
        ProgressBar(fraction: 0.35, height: 12)
    }
    .padding()
}
