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
