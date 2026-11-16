import SwiftUI

/// Creating an account with email and password (docs/app-redesign-v1.html, 0.3), pushed from the log-in screen
/// with the system back button. Once sent, the page turns into "Check your email" (0.4).
struct SignUpView: View {
    private enum Field {
        case email, password
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @State private var password = ""
    @FocusState private var focus: Field?

    var body: some View {
        Group {
            if let confirmation = auth.pendingConfirmationEmail {
                checkEmail(confirmation)
            } else {
                form
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { auth.clearError() }
        .onDisappear {
            auth.clearError()
            auth.dismissConfirmation()
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Create your account")
                    .padding(.top, Spacing.xs)

                VStack(alignment: .leading, spacing: Spacing.m) {
                    AuthEmailField(email: $email, focus: $focus, field: .email, isError: auth.errorMessage != nil) {
                        focus = .password
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        LabeledField("Password", isFocused: focus == .password) {
                            PasswordInput(
                                placeholder: "Create a password",
                                text: $password,
                                contentType: .newPassword,
                                focus: $focus,
                                field: .password,
                                onSubmit: submit
                            )
                        }
                        PasswordRuleList(password: password)
                    }
                }
                .padding(.top, Spacing.xl)

                if let error = auth.errorMessage {
                    FieldErrorText(message: error)
                        .padding(.top, Spacing.s)
                }

                // Faded until every rule is met.
                PrimaryButton(title: "Sign up", isEnabled: canSubmit, action: submit)
                    .padding(.top, Spacing.l + Spacing.xxs)

                if auth.isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            AuthFooterLink(prompt: "Already have an account?", link: "Log in") { dismiss() }
        }
        .onChange(of: email) { if auth.errorMessage != nil { auth.clearError() } }
    }

    /// Syllie with a mail badge, the address in bold so it can be checked, and the way back to log in.
    private func checkEmail(_ address: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottomTrailing) {
                SyllieView(mood: .happy)
                    .frame(width: 186, height: 154)
                    .padding(.vertical, -Spacing.m)
                Image(systemName: "envelope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .background(Color.interactive, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: Borders.focusHalo))
                    .offset(x: -Spacing.l, y: -Spacing.xxs)
            }
            .accessibilityHidden(true)

            Text("Check your email")
                .font(Typography.sheetTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.l + Spacing.xxs)
                .accessibilityAddTraits(.isHeader)
            AuthMessage(text: Text("We sent a confirmation link to \(AuthMessage.address(address)). Open it, then log in."))
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Back to log in") { dismiss() }
                .padding(.horizontal, Spacing.practiceGutter)
                .padding(.bottom, Spacing.s)
        }
    }

    private var canSubmit: Bool {
        !auth.isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && PasswordPolicy.accepts(password)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await auth.signUp(email: email, password: password) }
    }
}
