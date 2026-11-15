import SwiftUI

// Pieces shared by the log-in, sign-up and reset screens (docs/app-redesign-v1.html, flow 0).

/// Syllie over the "Syll" wordmark, opening the log-in screen.
struct AuthBrand: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            // The `Syllie` artboard (520×430) leaves room around him; at this frame his body is about 96 pt wide.
            SyllieView(mood: .idle)
                .frame(width: 160, height: 132)
                .padding(.vertical, -Spacing.m)
                .accessibilityHidden(true)
            Text(verbatim: "Syll")
                .font(Typography.wordmark)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Syll"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// "New here? Create account": the whole line is the button, pinned to the bottom of the screen.
struct AuthFooterLink: View {
    let prompt: LocalizedStringKey
    let link: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            (Text(prompt).foregroundColor(Color.bodyInk)
                + Text(verbatim: " ")
                + Text(link).foregroundColor(Color.link).fontWeight(.semibold))
                .font(Typography.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.practiceGutter)
        .padding(.bottom, Spacing.xs)
        .background(Color.canvas)
    }
}

/// A 16 pt Ink 600 explanation under a screen title, with the address in bold Ink 950.
struct AuthMessage: View {
    let text: Text

    var body: some View {
        text
            .font(Typography.body)
            .foregroundStyle(Color.bodyInk)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The address inside a sentence, bold and in Ink 950.
    static func address(_ email: String) -> Text {
        Text(verbatim: email).bold().foregroundColor(Color.ink)
    }
}

/// The email input shared by every auth form.
struct AuthEmailField<Field: Hashable>: View {
    @Binding var email: String
    let focus: FocusState<Field?>.Binding
    let field: Field
    var isError = false
    var submitLabel: SubmitLabel = .next
    let onSubmit: () -> Void

    var body: some View {
        LabeledField("Email", isFocused: focus.wrappedValue == field, isError: isError) {
            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused(focus, equals: field)
                .onSubmit(onSubmit)
        }
    }
}
