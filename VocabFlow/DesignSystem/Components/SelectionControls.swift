import SwiftUI

/// Large title. A full stop is dropped (no brand dot); other marks ("…learn?") are kept in ink.
struct PunctuatedTitle: View {
    let text: LocalizedStringKey
    var mark = "."
    var font: Font = Typography.display

    var body: some View {
        (Text(text) + Text(verbatim: mark == "." ? "" : mark))
            .font(font)
            .tracking(Typography.displayTracking)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// An icon drawn like a system navigation bar button, for screens without a bar:
/// a Liquid Glass circle on iOS 26+, a bare black icon before that.
struct SystemBarButtonLabel: View {
    let systemImage: String

    var body: some View {
        if #available(iOS 26.0, *) {
            icon
                .foregroundStyle(Color.ink)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            icon
                .foregroundStyle(Color.ink)
                .contentShape(Circle())
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
    }
}

/// Stands in for the system back button on screens without a navigation bar:
/// a Liquid Glass circle on iOS 26+, a bare black chevron (no text) before that.
struct BackButtonLabel: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            SystemBarButtonLabel(systemImage: "chevron.left")
        } else {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
    }
}

/// Rows in one card with a divider between them, for single-choice lists (language, level, collection).
struct ChoiceCard<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { CardDivider() }
                row(item)
            }
        }
        .cardSurface()
    }
}

/// One choice in a `ChoiceCard`: Blue 50 fill and a filled `SelectionMark` when selected.
struct ChoiceRow<Content: View>: View {
    let isSelected: Bool
    var alignment: VerticalAlignment = .center
    var markLeading = false
    let action: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.motion) private var motion

    var body: some View {
        Button(action: action) {
            HStack(alignment: alignment, spacing: Spacing.s) {
                if markLeading { mark }
                content
                Spacer(minLength: 0)
                if !markLeading { mark }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            .background(isSelected ? Color.selectedSurface : Color.surface)
            .contentShape(Rectangle())
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var mark: some View {
        SelectionMark(isOn: isSelected)
            .padding(.top, alignment == .top ? 2 : 0)
    }
}

/// Pill toggle with a leading icon. Selection is shown by colour and border, never a checkmark.
struct TopicChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    /// Learning progress such as "45/120"; nil hides it.
    var progress: (learned: Int, total: Int)? = nil
    /// Every word learned: labelled, still selectable.
    var isFinished = false
    /// Fill when selected; `.surface` on a Blue 50 panel.
    var selectedFill: Color = .selectedSurface
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs - 2) {
                Image(systemName: isFinished ? "checkmark.seal" : systemImage)
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .font(Typography.secondary.weight(.semibold))
                    .lineLimit(1)
                if isFinished {
                    Text("Finished")
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                } else if let progress {
                    Text(verbatim: "\(progress.learned)/\(progress.total)")
                        .font(Typography.micro.monospacedDigit())
                        .foregroundStyle(Color.mutedInk)
                        .accessibilityLabel(Text("\(progress.learned) of \(progress.total) words learned"))
                }
            }
            .chipSurface(isSelected: isSelected, selectedFill: selectedFill)
            .frame(minHeight: Spacing.minTouchTarget)
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Fixed-size square toggle used for weekday pickers.
struct DayToggle: View {
    let title: String
    let accessibilityName: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        Button(action: action) {
            Text(verbatim: title)
                .font(Typography.secondary.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink600)
                .frame(maxWidth: .infinity, minHeight: Spacing.fieldHeight)
                .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
                .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
                .contentShape(shape)
                .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text(verbatim: accessibilityName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.s - 2) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.ink400)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ink400)
                        .frame(width: Spacing.minTouchTarget - 12, height: Spacing.minTouchTarget - 12)
                }
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .fieldSurface(isFocused: isFocused)
        .contentShape(RoundedRectangle(cornerRadius: Radii.field, style: .continuous))
        .onTapGesture { isFocused = true }
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? motion.pressedScale : 1)
            .animation(motion.animation(MotionTokens.press), value: configuration.isPressed)
    }
}

/// Round ‹ for steps inside a sheet, the counterpart of `SheetCloseButton`.
struct SheetBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconButtonLabel(systemImage: "chevron.left")
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, -Spacing.xs)
        .accessibilityLabel(Text("Back"))
    }
}

/// Round ✕ for sheets, sized to a full touch target. Dismisses the presenting sheet.
struct SheetCloseButton: View {
    /// Replaces dismissing the enclosing sheet, e.g. to close a whole stack of sheets.
    var action: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            IconButtonLabel(systemImage: "xmark")
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.trailing, -Spacing.xs)
        .accessibilityLabel(Text("Close"))
    }
}
