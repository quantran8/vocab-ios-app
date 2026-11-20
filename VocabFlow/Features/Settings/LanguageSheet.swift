import SwiftUI

/// Bottom sheet choosing the app's language. Picking one closes the sheet; the host applies it after,
/// because applying rebuilds the whole screen, sheet included.
struct LanguageSheet: View {
    let selected: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(alignment: .top) {
                    SheetTitle("Choose your language")
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }

                VStack(spacing: Spacing.s) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(language: language, isSelected: language == selected) {
                            onSelect(language)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
    }
}

/// Selection is shown by colour and border, never a checkmark, like the other selection controls.
struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        Button(action: action) {
            Text(verbatim: language.nativeName)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget + 12, alignment: .leading)
                .padding(.horizontal, Spacing.m)
                .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
                .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
                .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
