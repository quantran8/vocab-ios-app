import SwiftUI

/// Report a problem with what's on screen (backend FRONTEND_FLOW §18): one reason, an optional note, send.
/// The task or card behind it keeps its state; nothing here is scored.
struct ContentReportSheet: View {
    let target: ContentReportTarget
    let onSent: () -> Void
    @Environment(ContentReportStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ContentReportReason?
    @State private var note = ""
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        SheetTitle("Report a problem")
                        if let subtitle = target.subtitle, !subtitle.isEmpty {
                            Text(verbatim: subtitle)
                                .font(Typography.secondary)
                                .foregroundStyle(Color.mutedInk)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    SheetCloseButton()
                        .disabled(store.isSubmitting)
                }

                Eyebrow(text: "What’s wrong?")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.xs)
                reasonList

                noteField
                    .padding(.top, Spacing.l)

                if case .failed(let message) = store.phase {
                    Text(verbatim: message)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.s)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                PrimaryButton(
                    title: store.isSubmitting ? "Sending…" : "Send report",
                    requirement: requirement,
                    isEnabled: requirement == nil && !store.isSubmitting,
                    action: send
                )
                .padding(.top, Spacing.l)
                SecondaryButton(title: "Cancel") { dismiss() }
                    .disabled(store.isSubmitting)
                    .padding(.top, Spacing.s)
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
        // A send in flight is bounded by the API timeout; closing then would lose its answer.
        .interactiveDismissDisabled(store.isSubmitting)
        .onAppear { store.begin() }
    }

    private var reasonList: some View {
        VStack(spacing: 0) {
            ForEach(Array(target.reasons.enumerated()), id: \.element) { index, option in
                if index > 0 { CardDivider() }
                Button {
                    reason = option
                    if option == .other { isNoteFocused = true }
                } label: {
                    CardRow {
                        SelectionMark(isOn: reason == option)
                        Text(option.title(isRecording: target.isRecording))
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isSubmitting)
                .accessibilityAddTraits(reason == option ? [.isSelected] : [])
            }
        }
        .cardSurface()
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: reason == .other ? "Details" : "Details (optional)", color: isNoteFocused ? .selectedInk : .mutedInk)
                .accessibilityHidden(true)
            TextField(reason == .other ? LocalizedStringKey("Details") : LocalizedStringKey("Details (optional)"), text: $note, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .lineLimit(3...6)
                .focused($isNoteFocused)
                .disabled(store.isSubmitting)
                .padding(.vertical, Spacing.s)
                .fieldSurface(isFocused: isNoteFocused, isError: isNoteTooLong)
            HStack {
                if isNoteTooLong {
                    Text("Keep it under \(ContentReportRequest.maxNoteLength) characters")
                        .foregroundStyle(Color.errorInk)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(note.unicodeScalars.count)/\(ContentReportRequest.maxNoteLength)")
                    .monospacedDigit()
                    .foregroundStyle(isNoteTooLong ? Color.errorInk : Color.mutedInk)
                    .accessibilityHidden(true)
            }
            .font(Typography.micro)
        }
    }

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isNoteTooLong: Bool { trimmedNote.unicodeScalars.count > ContentReportRequest.maxNoteLength }

    /// Why Send is off; nil when it can send.
    private var requirement: LocalizedStringKey? {
        guard let reason else { return "Choose what’s wrong" }
        if reason == .other, trimmedNote.isEmpty { return "Tell us what’s wrong" }
        if isNoteTooLong { return "Shorten your note" }
        return nil
    }

    private func send() {
        guard requirement == nil, let reason else { return }
        isNoteFocused = false
        Task {
            if await store.submit(target, reason: reason, note: note) { onSent() }
        }
    }
}

extension ContentReportReason {
    func title(isRecording: Bool) -> LocalizedStringKey {
        switch self {
        case .incorrectMeaning: "The meaning or translation is wrong"
        case .incorrectDefinition: "The definition is wrong"
        case .incorrectExample: "The example is wrong or unnatural"
        case .answerShouldBeAccepted: isRecording ? "My pronunciation was marked wrong" : "My answer should be accepted"
        case .incorrectQuestion: "The question or answer doesn’t make sense"
        case .audioIssue: "Problem with the audio or pronunciation"
        case .other: "Something else"
        }
    }
}

/// The flag that opens the report sheet: Ink 400, a 44 pt target.
struct ContentReportButton: View {
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "flag")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.ink400 : Color.ink200)
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Report a problem"))
        .accessibilityHint(Text("Tells our editors something in this content is wrong"))
    }
}

private struct ContentReportPresenter: ViewModifier {
    @Binding var target: ContentReportTarget?
    @Environment(\.motion) private var motion
    @State private var toast: String?
    @State private var toastToken = UUID()

    func body(content: Content) -> some View {
        content
            .sheet(item: $target) { target in
                ContentReportSheet(target: target) {
                    self.target = nil
                    showToast(String(localized: "Report sent. Thank you!", bundle: .appLanguage))
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    ToastView(text: toast)
                        .padding(.horizontal, Spacing.screenGutter)
                        .padding(.bottom, Spacing.s)
                        .transition(motion.popTransition)
                        .allowsHitTesting(false)
                }
            }
    }

    private func showToast(_ text: String) {
        let token = UUID()
        toastToken = token
        motion.perform(MotionTokens.feedback) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard toastToken == token else { return }
            motion.perform(MotionTokens.press) { toast = nil }
        }
    }
}

extension View {
    /// Presents the report sheet for `target` and confirms a sent report with a toast over this view.
    func contentReportSheet(_ target: Binding<ContentReportTarget?>) -> some View {
        modifier(ContentReportPresenter(target: target))
    }
}
