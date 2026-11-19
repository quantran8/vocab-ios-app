import SwiftUI

/// Sheet adding any word to the learning path. The whole flow stays in this one sheet: type the word, the lookup,
/// what the backend found, editing it or looking for another meaning, and the confirmation are steps pushed inside
/// it, each with a round back (‹) and close (✕) button (docs/app-redesign-v1.html, frames 3.1–3.7).
struct AddWordView: View {
    @Environment(CustomWordStore.self) private var store
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.motion) private var motion
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var direction = StepDirection()

    var body: some View {
        let stage = Stage(store: store)
        let _ = direction.update(stage.order)
        // The ZStack ties onDisappear to the sheet, not to each step's view.
        ZStack {
            stageView
                .id(stage.key)
                .transition(motion.stepTransition(isMovingBack: { direction.isBack }))
        }
        .animation(motion.animation(MotionTokens.stepSlide), value: stage.key)
        .onDisappear {
            store.resetLookup()
            speech.stop()
        }
        .environment(\.closeAddWord, { dismiss() })
        .addWordSheetStyle()
    }

    @ViewBuilder
    private var stageView: some View {
        switch store.phase {
        case .idle:
            WordEntry(text: $text, message: nil, canRetry: false)
        case .loading:
            CenteredStage { LookupProgress() }
        case .failed(let message, let canRetry):
            if !store.isReviewing {
                WordEntry(text: $text, message: message, canRetry: canRetry)
            } else if let word = store.baseWord {
                OtherMeaningStage(
                    lemma: word.lemma,
                    context: store.lastContext,
                    message: message,
                    canRetry: canRetry,
                    onBack: store.goBack
                )
            } else {
                AddWordScaffold(onBack: store.goBack) {
                    ErrorText(message: message)
                    if canRetry {
                        SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                            Task { await store.retryLookup() }
                        }
                    }
                }
            }
        case .result(let result):
            lookupResult(result)
        case .added(let lemma, let isNew, _, let meaning):
            AddedConfirmation(lemma: lemma, meanings: store.addedMeanings.isEmpty ? meaning.map { [$0] } ?? [] : store.addedMeanings, isNew: isNew) { dismiss() }
        }
    }

    @ViewBuilder
    private func lookupResult(_ result: CustomWordLookup) -> some View {
        switch result {
        case .existing(let word):
            let senses = ReviewSense.senses(of: word)
            WordReview(
                lemma: word.lemma,
                senses: senses,
                closed: word.meanings.filter { meaning in !senses.contains { $0.id == meaning.id } },
                search: .otherMeaning
            )
        case .draft(let draft):
            WordReview(lemma: draft.lemma, senses: ReviewSense.senses(of: draft, tag: "AI-generated"), search: .otherMeaning)
        case .newMeaningDraft(let draft):
            WordReview(lemma: draft.lemma, senses: ReviewSense.senses(of: draft, tag: "Private to you"), search: .searchAgain)
        case .invalid:
            CenteredStage(onBack: store.goBack) {
                InvalidWord(text: text.trimmed)
            } bar: {
                PinnedActionBar {
                    PrimaryButton(title: "Try another word") { store.resetLookup() }
                }
            }
        }
    }
}

/// The step on screen, from the store's phase: a key that changes with every new step, and its place in the flow.
private struct Stage {
    let key: String
    /// Higher is further in. A search for another meaning sits deeper than the word it started from.
    let order: Int

    @MainActor
    init(store: CustomWordStore) {
        let nested = store.baseWord != nil ? 2 : 0
        switch store.phase {
        case .idle:
            key = "entry"
            order = 0
        case .loading:
            key = "loading"
            order = 1 + nested
        case .failed:
            if store.isReviewing {
                key = "failed-\(nested)"
                order = 2 + nested
            } else {
                key = "entry"
                order = 0
            }
        case .result(let result):
            key = "result-" + Self.identity(of: result)
            order = 2 + nested
        case .added:
            key = "added"
            order = 5
        }
    }

    private static func identity(of result: CustomWordLookup) -> String {
        switch result {
        case .existing(let word): "existing-" + word.meanings.map(\.id).joined(separator: ",")
        case .draft(let draft): "draft-" + draft.draftId
        case .newMeaningDraft(let draft): "meaning-" + draft.draftId
        case .invalid: "invalid"
        }
    }
}

/// Which way the steps move. Worked out from their order as the phase changes, and read by the transition as it
/// runs (an outgoing step keeps the transition it was given). Not observed: it never redraws anything itself.
private final class StepDirection {
    private(set) var isBack = false
    private var last: Int?

    func update(_ order: Int) {
        if let last, last != order { isBack = order < last }
        last = order
    }
}

private struct CloseAddWordKey: EnvironmentKey {
    static var defaultValue: (() -> Void)? { nil }
}

private extension EnvironmentValues {
    /// Closes the add-word sheet from any step.
    var closeAddWord: (() -> Void)? {
        get { self[CloseAddWordKey.self] }
        set { self[CloseAddWordKey.self] = newValue }
    }
}

private extension View {
    func addWordSheetStyle() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radii.sheet)
            .presentationBackground(Color.canvas)
    }
}

/// The ‹ and ✕ row at the top of every step.
private struct AddWordHeader: View {
    var onBack: (() -> Void)?
    @Environment(\.closeAddWord) private var closeAddWord

    var body: some View {
        HStack {
            if let onBack {
                SheetBackButton(action: onBack)
            }
            Spacer()
            SheetCloseButton(action: closeAddWord)
        }
    }
}

/// One step of the sheet: the header, scrolling content, and an action bar pinned to the bottom (above the keyboard).
private struct AddWordScaffold<Content: View, Bar: View>: View {
    var onBack: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AddWordHeader(onBack: onBack)
                VStack(alignment: .leading, spacing: Spacing.m) {
                    content
                }
                .padding(.top, Spacing.xxs)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bar }
        .background(Color.canvas)
    }
}

extension AddWordScaffold where Bar == EmptyView {
    init(onBack: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(onBack: onBack, content: content, bar: { EmptyView() })
    }
}

/// A step whose content sits in the middle of the sheet: the lookup, the confirmation, "not a word".
private struct CenteredStage<Content: View, Bar: View>: View {
    var onBack: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    var body: some View {
        VStack(spacing: 0) {
            AddWordHeader(onBack: onBack)
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.xs)
            Spacer(minLength: Spacing.l)
            content
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer(minLength: Spacing.l)
            // Sits a little above the middle, as the header's height does in the design.
            Color.clear.frame(height: Spacing.xl + Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { bar }
        .background(Color.canvas)
    }
}

extension CenteredStage where Bar == EmptyView {
    init(onBack: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(onBack: onBack, content: content, bar: { EmptyView() })
    }
}

// MARK: - Entry, lookup, not a word

private struct WordEntry: View {
    @Binding var text: String
    let message: String?
    let canRetry: Bool
    @Environment(CustomWordStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        let issue = CustomWordInput.issue(in: text)
        let inputHint = hint(for: issue)
        AddWordScaffold {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SheetTitle("Which word do you want to learn?")
                Text("We’ll find it or prepare it for you.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Type an English word", text: $text)
                .font(Typography.tileLarge)
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit { search() }
                .fieldSurface(isFocused: isFocused, minHeight: Spacing.rowMinHeight, isError: inputHint != nil)
                .padding(.top, Spacing.xs)

            // Only once the text can't be looked up.
            if let inputHint {
                Text(inputHint)
                    .font(Typography.micro)
                    .foregroundStyle(Color.errorInk)
            }
            if let message {
                ErrorText(message: message)
            }
            if canRetry {
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.retryLookup() }
                }
            }
        } bar: {
            PinnedActionBar {
                PrimaryButton(title: "Look up", isEnabled: issue == nil) { search() }
            }
        }
        .onAppear { isFocused = true }
    }

    private func hint(for issue: CustomWordInput.Issue?) -> LocalizedStringKey? {
        switch issue {
        case nil, .empty: nil
        case .tooLong: "Keep it under \(CustomWordInput.maxTextLength) characters."
        case .invalidCharacters: "Use letters, spaces, hyphens and apostrophes, starting with a letter."
        }
    }

    private func search() {
        guard CustomWordInput.issue(in: text) == nil else { return }
        Task { await store.lookup(text) }
    }
}

/// Syllie flying while the backend looks the word up.
private struct LookupProgress: View {
    var body: some View {
        VStack(spacing: 0) {
            SyllieLoadingView()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Looking up your word…")
                .font(Typography.tileLarge.weight(.heavy))
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.screenGutter)
            Text("New words can take up to a minute.")
                .font(Typography.secondary)
                .foregroundStyle(Color.bodyInk)
                .padding(.top, Spacing.xs)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Syllie tilts his head over what was typed, so the spelling mistake is easy to see.
private struct InvalidWord: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            SyllieReactionView(reaction: .oops)
                .frame(width: 96, height: 80)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            if !text.isEmpty {
                Text(verbatim: text)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.bodyInk)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.m)
                    .frame(height: Spacing.buttonSmallHeight)
                    .background(Color.neutralSurface, in: Capsule())
                    .padding(.top, Spacing.screenGutter)
            }
            Text("That doesn’t look like a word")
                .font(Typography.screenTitle.weight(.heavy))
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.m)
                .accessibilityAddTraits(.isHeader)
            Text("Check the spelling, or try another word.")
                .font(Typography.secondary)
                .foregroundStyle(Color.bodyInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)
        }
    }
}

private struct ErrorText: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(Typography.secondary)
            .foregroundStyle(Color.errorInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Review

/// A meaning shown in full, whichever lookup result it came from: one to add, or one the learner already has.
private struct ReviewSense: Identifiable {
    let id: String
    let partOfSpeech: String
    let ipa: String?
    let tag: LocalizedStringKey?
    /// Nil when the meaning is already learned or on the path.
    let addition: CustomWordAddition?
    let standing: ExistingMeaning.Standing?
    let draft: CustomWordEditDraft

    static func senses(of word: ExistingWord) -> [ReviewSense] {
        word.meanings.compactMap { meaning in
            guard meaning.status != .unavailable, meaning.canBeAdded || meaning.standing != nil else { return nil }
            return ReviewSense(
                id: meaning.id,
                partOfSpeech: meaning.partOfSpeech,
                ipa: meaning.ipa,
                tag: meaning.status == .translationDraft ? "AI-translated" : nil,
                addition: meaning.canBeAdded ? meaning.addition : nil,
                standing: meaning.standing,
                draft: CustomWordEditDraft(lemma: word.lemma, meaning: meaning)
            )
        }
    }

    static func senses(of draft: WordDraft, tag: LocalizedStringKey) -> [ReviewSense] {
        draft.senses.enumerated().map { index, sense in
            ReviewSense(
                id: String(index),
                partOfSpeech: sense.partOfSpeech,
                ipa: sense.ipa,
                tag: tag,
                addition: .draft(draft.draftId, senseIndex: index, edits: nil),
                standing: nil,
                draft: CustomWordEditDraft(lemma: draft.lemma, sense: sense)
            )
        }
    }
}

/// Grouped meanings with independent selection, expansion and editing.
private struct WordReview: View {
    /// The way to another meaning. Context only works on a word the backend already has,
    /// so a brand-new word offers none.
    enum Search {
        case otherMeaning, searchAgain
    }

    /// A step pushed over the result.
    private enum Step {
        case edit, otherMeaning
    }

    let lemma: String
    let senses: [ReviewSense]
    let closed: [ExistingMeaning]
    let search: Search?
    @Environment(CustomWordStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var step: Step?
    @State private var isMovingBack = false
    @State private var selectedID: String?
    @State private var openIDs: Set<String>
    @State private var selectedIDs: Set<String>
    @State private var editedIDs: Set<String> = []
    /// One editable copy per meaning, so switching between them keeps the changes.
    @State private var drafts: [String: CustomWordEditDraft]

    init(lemma: String, senses: [ReviewSense], closed: [ExistingMeaning] = [], search: Search? = nil) {
        self.lemma = lemma
        self.senses = senses
        self.closed = closed
        self.search = search
        // Opens on a meaning that can still be added, when there is one.
        let first = (senses.first { $0.addition != nil } ?? senses.first)?.id
        _selectedID = State(initialValue: first)
        _openIDs = State(initialValue: Set(first.map { [$0] } ?? []))
        _selectedIDs = State(initialValue: Set(senses.first(where: { $0.addition != nil }).map { [$0.id] } ?? []))
        _drafts = State(initialValue: Dictionary(uniqueKeysWithValues: senses.map { ($0.id, $0.draft) }))
    }

    private var selected: ReviewSense? {
        senses.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack {
            switch step {
            case nil:
                details
                    .transition(motion.stepTransition(isMovingBack: { isMovingBack }))
            case .edit?:
                if let selected, let draft = drafts[selected.id] {
                    EditStage(initial: draft, onBack: { go(to: nil) }) { edited in
                        drafts[selected.id] = edited
                        selectedIDs.insert(selected.id)
                        editedIDs.insert(selected.id)
                        go(to: nil)
                    }
                    .transition(motion.stepTransition(isMovingBack: { isMovingBack }))
                }
            case .otherMeaning?:
                OtherMeaningStage(
                    lemma: lemma,
                    context: search == .searchAgain ? store.lastContext : "",
                    message: nil,
                    canRetry: false,
                    onBack: { go(to: nil) }
                )
                .transition(motion.stepTransition(isMovingBack: { isMovingBack }))
            }
        }
    }

    private func go(to next: Step?) {
        isMovingBack = next == nil
        motion.perform(MotionTokens.stepSlide) { step = next }
    }

    private var pronunciationsDiffer: Bool { Set(senses.map { $0.ipa ?? "" }).count > 1 }
    private var pending: [ReviewSense] {
        senses.filter { selectedIDs.contains($0.id) && !store.addedSenseIDs.contains($0.id) && $0.addition != nil }
    }

    private var details: some View {
        AddWordScaffold(onBack: store.goBack) {
            WordHeroHeader(lemma: lemma, ipa: senses.first?.ipa, showsPronunciation: !pronunciationsDiffer)
            HStack {
                Text("Choose meanings to add").font(Typography.emphasis)
                Spacer()
                if let tag = senses.compactMap(\.tag).first { StatusPill(tag) }
            }
            .padding(.top, Spacing.m)
            ForEach(PartOfSpeechGroup.grouping(senses) { $0.partOfSpeech }) { group in
                Text(verbatim: VocabularyItem.localizedPartOfSpeech(group.partOfSpeech))
                    .font(Typography.eyebrow).foregroundStyle(Color.mutedInk)
                ForEach(group.items) { sense in senseCard(sense) }
            }
            TextLink(title: "Find another meaning") {
                if search != nil { go(to: .otherMeaning) }
                else { store.resetLookup() }
            }
            ForEach(closed) { meaning in ClosedMeaningRow(meaning: meaning) }
        } bar: {
            PinnedActionBar {
                VStack(spacing: Spacing.xs) {
                    if let notice = store.notice { ErrorText(message: notice) }
                    PrimaryButton(title: pending.count > 1 ? "Add \(pending.count) meanings" : "Add word",
                                  isEnabled: !pending.isEmpty && !store.isAdding) {
                        let selections = pending.compactMap { sense -> CustomWordStore.Selection? in
                            guard var addition = sense.addition else { return nil }
                            let draft = drafts[sense.id] ?? sense.draft
                            addition.edits = draft.edits
                            return .init(id: sense.id, addition: addition, meaning: draft.meaningText)
                        }
                        Task { await store.addSelected(selections, lemma: lemma) }
                    }
                }
            }
        }
        .disabled(store.isAdding)
    }

    private func senseCard(_ sense: ReviewSense) -> some View {
        let draft = drafts[sense.id] ?? sense.draft
        let added = store.addedSenseIDs.contains(sense.id)
        let canSelect = sense.addition != nil && !added
        let chosen = canSelect && selectedIDs.contains(sense.id)
        let open = openIDs.contains(sense.id)
        let shape = RoundedRectangle(cornerRadius: Radii.card)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                if canSelect {
                    Button {
                        if chosen { selectedIDs.remove(sense.id) } else { selectedIDs.insert(sense.id) }
                    } label: {
                        Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24)).foregroundStyle(chosen ? Color.interactive : Color.ink300)
                            .symbolReplace(value: chosen)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Select meaning"))
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
                Button {
                    motion.perform(MotionTokens.snap) { if open { openIDs.remove(sense.id) } else { openIDs.insert(sense.id) } }
                } label: {
                    HStack {
                        Text(verbatim: draft.meaningText).font(Typography.emphasis).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if added || sense.standing != nil {
                            StatusPill(sense.standing == .learned ? "Already learned" : "On your path")
                        } else if editedIDs.contains(sense.id) { StatusPill("Edited") }
                        ExpandChevron(isExpanded: open)
                    }
                    .foregroundStyle(chosen ? Color.selectedInk : Color.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(open ? "Expanded" : "Collapsed"))
            }
            if pronunciationsDiffer {
                WordPronunciation(term: lemma, ipa: sense.ipa, style: .compact, usesWhiteSurface: chosen)
                    .padding(.leading, canSelect ? 56 : 0)
            }
            if open {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if !draft.definitionText.isEmpty {
                        Eyebrow(text: "Definition")
                        Text(verbatim: draft.definitionText).font(Typography.secondary)
                    }
                    ForEach(draft.examples) { example in
                        Eyebrow(text: "Example")
                        HighlightedSentence(sentence: example.text, locator: draft.locator(for: example)).font(Typography.secondary)
                        if !example.translation.isEmpty { ExampleTranslation(text: example.translation) }
                    }
                    if canSelect {
                        TextLink(title: "Edit this meaning") { selectedID = sense.id; go(to: .edit) }
                    }
                }
                .padding(.leading, canSelect ? 56 : 0)
                .padding(.bottom, Spacing.xs)
            }
        }
        .padding(Spacing.s)
        .background(chosen ? Color.selectedSurface : Color.surface, in: shape)
        .overlay(shape.strokeBorder(chosen ? Color.interactive : Color.stroke, lineWidth: Borders.card))
    }

}

/// A meaning that can't be picked: already on the path, or not available.
private struct ClosedMeaningRow: View {
    let meaning: ExistingMeaning

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: VocabularyItem.localizedPartOfSpeech(meaning.partOfSpeech))
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedInk)
                if meaning.status == .unavailable {
                    Text("Not available right now")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.disabledInk)
                }
                if let text = meaning.meaningText {
                    Text(verbatim: text)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                }
                if let definition = meaning.definitionText {
                    Text(verbatim: definition)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if meaning.inRoadmap {
                StatusPill("On your path", tone: .success)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(fill: meaning.status == .unavailable ? .disabledSurface : .surface)
    }
}

// MARK: - Other steps

/// Saves the changes and adds the word in one go.
private struct EditStage: View {
    let onBack: () -> Void
    let onSave: (CustomWordEditDraft) -> Void
    @State private var draft: CustomWordEditDraft

    init(initial: CustomWordEditDraft, onBack: @escaping () -> Void, onSave: @escaping (CustomWordEditDraft) -> Void) {
        self.onBack = onBack
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        AddWordScaffold(onBack: onBack) {
            EditWordTitle(lemma: draft.lemma)
            CustomWordEditFields(draft: $draft)
                .padding(.top, Spacing.xs)
        } bar: {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save",
                    requirement: "Fill in every field",
                    isEnabled: draft.isValid
                ) {
                    onSave(draft)
                }
            }
        }
    }
}

/// A field describing the meaning to look for. Shown after a failed search too, with the error under it.
private struct OtherMeaningStage: View {
    let lemma: String
    let message: String?
    let canRetry: Bool
    let onBack: () -> Void
    @Environment(CustomWordStore.self) private var store
    @State private var context: String

    init(lemma: String, context: String, message: String?, canRetry: Bool, onBack: @escaping () -> Void) {
        self.lemma = lemma
        self.message = message
        self.canRetry = canRetry
        self.onBack = onBack
        _context = State(initialValue: context)
    }

    private var isValid: Bool {
        (1...CustomWordInput.maxContextLength).contains(context.trimmed.utf16.count)
    }

    var body: some View {
        AddWordScaffold(onBack: onBack) {
            WordHeroHeader(lemma: lemma, ipa: nil)
            EditorField(
                title: "Meaning to find",
                text: $context,
                maxLength: CustomWordInput.maxContextLength,
                lines: 2...6,
                focusesOnAppear: true
            )
            .padding(.top, Spacing.m)
            if let message {
                ErrorText(message: message)
            }
            if canRetry {
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.retryLookup() }
                }
            }
        } bar: {
            PinnedActionBar {
                // The lemma, not the typed form: context only applies to a word the backend already has.
                PrimaryButton(title: "Find meaning", isEnabled: isValid) {
                    let context = context
                    Task { await store.lookup(lemma, context: context) }
                }
            }
        }
    }
}

/// Syllie with a green check badge, then the word and meaning just added.
private struct AddedConfirmation: View {
    let lemma: String
    let meanings: [String]
    let isNew: Bool
    let onDone: () -> Void

    var body: some View {
        CenteredStage {
            VStack(spacing: 0) {
                SyllieReactionView(reaction: .happy)
                    .frame(width: 112, height: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: Spacing.iconBadge, height: Spacing.iconBadge)
                            .background(Color.success, in: Circle())
                            .padding(Borders.focusHalo)
                            .background(Color.surface, in: Circle())
                            .offset(x: Spacing.xs, y: Spacing.xxs)
                    }
                    .accessibilityHidden(true)
                Text(isNew ? "Word added" : "Already on your path")
                    .font(Typography.screenTitle.weight(.heavy))
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .padding(.top, Spacing.l)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: lemma).font(Typography.wordTitle).padding(.top, Spacing.xs)
                VStack(spacing: 0) {
                    ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                        if index > 0 { CardDivider() }
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.success)
                            Text(verbatim: meaning).font(Typography.secondary.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(Spacing.m)
                    }
                }
                .cardSurface()
                .padding(.top, Spacing.m)
            }
        } bar: {
            PinnedActionBar {
                PrimaryButton(title: "Done", action: onDone)
            }
        }
    }
}
