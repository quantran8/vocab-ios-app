import SwiftUI

/// Sheet listing the words the learner added: tap for details; each row's ⋯ opens a sheet to edit,
/// restore the original, or remove (which asks first).
struct CustomWordsView: View {
    /// What the ⋯ sheet asked for. It runs once that sheet is gone, so the next sheet can present.
    private enum RowAction {
        case edit, restore, remove
    }

    @Environment(CustomWordStore.self) private var store
    @State private var selected: CustomWord?
    @State private var editing: CustomWord?
    @State private var acting: CustomWord?
    @State private var pendingAction: (word: CustomWord, action: RowAction)?
    @State private var removing: CustomWord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }
                SheetTitle("Words you added")
                content
                    .padding(.top, Spacing.screenGutter)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .task { await store.loadWords() }
        .refreshable { await store.loadWords() }
        .onDisappear { store.stopAudio() }
        .sheet(item: $selected) { word in
            WordDetailSheet(
                wordID: word.wordId,
                lemma: word.lemma,
                ipa: word.ipa,
                focusMeaningID: word.meaningId,
                playAudio: word.audioUrl == nil ? nil : { store.play(word) },
                isPlayingAudio: store.isPlayingAudio
            )
        }
        .sheet(item: $editing) { word in
            CustomWordEditView(initial: CustomWordEditDraft(word: word)) { edited in
                editing = nil
                guard let edits = edited.edits else { return }
                Task { await store.saveOverride(edits, for: word) }
            }
        }
        .sheet(item: $acting, onDismiss: runPendingAction) { word in
            actionSheet(word)
        }
        .sheet(item: $removing) { word in
            ConfirmSheet(
                style: .destructive(systemImage: "trash"),
                title: "Remove this word?",
                message: "It won’t be scheduled for review and your edits will be deleted. Your learning history stays.",
                cancelTitle: "Cancel",
                confirmTitle: "Remove"
            ) {
                removing = nil
                Task { await store.remove(word) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
    }

    @ViewBuilder
    private var content: some View {
        switch store.listPhase {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Spacing.m) {
                errorText(message)
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.loadWords() }
                }
            }
        case .ready:
            VStack(alignment: .leading, spacing: 0) {
                if let error = store.listError {
                    errorText(error)
                        .padding(.bottom, Spacing.s)
                }
                if store.words.isEmpty {
                    Text("Words you add will collect here.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(store.words) { word in
                            row(word)
                        }
                    }
                }
            }
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(verbatim: message)
            .font(Typography.secondary)
            .foregroundStyle(Color.errorInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ word: CustomWord) -> some View {
        let isBusy = store.busyMeaningIDs.contains(word.meaningId)
        return HStack(spacing: Spacing.s) {
            Button {
                if word.isEditable { selected = word }
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
                    Text(verbatim: word.lemma)
                        .font(Typography.wordClass.weight(.bold))
                        .foregroundStyle(word.recalled ? Color.disabledInk : Color.ink)
                    status(word)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(word.isEditable ? Text("Shows every meaning of the word") : Text(verbatim: ""))

            Button {
                acting = word
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.trailing, -Spacing.xs)
            .accessibilityLabel(Text("More actions"))
        }
        .padding(.vertical, Spacing.s + 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.divider).frame(height: Borders.hairline)
        }
        .opacity(isBusy ? 0.5 : 1)
        .disabled(isBusy)
    }

    @ViewBuilder
    private func status(_ word: CustomWord) -> some View {
        if word.recalled {
            Text("No longer available")
                .font(Typography.secondary)
                .foregroundStyle(Color.destructiveInk)
        } else if word.translationPending {
            StatusPill("Translating", tone: .reward)
                .padding(.top, Spacing.xxs / 2)
                .accessibilityHint(Text("It joins your sessions once the translation is ready."))
        } else if let meaning = word.meaningText {
            Text(verbatim: meaning)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    /// The ⋯ sheet: the word and its meaning, then Edit / Restore original / Remove in one card.
    private func actionSheet(_ word: CustomWord) -> some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: word.lemma)
                    .font(Typography.screenTitle.weight(.heavy))
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                if let meaning = word.meaningText {
                    Text(verbatim: meaning)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                }

                VStack(spacing: 0) {
                    if word.isEditable {
                        actionRow("Edit", systemImage: "pencil") { choose(.edit, for: word) }
                        if word.overridden {
                            CardDivider()
                            actionRow("Restore original", systemImage: "arrow.uturn.backward") { choose(.restore, for: word) }
                        }
                        CardDivider()
                    }
                    actionRow("Remove", systemImage: "trash", color: .destructiveInk) { choose(.remove, for: word) }
                }
                .cardSurface()
                .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
    }

    private func actionRow(
        _ title: LocalizedStringKey,
        systemImage: String,
        color: Color = .ink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CardRow {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color == .ink ? Color.ink700 : color)
                    .frame(width: Spacing.l)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(color)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func choose(_ action: RowAction, for word: CustomWord) {
        pendingAction = (word, action)
        acting = nil
    }

    private func runPendingAction() {
        guard let pending = pendingAction else { return }
        pendingAction = nil
        switch pending.action {
        case .edit: editing = pending.word
        case .restore: Task { await store.restoreOriginal(pending.word) }
        case .remove: removing = pending.word
        }
    }
}
