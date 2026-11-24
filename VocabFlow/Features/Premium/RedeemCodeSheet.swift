import SwiftUI

/// Enter a Syll redeem code (not an App Store offer code). Shown only while the server allows redeeming
/// (`features.redeemEnabled`). Success shows Syllie with a green check and the new end date.
struct RedeemCodeSheet: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isRedeeming = false
    @State private var error: String?
    @State private var didRedeem = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                SheetCloseButton()
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)

            if didRedeem {
                done
            } else {
                form
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
        .onAppear { isFocused = true }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle("Redeem a code")
            Text("Enter the code you received to unlock Syll Premium.")
                .font(Typography.secondary)
                .foregroundStyle(Color.bodyInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)

            LabeledField("Code", isFocused: isFocused, isError: error != nil) {
                TextField(text: $code, prompt: Text(verbatim: "SYLL-XXXX")) { Text("Code") }
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit(submit)
            }
            .padding(.top, Spacing.l)

            if let error {
                FieldErrorText(message: error)
                    .padding(.top, Spacing.s)
            }

            Spacer(minLength: Spacing.l)

            VStack(spacing: Spacing.s) {
                if isRedeeming { ProgressView() }
                PrimaryButton(title: "Redeem", isEnabled: canSubmit, action: submit)
            }
            .padding(.bottom, Spacing.xs)
        }
        .padding(.horizontal, Spacing.screenGutter)
        .onChange(of: code) { if error != nil { error = nil } }
    }

    private var done: some View {
        VStack(spacing: Spacing.s) {
            Spacer(minLength: 0)
            SyllieView(mood: .happy)
                .frame(width: 186, height: 154)
                .accessibilityHidden(true)
            SheetTitle("You’re Premium!")
                .multilineTextAlignment(.center)
            if let until = learner.profile?.plan?.premiumUntil {
                Text("Premium until \(until.formatted(.dateTime.day().month(.wide).year().locale(AppLanguage.active.locale)))")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.bottom, Spacing.xs)
        }
        .padding(.horizontal, Spacing.screenGutter)
    }

    private var canSubmit: Bool {
        !isRedeeming && !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        isRedeeming = true
        error = nil
        Task {
            defer { isRedeeming = false }
            do {
                try await learner.redeem(code: code)
                didRedeem = true
            } catch {
                self.error = error.asAPIError.userMessage
            }
        }
    }
}
