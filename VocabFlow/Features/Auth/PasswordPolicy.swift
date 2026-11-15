import SwiftUI

/// Rules for a password the learner creates (sign up, reset, change). Logging in only checks length,
/// so accounts made before these rules keep working. The backend enforces the same rules.
enum PasswordPolicy {
    /// Allowed password length. Logging in checks only this, so accounts made before the other rules keep working.
    static let length = 8...72

    enum Rule: CaseIterable, Identifiable {
        case length, letter, digit

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .length: "At least 8 characters"
            case .letter: "At least one letter"
            case .digit: "At least one number"
            }
        }

        func isMet(by password: String) -> Bool {
            switch self {
            case .length: password.count >= PasswordPolicy.length.lowerBound
            case .letter: password.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            case .digit: password.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
            }
        }
    }

    static func isTooLong(_ password: String) -> Bool {
        password.count > PasswordPolicy.length.upperBound
    }

    static func accepts(_ password: String) -> Bool {
        !isTooLong(password) && Rule.allCases.allSatisfy { $0.isMet(by: password) }
    }
}

/// The rules under a new-password field, ticked live as the learner types: a Green check when met,
/// an Ink 300 ring when not.
struct PasswordRuleList: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs - 2) {
            ForEach(PasswordPolicy.Rule.allCases) { rule in
                row(rule.title, isMet: rule.isMet(by: password))
            }
            row("At most 72 characters", isMet: !PasswordPolicy.isTooLong(password))
        }
        .font(Typography.secondary)
    }

    private func row(_ title: LocalizedStringKey, isMet: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Group {
                if isMet {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.success, in: Circle())
                } else {
                    Circle()
                        .strokeBorder(Color.ink300, lineWidth: Borders.card)
                        .frame(width: 18, height: 18)
                }
            }
            .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(isMet ? Color.ink : Color.mutedInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isMet ? Text("Done") : Text("Not yet"))
    }
}
