import SwiftUI

/// The first screen after the first login. Shows itself in the highlighted language,
/// so the choice can be read before it is confirmed.
struct LanguageSelectionView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    @State private var selection = AppLanguage.device

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The artboard leaves room around him; at this frame his body is about 64 pt wide.
                SyllieView(mood: .idle)
                    .frame(width: 107, height: 88)
                    .padding(.leading, -21)
                    .padding(.vertical, -Spacing.s)
                    .accessibilityHidden(true)
                    .padding(.top, Spacing.xl)

                OnboardingTitle(
                    title: "Choose a language",
                    subtitle: "For the app and for word meanings. You can change it in Settings."
                )

                ChoiceCard(items: AppLanguage.allCases) { language in
                    ChoiceRow(isSelected: language == selection, markLeading: true) {
                        guard language != selection else { return }
                        motion.perform(MotionTokens.press) { selection = language }
                        settings.feedback.selectionChanged()
                    } content: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: language.nativeName)
                                .font(Typography.emphasis)
                                .foregroundStyle(language == selection ? Color.selectedInk : Color.ink)
                            Text(verbatim: language.otherLanguageName)
                                .font(Typography.micro)
                                .foregroundStyle(Color.mutedInk)
                        }
                    }
                }
                .padding(.top, Spacing.l + 4)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Continue") {
                    motion.perform(MotionTokens.transition) { settings.chooseLanguage(selection) }
                }
            }
        }
        .environment(\.locale, selection.locale)
    }
}

extension AppLanguage {
    /// The language's name in the other app language ("Vietnamese", "Tiếng Anh"),
    /// so either reader recognises both rows.
    var otherLanguageName: String {
        switch self {
        case .vietnamese: "Vietnamese"
        case .english: "Tiếng Anh"
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
