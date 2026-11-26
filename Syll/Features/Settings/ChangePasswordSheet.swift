import SwiftUI

/// Changes the password of the signed-in account. The backend re-checks the current one.
/// Built like the design's other sheets: ✕ in the corner, a 26 pt title, labelled fields with focus and error
/// states, and the Ink action pinned at the bottom. Success shows Syllie with a green check.
struct ChangePasswordSheet: View {
    private enum Field {
        case current, new
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var didChange = false
    @FocusState private var focus: Field?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                SheetCloseButton()
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)

            if didChange {
                done
            } else {
                form
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
        .onAppear {
            auth.clearPasswordChangeError()
            focus = .current
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle("Change password")

                VStack(alignment: .leading, spacing: Spacing.m) {
                    LabeledField("Current password", isFocused: focus == .current, isError: auth.passwordChangeError != nil) {
                        PasswordInput(
                            placeholder: "Current password",
                            text: $current,
                            contentType: .password,
                            focus: $focus,
                            field: .current,
                            submitLabel: .next
                        ) { focus = .new }
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        LabeledField("New password", isFocused: focus == .new) {
                            PasswordInput(
                                placeholder: "Create a password",
                                text: $new,
                                contentType: .newPassword,
                                focus: $focus,
                                field: .new,
                                submitLabel: .done,
                                onSubmit: submit
                            )
                        }
                        PasswordRuleList(password: new)
                    }
                }
                .padding(.top, Spacing.l)

                if let error = auth.passwordChangeError {
                    FieldErrorText(message: error)
                        .padding(.top, Spacing.s)
                }

                Text("Signed up with Google or Apple? Log out and use “Forgot password?” to set a password.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.s) {
                if auth.isChangingPassword {
                    ProgressView()
                }
                PrimaryButton(title: "Change password", isEnabled: canSubmit, action: submit)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xs)
            .background(Color.canvas)
        }
        .onChange(of: current) { if auth.passwordChangeError != nil { auth.clearPasswordChangeError() } }
    }

    private var done: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottomTrailing) {
                SyllieView(mood: .happy)
                    .frame(width: 186, height: 154)
                    .padding(.vertical, -Spacing.m)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: Spacing.iconBadge, height: Spacing.iconBadge)
                    .background(Color.success, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: Borders.focusHalo))
                    .offset(x: -Spacing.l, y: -Spacing.xxs)
            }
            .accessibilityHidden(true)
            Text("Your password has been changed.")
                .font(Typography.screenTitle.weight(.heavy))
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.l)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.bottom, Spacing.xs)
        }
    }

    private var canSubmit: Bool {
        !auth.isChangingPassword
            && PasswordPolicy.length.contains(current.count)
            && PasswordPolicy.accepts(new)
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        Task {
            if await auth.changePassword(current: current, new: new) {
                current = ""
                new = ""
                didChange = true
            }
        }
    }
}
