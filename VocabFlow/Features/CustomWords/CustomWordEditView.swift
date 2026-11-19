import SwiftUI

/// Sheet editing the learner's own copy of a word. The word itself, its IPA and level stay fixed.
/// Dismissing discards the changes.
struct CustomWordEditView: View {
    let onSave: (CustomWordEditDraft) -> Void
    private let initial: CustomWordEditDraft
    @State private var draft: CustomWordEditDraft

    init(initial: CustomWordEditDraft, onSave: @escaping (CustomWordEditDraft) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                EditWordTitle(lemma: draft.lemma)
                Text("Your changes apply only to you. Other learners keep the original.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)

                CustomWordEditFields(draft: $draft)
                    .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save",
                    requirement: "Change something and fill in every field",
                    isEnabled: draft.isValid && draft != initial
                ) {
                    onSave(draft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
    }
}

/// "Edit word" over the word itself (30 pt).
struct EditWordTitle: View {
    let lemma: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Eyebrow(text: "Edit word")
            Text(verbatim: lemma)
                .font(Typography.stat)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The editable text of a word: meaning, definition and each example.
struct CustomWordEditFields: View {
    @Binding var draft: CustomWordEditDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.screenGutter) {
            EditorField(title: "Meaning", text: $draft.meaningText, maxLength: CustomWordInput.maxFieldLength)
            EditorField(title: "Definition", text: $draft.definitionText, maxLength: CustomWordInput.maxFieldLength,
                        lines: 2...5)

            ForEach($draft.examples) { $example in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    EditorField(title: "Example", text: $example.text, maxLength: CustomWordInput.maxFieldLength,
                                lines: 2...5, isError: draft.locator(for: example) == nil)
                    if draft.locator(for: example) == nil {
                        Label("The example must contain “\(draft.lemma)”.", systemImage: "exclamationmark.circle")
                            .font(Typography.micro).foregroundStyle(Color.errorInk)
                    } else {
                        HighlightedSentence(sentence: example.text.trimmed, locator: draft.locator(for: example))
                            .font(Typography.secondary)
                    }
                    EditorField(title: "Translation", text: $example.translation, maxLength: CustomWordInput.maxFieldLength,
                                lines: 2...5)
                        .padding(.top, Spacing.xs)
                }
            }
        }
    }
}

/// Multi-line labelled text field with the app's outlined look.
struct EditorField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var maxLength: Int?
    var lines: ClosedRange<Int> = 1...5
    var focusesOnAppear = false
    var isError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title, color: isFocused ? .selectedInk : .mutedInk)
                .accessibilityHidden(true)
            TextField(title, text: $text, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .lineLimit(lines)
                .focused($isFocused)
                .onAppear { if focusesOnAppear { isFocused = true } }
                .padding(.vertical, Spacing.s)
                .fieldSurface(isFocused: isFocused, isError: isTooLong || isError)
            if isTooLong, let maxLength {
                Text("Keep this under \(maxLength) characters.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.errorInk)
            }
        }
    }

    private var isTooLong: Bool {
        guard let maxLength else { return false }
        return text.utf16.count > maxLength
    }
}
