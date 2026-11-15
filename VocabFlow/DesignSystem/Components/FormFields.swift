import SwiftUI

/// A text input with its label above (semibold, Ink 950), used by the account forms.
/// Focused: Blue border and halo; `isError`: Coral border.
struct LabeledField<Content: View>: View {
    let title: LocalizedStringKey
    var isFocused = false
    var isError = false
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, isFocused: Bool = false, isError: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isFocused = isFocused
        self.isError = isError
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            content
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fieldSurface(isFocused: isFocused, isError: isError)
        }
    }
}

/// An error line under a form: info icon and semibold Coral 700 text. Never an alert.
struct FieldErrorText: View {
    let message: String

    var body: some View {
        Label {
            Text(verbatim: message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(Typography.secondary.weight(.semibold))
        .foregroundStyle(Color.destructiveInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A password input with a show/hide toggle. Focus stays on the field when it flips.
struct PasswordInput<Field: Hashable>: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let contentType: UITextContentType
    let focus: FocusState<Field?>.Binding
    let field: Field
    var submitLabel: SubmitLabel = .go
    var onSubmit: () -> Void = {}

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(contentType)
            .submitLabel(submitLabel)
            .focused(focus, equals: field)
            .onSubmit(onSubmit)

            Button {
                let wasFocused = focus.wrappedValue == field
                isVisible.toggle()
                // Swapping the field drops focus; keep the keyboard up.
                if wasFocused { focus.wrappedValue = field }
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -Spacing.s)
            .accessibilityLabel(isVisible ? Text("Hide password") : Text("Show password"))
        }
    }
}
