import SwiftUI

/// Sheet listing the words the learner added, one row per word: tap for details. The row's ⋯ is a menu
/// (edit, restore the original, remove — which asks first); a word with several meanings opens a sheet of them first.
struct CustomWordsView: View {
    /// What a ⋯ menu asked for; from the meanings sheet it runs once that sheet is gone.
    private enum RowAction {
        case edit, restore, remove
    }

    @Environment(CustomWordStore.self) private var store
    @State private var selected: CustomWord?
    @State private var editing: CustomWord?
    @State private var acting: CustomWordGroup?
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
        .sheet(item: $acting, onDismiss: runPendingAction) { group in
            actionSheet(group)
        }
        .sheet(item: $removing) { word in
            ConfirmSheet(
                style: .destructive(systemImage: "trash"),
                title: isOnlyMeaning(word) ? "Remove this word?" : "Remove this meaning?",
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
                if groups.isEmpty {
                    Text("Words you add will collect here.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            row(group)
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

    private var groups: [CustomWordGroup] { CustomWordGroup.grouping(store.words) }

    private func isOnlyMeaning(_ word: CustomWord) -> Bool {
        store.words.filter { $0.wordId == word.wordId }.count <= 1
    }

    private func row(_ group: CustomWordGroup) -> some View {
        let isBusy = group.meanings.contains { store.busyMeaningIDs.contains($0.meaningId) }
        let editable = group.firstEditable
        return HStack(spacing: Spacing.s) {
            Button {
                if let editable { selected = editable }
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
                    Text(verbatim: group.lemma)
                        .font(Typography.wordClass.weight(.bold))
                        .foregroundStyle(group.recalled ? Color.disabledInk : Color.ink)
                    status(meaningText: group.meaningText, pending: group.translationPending, recalled: group.recalled)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(editable != nil ? Text("Shows every meaning of the word") : Text(verbatim: ""))

            // One meaning: its menu straight away. Several: a sheet listing them, each with its own menu.
            Group {
                if let word = group.meanings.first, group.meanings.count == 1 {
                    Menu {
                        actionMenu(word) { perform($0, on: word) }
                    } label: {
                        moreIcon
                    }
                } else {
                    Button {
                        acting = group
                    } label: {
                        moreIcon
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
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

    /// A word row shows its meanings and, below them, the pill while any meaning still translates.
    @ViewBuilder
    private func status(meaningText: String?, pending: Bool, recalled: Bool) -> some View {
        if recalled {
            Text("No longer available")
                .font(Typography.secondary)
                .foregroundStyle(Color.destructiveInk)
        } else {
            if let meaningText {
                Text(verbatim: meaningText)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if pending {
                StatusPill("Translating", tone: .reward)
                    .padding(.top, Spacing.xxs / 2)
                    .accessibilityHint(Text("It joins your sessions once the translation is ready."))
            }
        }
    }

    private func status(_ word: CustomWord) -> some View {
        status(meaningText: word.meaningText, pending: word.translationPending, recalled: word.recalled)
    }

    // MARK: Actions

    /// The ⋯ sheet: the word, then one card with a row per added meaning; each row's ⋯ is a menu of its actions.
    private func actionSheet(_ group: CustomWordGroup) -> some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: group.lemma)
                    .font(Typography.screenTitle.weight(.heavy))
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(group.meanings.enumerated()), id: \.element.id) { index, word in
                        if index > 0 { CardDivider() }
                        meaningRow(word)
                    }
                }
                .cardSurface()
                .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
    }

    private func meaningRow(_ word: CustomWord) -> some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 0) {
                status(word)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if word.overridden, word.isEditable {
                StatusPill("Edited")
            }
            Menu {
                actionMenu(word) { choose($0, for: word) }
            } label: {
                moreIcon
            }
            .padding(.trailing, -Spacing.xs)
            .accessibilityLabel(Text("More actions"))
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .frame(minHeight: Spacing.rowMinHeight)
        .opacity(store.busyMeaningIDs.contains(word.meaningId) ? 0.5 : 1)
        .disabled(store.busyMeaningIDs.contains(word.meaningId))
    }

    private var moreIcon: some View {
        Image(systemName: "ellipsis")
            .font(.body.weight(.bold))
            .foregroundStyle(Color.mutedInk)
            .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func actionMenu(_ word: CustomWord, run: @escaping (RowAction) -> Void) -> some View {
        if word.isEditable {
            Button("Edit", systemImage: "pencil") { run(.edit) }
            if word.overridden {
                Button("Restore original", systemImage: "arrow.uturn.backward") { run(.restore) }
            }
        }
        Button("Remove", systemImage: "trash", role: .destructive) { run(.remove) }
    }

    /// From the sheet: the action waits until the sheet is gone, so the next sheet can present.
    private func choose(_ action: RowAction, for word: CustomWord) {
        pendingAction = (word, action)
        acting = nil
    }

    private func runPendingAction() {
        guard let pending = pendingAction else { return }
        pendingAction = nil
        perform(pending.action, on: pending.word)
    }

    private func perform(_ action: RowAction, on word: CustomWord) {
        switch action {
        case .edit: editing = word
        case .restore: Task { await store.restoreOriginal(word) }
        case .remove: removing = word
        }
    }
}
