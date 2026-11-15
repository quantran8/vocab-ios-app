import SwiftUI

/// Log in with email and password, Apple or Google (docs/app-redesign-v1.html, 0.1–0.2).
/// Creating an account (`SignUpView`) and resetting a password (`ResetPasswordView`) are pushed pages
/// with the system back button.
struct AuthView: View {
    private enum Field {
        case email, password
    }

    @Environment(AuthStore.self) private var auth
    @State private var isResetting = false
    @State private var isSigningUp = false
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthBrand()
                        .padding(.top, Spacing.l)

                    VStack(spacing: Spacing.m) {
                        AuthEmailField(email: $email, focus: $focus, field: .email, isError: logInError != nil) {
                            focus = .password
                        }
                        LabeledField("Password", isFocused: focus == .password, isError: logInError != nil) {
                            PasswordInput(
                                placeholder: "At least 8 characters",
                                text: $password,
                                contentType: .password,
                                focus: $focus,
                                field: .password,
                                onSubmit: submit
                            )
                        }
                    }
                    .padding(.top, Spacing.xl)

                    if let notice = auth.accountDeletedNotice {
                        Text(verbatim: notice)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.s)
                    }
                    if let logInError {
                        FieldErrorText(message: logInError)
                            .padding(.top, Spacing.s)
                    }

                    TextLink(title: "Forgot password?") { open(reset: true) }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        // Keeps the 44 pt touch target without pushing the button down.
                        .padding(.vertical, -Spacing.xs)
                        .padding(.top, Spacing.s)

                    PrimaryButton(title: "Log in", isEnabled: canSubmit, action: submit)
                        .padding(.top, Spacing.l - Spacing.xxs)

                    if auth.isSubmitting && !isSigningUp && !isResetting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.s)
                    }

                    SocialSignInButtons()
                        .padding(.top, Spacing.l)
                }
                .padding(.horizontal, Spacing.practiceGutter)
                .padding(.bottom, Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .safeAreaInset(edge: .bottom) {
                AuthFooterLink(prompt: "New here?", link: "Create account") { open(reset: false) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: email) { if logInError != nil { auth.clearError() } }
            .onChange(of: password) { if logInError != nil { auth.clearError() } }
            .navigationDestination(isPresented: $isSigningUp) {
                SignUpView(email: $email)
                    .iconOnlyBackButton()
            }
            .navigationDestination(isPresented: $isResetting) {
                ResetPasswordView(email: $email)
                    .iconOnlyBackButton()
            }
        }
        .tint(Color.ink)
    }

    /// The log-in error, shown under the fields. Errors from a pushed page stay on that page.
    private var logInError: String? {
        guard !isSigningUp, !isResetting else { return nil }
        return auth.errorMessage
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !auth.isSubmitting && !trimmedEmail.isEmpty && PasswordPolicy.length.contains(password.count)
    }

    private func open(reset: Bool) {
        auth.clearError()
        focus = nil
        // The reset's new password must not reuse what was typed to log in.
        password = ""
        if reset { isResetting = true } else { isSigningUp = true }
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        let email = trimmedEmail
        Task { await auth.logIn(email: email, password: password) }
    }
}

/// Reset a forgotten password in two steps (0.5 enter the email, 0.6 enter the code and a new password).
/// The store knows whether the code went out.
struct ResetPasswordView: View {
    private enum Field {
        case email, code, password
    }

    @Environment(AuthStore.self) private var auth
    @Binding var email: String
    @State private var code = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Reset your password")
                    .padding(.top, Spacing.xs)

                if let sentTo = auth.passwordResetEmail {
                    codeStep(sentTo)
                } else {
                    emailStep
                }

                if let error = auth.errorMessage {
                    FieldErrorText(message: error)
                        .padding(.top, Spacing.s)
                }

                PrimaryButton(title: auth.passwordResetEmail == nil ? "Send code" : "Set new password",
                              isEnabled: canSubmit, action: submit)
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
        .background(Color.canvas)
        .onAppear {
            auth.clearError()
            focus = auth.passwordResetEmail == nil ? .email : .code
        }
        .onDisappear {
            auth.cancelPasswordReset()
            auth.clearError()
        }
    }

    @ViewBuilder
    private var emailStep: some View {
        AuthMessage(text: Text("Enter the email you signed up with. We’ll send you a code to set a new password."))
            .padding(.top, Spacing.s)
        AuthEmailField(email: $email, focus: $focus, field: .email, isError: auth.errorMessage != nil,
                       submitLabel: .send, onSubmit: submit)
            .padding(.top, Spacing.l + Spacing.xxs)
    }

    @ViewBuilder
    private func codeStep(_ sentTo: String) -> some View {
        AuthMessage(text: Text("We sent a code to \(AuthMessage.address(sentTo)). Enter it and choose a new password."))
            .padding(.top, Spacing.s)
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .trailing, spacing: 0) {
                LabeledField("Code", isFocused: focus == .code) {
                    TextField("6-digit code", text: $code)
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .tracking(6)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focus, equals: .code)
                }
                TextLink(title: "Send a new code") {
                    Task { await auth.requestPasswordReset(email: sentTo) }
                }
                .disabled(auth.isSubmitting)
                .padding(.vertical, -Spacing.xxs)
            }
            VStack(alignment: .leading, spacing: Spacing.s) {
                LabeledField("New password", isFocused: focus == .password) {
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
        .padding(.top, Spacing.l + Spacing.xxs)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        guard !auth.isSubmitting else { return false }
        if auth.passwordResetEmail == nil { return !trimmedEmail.isEmpty }
        return !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && PasswordPolicy.accepts(password)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        Task {
            if auth.passwordResetEmail == nil {
                await auth.requestPasswordReset(email: trimmedEmail)
                if auth.passwordResetEmail != nil { focus = .code }
            } else {
                await auth.resetPassword(code: code.trimmingCharacters(in: .whitespacesAndNewlines), newPassword: password)
            }
        }
    }
}
