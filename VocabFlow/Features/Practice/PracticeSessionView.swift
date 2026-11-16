import SwiftUI

/// Everything between tapping a practice button and returning to the tab it was started from.
struct PracticeSessionView: View {
    @Environment(PracticeSessionStore.self) private var store
    @Environment(LearnerStore.self) private var learner
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion

    var body: some View {
        switch store.stage {
        case .idle:
            EmptyView()
        case .planning:
            StatusScreen(title: "Preparing your session", isBusy: true, showsFlyingSyllie: true)
        case .committing:
            StatusScreen(title: "Saving your progress", isBusy: true, showsFlyingSyllie: true)
        case .empty where store.isDaily && store.newWords?.withheldReason == .scopeExhausted:
            // Nothing new left in the scope and nothing due: offer the ways forward instead of a blank screen.
            StatusScreen(title: "You’ve learned every new word here", message: plan.current.hasAllTopics
                ? Text("You can still review and practise the words you learned. Choose another collection to learn new words.")
                : Text("You can still review and practise the words you learned. Choose another topic or collection to learn new words.")) {
                PrimaryButton(title: plan.current.hasAllTopics ? "Change collection" : "Choose topics") {
                    motion.perform(MotionTokens.transition) { store.close(followUp: .chooseTopics) }
                }
                SecondaryButton(title: "Practise") {
                    motion.perform(MotionTokens.transition) { store.close(followUp: .randomPractice) }
                }
                closeButton
            }
        case .empty:
            StatusScreen(title: "Nothing to practise right now", message: emptyMessage) {
                closeButton
            }
        case .reviewPreview(let words):
            ReviewPreviewView(words: words)
        case .reviewFinished:
            ReviewFinishedView(cards: store.upcomingCards)
        case .running:
            PracticeFlowView()
        case .finished(let summary):
            PracticeResultsView(
                result: store.result(for: summary),
                effort: store.effort,
                scopeEvents: store.scopeEvents,
                onChooseTopics: { motion.perform(MotionTokens.transition) { store.close(followUp: .chooseTopics) } },
                firstTryCount: store.firstTryCount,
                onPracticeAgain: store.canPracticeAgain ? { Task { await store.practiceAgain() } } : nil,
                onDone: { motion.perform(MotionTokens.transition) { store.close() } }
            )
        case .failed(.planning(let message)):
            StatusScreen(title: "Couldn’t start the session", message: Text(verbatim: message)) {
                retryButton("Try again")
                closeButton
            }
        case .failed(.commit(let message)):
            StatusScreen(title: "Your progress isn’t saved yet", message: Text(verbatim: message)) {
                retryButton("Try saving again")
            }
        case .failed(.sessionLost(let message)):
            StatusScreen(title: "Session ended", message: Text(verbatim: message)) {
                closeButton
            }
        }
    }

    private var emptyMessage: Text {
        if store.isWeakPractice { return Text("Skills you need to practice again will show up here.") }
        if store.isReviewOnly { return Text("No words are waiting for review right now.") }
        if store.practiceFilter != nil { return Text("You haven’t learned any words from this source yet.") }
        // No checkpoint gate any more: an old pending review never shows Daily as blocked.
        // The backend drops skills the device can't train, so only audio-bound choices can come back empty for that reason.
        let skills = Set(store.practiceSkills ?? [])
        if skills == [.speaking], !store.canRecord {
            return Text("Allow microphone access in Settings to practice speaking.")
        }
        if skills.contains(.listening), skills.isSubset(of: [.listening, .speaking]) {
            return Text("Listening practice needs sound and only uses words with audio. Check back after learning more words.")
        }
        return Text("Check back after learning more words.")
    }

    private var closeButton: some View {
        SecondaryButton(title: "Close") {
            motion.perform(MotionTokens.transition) { store.close() }
        }
    }

    private func retryButton(_ title: LocalizedStringKey) -> some View {
        PrimaryButton(title: title) {
            Task { await store.retry() }
        }
    }
}

/// Centered status with optional spinner and actions. Also used while the account loads.
/// `showsFlyingSyllie` swaps the spinner for Syllie flying in place, except with reduced motion.
struct StatusScreen<Actions: View>: View {
    let title: LocalizedStringKey
    var message: Text?
    var isBusy = false
    var showsFlyingSyllie = false
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: Spacing.m) {
            Spacer()
            if isBusy {
                BusyIndicator(showsFlyingSyllie: showsFlyingSyllie)
            }
            Text(title)
                .font(Typography.screenTitle)
                .tracking(Typography.tightTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            message
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            VStack(spacing: Spacing.s) {
                actions
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.m)
    }
}

extension StatusScreen where Actions == EmptyView {
    init(title: LocalizedStringKey, message: Text? = nil, isBusy: Bool = false, showsFlyingSyllie: Bool = false) {
        self.init(title: title, message: message, isBusy: isBusy, showsFlyingSyllie: showsFlyingSyllie) { EmptyView() }
    }
}

/// Spinner, or Syllie flying in place when asked for and motion is allowed.
private struct BusyIndicator: View {
    let showsFlyingSyllie: Bool
    @Environment(\.motion) private var motion

    var body: some View {
        if showsFlyingSyllie && !motion.reduceMotion {
            SyllieLoadingView()
                .frame(width: 240, height: 240)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

/// Lists the session's review words before its first step: the intro streams in, then the words land in rows,
/// with an entrance picked at random each time.
/// Presentation only: Continue works at any point.
private struct ReviewPreviewView: View {
    let words: [ReviewWord]
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var hasLanded = false
    @State private var entrance = Entrance.allCases.randomElement() ?? .scattered
    @State private var trainOrigin = ReviewPreviewView.trainOrigins.randomElement() ?? .zero
    /// Bumped per word to replay its wiggle.
    @State private var wiggles: [String: Int] = [:]
    /// Idle during the intro, watching the list while the words fly in, then one scan once they've landed.
    @State private var syllieReaction = SyllieMood.idle

    private enum Entrance: CaseIterable {
        case scattered, wordTrain
    }

    private static let tileHeight: CGFloat = 54
    /// gap-2.5 between the word tiles.
    private static let tileGap = Spacing.xs + 2
    /// Top, right, bottom and left, each past that screen edge on any phone.
    private static let trainOrigins = [
        CGSize(width: 0, height: -1000),
        CGSize(width: 460, height: 0),
        CGSize(width: 0, height: 1000),
        CGSize(width: -460, height: 0),
    ]
    /// Where tiles start, cycled so neighbours arrive from different sides.
    private static let flyInOrigins = [
        CGSize(width: -420, height: -120),
        CGSize(width: 420, height: -260),
        CGSize(width: -260, height: 520),
        CGSize(width: 360, height: 420),
        CGSize(width: 40, height: -560),
        CGSize(width: -440, height: 260),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle("Review words you’ve learned")

                StreamingText(text: String(localized: "Let’s review these words you already learned before exploring new words.", bundle: .appLanguage)) {
                    hasLanded = true
                }
                .font(Typography.body)
                .foregroundStyle(Color.bodyInk)
                .padding(.top, Spacing.xs)

                // Between the intro and the list: he scans the words as they fly in (left to right, looping) and nods
                // he's ready the moment the last word lands, then idles (scrolling
                // doesn't retrigger it, and it never repeats while the screen is up).
                SyllieReactionView(reaction: syllieReaction)
                    .frame(width: 150, height: 118)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.l)

                FlowLayout(spacing: Self.tileGap, lineSpacing: Self.tileGap, alignment: .center) {
                    ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                        tile(word, index: index)
                            .modifier(TileWiggle(trigger: wiggles[word.id, default: 0]))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .task(id: hasLanded) { await wiggleWords() }
        .task(id: hasLanded) { await scanWhenSettled() }
        .safeAreaInset(edge: .bottom) {
            PracticeActionBar {
                VStack(spacing: Spacing.s) {
                    PrimaryButton(title: "Continue") {
                        motion.perform(MotionTokens.transition) { store.continueToPractice() }
                    }
                    SecondaryButton(title: "Close") {
                        motion.perform(MotionTokens.transition) { store.close() }
                    }
                }
            }
        }
    }

    /// Syllie scans the list from the moment the words start flying in and nods the moment the last one lands.
    /// The nod has to start on a loop boundary (each `reviewWatch` loop ends with his eyes centred, the nod's first
    /// pose), so the entrance is timed to last whole loops (`entranceTiming`) rather than the other way round.
    private func scanWhenSettled() async {
        guard hasLanded else { return }
        if !motion.reduceMotion {
            syllieReaction = .reviewWatch
            do {
                try await Task.sleep(for: .seconds(entranceTiming.total))
            } catch {
                return
            }
        }
        syllieReaction = .reviewReady
    }

    /// After the entrance, a random word stirs every so often until the screen goes away.
    private func wiggleWords() async {
        guard hasLanded, !motion.reduceMotion else { return }
        try? await Task.sleep(for: .seconds(entranceTiming.total))
        while !Task.isCancelled {
            if let word = words.randomElement() {
                wiggles[word.id, default: 0] += 1
            }
            try? await Task.sleep(for: .seconds(Double.random(in: MotionTokens.reviewWigglePause)))
        }
    }

    /// When each word starts flying in: after `lead`, one every `stagger`. Picked so the last word comes to rest
    /// (its delay + its own landing) after a whole number of `reviewWatch` loops, at least one. The stagger
    /// stretches or shrinks a little from its token to get there; whatever is left is a short lead before the
    /// first word.
    private var entranceTiming: (lead: Double, stagger: Double, total: Double) {
        let (base, settle): (Double, Double) = switch entrance {
        case .scattered: (MotionTokens.reviewTileStagger, MotionTokens.reviewTileSettle)
        case .wordTrain: (MotionTokens.reviewTrainStagger, MotionTokens.reviewTrainSettle)
        }
        let loop = SyllieMood.reviewWatchLoop
        let gaps = Double(max(words.count - 1, 0))
        var loops = max(1, ((gaps * base + settle) / loop).rounded())
        while true {
            let total = loops * loop
            let stagger = gaps > 0 ? min(max((total - settle) / gaps, base * 0.6), base * 2) : base
            let lead = total - settle - gaps * stagger
            if lead >= 0 { return (lead, stagger, total) }
            loops += 1
        }
    }

    private func entranceDelay(_ index: Int) -> Double {
        let timing = entranceTiming
        return timing.lead + Double(index) * timing.stagger
    }

    @ViewBuilder
    private func tile(_ word: ReviewWord, index: Int) -> some View {
        switch entrance {
        case .scattered:
            let tilt: Double = motion.reduceMotion ? 0 : (index.isMultiple(of: 2) ? -12 : 12)
            let delay = entranceDelay(index)
            // The fade is quick and separate from the flight, so a tile is solid for most of its way in instead of
            // drifting in half-transparent for the whole spring.
            tileFace(tileLabel(word))
                .opacity(hasLanded ? 1 : 0)
                .animation(motion.animation(MotionTokens.reviewTileFade.delay(delay)), value: hasLanded)
                .rotationEffect(.degrees(hasLanded ? 0 : tilt))
                .offset(hasLanded ? .zero : flyInOrigin(index))
                .animation(motion.animation(MotionTokens.reviewTileLanding.delay(delay)), value: hasLanded)
        case .wordTrain:
            // All come from the same side, so each word follows the tail of the one before.
            tileFace(tileLabel(word))
                .offset(hasLanded || motion.reduceMotion ? .zero : trainOrigin)
                .opacity(hasLanded ? 1 : 0)
                .animation(
                    motion.animation(MotionTokens.reviewTrainLanding.delay(entranceDelay(index))),
                    value: hasLanded
                )
        }
    }

    /// The word, with the topic it belongs to under it: old topics stay in review after the focus changes.
    private func tileLabel(_ word: ReviewWord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: word.lemma)
                .font(Typography.wordClass.weight(.bold))
                .foregroundStyle(Color.ink)
            if let topic = word.topic {
                Text(verbatim: topic)
                    .font(Typography.tab)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func flyInOrigin(_ index: Int) -> CGSize {
        motion.reduceMotion ? .zero : Self.flyInOrigins[index % Self.flyInOrigins.count]
    }

    private func tileFace(_ label: some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        return label
            .padding(.horizontal, Spacing.s + 2)
            .frame(minHeight: Self.tileHeight)
            .background(Color.surface, in: shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: Borders.card))
            .background(shape.fill(Color.tileDepth).offset(y: Spacing.tileDepth))
            .padding(.bottom, Spacing.tileDepth)
            // Flattened into one layer: the entrance and the wiggle then only move a bitmap instead of redrawing
            // the face, stroke and depth of every tile on every frame while they all fly at once.
            .drawingGroup()
    }
}

/// Between review and new words: lists the words coming up with their meanings.
private struct ReviewFinishedView: View {
    let cards: [LearnCard]
    @Environment(PracticeSessionStore.self) private var store
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion

    private var focusNames: String {
        TopicCatalog.topics(ids: plan.current.topicIDs).map(\.name)
            .formatted(.list(type: .and).locale(AppLanguage.active.locale))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: Spacing.m) {
                    Text("Review complete")
                        .font(Typography.stat)
                        .tracking(Typography.displayTracking)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    // Proud of the finished review, a curious look down at the new words, then ready to go;
                    // he idles after that until "Learn new words" is tapped. Reduced motion: just idle.
                    SyllieReactionView(reaction: motion.reduceMotion ? .idle : .reviewToLearn)
                        .frame(width: 150, height: 118)
                }
                .frame(maxWidth: .infinity)

                if cards.isEmpty {
                    Text("Next up: some new words to learn.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.l)
                } else {
                    if !focusNames.isEmpty {
                        Text("Now for new words from \(focusNames)")
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.m + Spacing.xxs)
                    }
                    Text("Next: \(cards.count) new words")
                        .font(Typography.wordClass.weight(.bold))
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.l)

                    // One card, one row per word, hairlines between.
                    VStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                            if index > 0 {
                                CardDivider()
                            }
                            row(card)
                        }
                    }
                    .cardSurface()
                    .padding(.top, Spacing.s)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PracticeActionBar {
                PrimaryButton(title: "Learn new words") {
                    motion.perform(MotionTokens.transition) { store.continueToPractice() }
                }
            }
        }
    }

    private func row(_ card: LearnCard) -> some View {
        CardRow {
            Text(verbatim: card.word)
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: card.meaning)
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One quick shake with a small hop, replayed whenever `trigger` changes.
private struct TileWiggle: ViewModifier {
    let trigger: Int

    private struct Frame {
        var angle: Double = 0
        var lift: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Frame(), trigger: trigger) { view, frame in
            view
                .rotationEffect(.degrees(frame.angle))
                .offset(y: frame.lift)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(-6, duration: 0.09)
                CubicKeyframe(5, duration: 0.11)
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(2, duration: 0.09)
                CubicKeyframe(0, duration: 0.11)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-5, duration: 0.14)
                CubicKeyframe(0, duration: 0.2)
            }
        }
    }
}

/// Reveals its text character by character. The hidden rest keeps its space, so lines never reflow.
private struct StreamingText: View {
    let text: String
    let onFinished: () -> Void
    @Environment(\.motion) private var motion
    @State private var revealed = 0

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: text))
            .task {
                if !motion.reduceMotion {
                    while revealed < text.count {
                        revealed += 1
                        try? await Task.sleep(for: .seconds(MotionTokens.streamCharacter))
                        if Task.isCancelled { return }
                    }
                }
                revealed = text.count
                onFinished()
            }
    }

    private var attributed: AttributedString {
        var hidden = AttributedString(String(text.dropFirst(revealed)))
        hidden.foregroundColor = Color.clear
        return AttributedString(String(text.prefix(revealed))) + hidden
    }
}

/// One persistent header for every step; the step below it transitions.
private struct PracticeFlowView: View {
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var isConfirmingExit = false

    var body: some View {
        ZStack {
            if let step = store.currentStep {
                stepView(step)
                    .environment(\.stepActionBarHost, store.stepIndex)
                    .id(store.stepIndex)
                    .transition(motion.stepTransition)
            }
        }
        // Only the step content slides; its bottom bar is drawn here and stays in place.
        .hostsStepActionBar()
        .safeAreaInset(edge: .top) {
            let progress = store.partProgress
            FlowHeader(
                stage: partName(progress.part),
                stageCurrent: progress.current,
                stageTotal: progress.total,
                step: progress.current,
                totalSteps: progress.total,
                onClose: { isConfirmingExit = true }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.s)
            .background(Color.canvas)
        }
        .sheet(isPresented: $isConfirmingExit) {
            ConfirmSheet(
                style: .leavePractice,
                title: "Leave the session?",
                message: "Progress only counts once the whole session is finished.",
                cancelTitle: "Keep practising",
                confirmTitle: "Leave without saving"
            ) {
                isConfirmingExit = false
                motion.perform(MotionTokens.transition) { store.close() }
            }
        }
    }

    private func partName(_ part: SessionPartProgress.Part) -> LocalizedStringKey {
        switch part {
        case .review: "Review"
        case .newWords: "New words"
        case .practice: "Practice"
        }
    }

    @ViewBuilder
    private func stepView(_ step: PlanStep) -> some View {
        switch step {
        case .learn(_, let card):
            LearnCardStep(card: card)
        case .practice(let phase, let task):
            if let attempt = store.attempts[task.id] {
                if phase == .knownCheck, let card = store.knownCheckOffer {
                    LearnCardStep(card: card, offersKnownCheck: true)
                } else {
                    PracticeTaskView(attempt: attempt)
                }
            }
        }
    }
}

/// Picks the view for a task's template. Shared by live sessions and Practice Lab.
struct PracticeTaskView: View {
    let attempt: TaskAttempt

    var body: some View {
        switch attempt.task.template {
        case .select: ChoiceTaskView(attempt: attempt)
        case .clozeSelect: ClozeTaskView(attempt: attempt)
        case .typing: TypingTaskView(attempt: attempt)
        case .flyReorder: ReorderTaskView(attempt: attempt)
        case .match: MatchTaskView(attempt: attempt)
        case .surgery: SurgeryTaskView(attempt: attempt)
        case .recording: RecordingTaskView(attempt: attempt)
        }
    }
}

private struct LearnCardStep: View {
    let card: LearnCard
    var offersKnownCheck = false
    @Environment(PracticeSessionStore.self) private var store
    @Environment(LearnerStore.self) private var learner
    @Environment(\.motion) private var motion
    @State private var otherMeanings: [WordDetail.Meaning] = []
    @State private var isShowingOtherMeanings = false

    var body: some View {
        let word = VocabularyItem(
            id: card.word,
            term: card.word,
            meaningVi: card.meaning,
            example: card.examples?.first?.text ?? "",
            exampleTranslation: card.examples?.first?.translation,
            definitionEN: card.definition,
            ipa: card.ipa,
            partsOfSpeech: card.partOfSpeech.map { [$0] } ?? []
        )
        ScrollView {
            VStack(spacing: 0) {
                WordIntroContent(
                    word: word,
                    presentation: word.introPresentation,
                    playAudio: card.audio.map { clip in { store.playClip(clip) } },
                    isPlayingAudio: store.audio.isPlaying,
                    style: .card
                )
                if !otherMeanings.isEmpty {
                    OtherMeaningsLink(count: otherMeanings.count) { isShowingOtherMeanings = true }
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.m + Spacing.xxs)
            .padding(.bottom, Spacing.l)
        }
        .stepActionBar {
            PracticeActionBar {
                if offersKnownCheck {
                    VStack(spacing: Spacing.s) {
                        PrimaryButton(title: "Continue") {
                            motion.perform(MotionTokens.transition) { store.declineKnownCheck() }
                        }
                        SecondaryButton(title: "I know this word", kind: .outline) {
                            motion.perform(MotionTokens.transition) { store.markKnown() }
                        }
                        .accessibilityHint(Text("Skips learning this word"))
                    }
                } else {
                    PrimaryButton(title: "Continue") {
                        motion.perform(MotionTokens.transition) { store.advance() }
                    }
                }
            }
        }
        .task(id: card.wordId) { await loadOtherMeanings() }
        .task(id: card) { await autoplay() }
        .sheet(isPresented: $isShowingOtherMeanings) {
            OtherMeaningsSheet(lemma: card.word, meanings: otherMeanings)
        }
    }

    /// A new word is heard once as its card appears, after the step transition so the sound lands on the card.
    /// Leaving the step cancels it; the store stops any sound on advance.
    private func autoplay() async {
        guard let clip = card.audio else { return }
        try? await Task.sleep(for: Self.autoplayDelay)
        guard !Task.isCancelled else { return }
        store.playClip(clip)
    }

    private static let autoplayDelay: Duration = .milliseconds(350)

    /// Reference only, so a failed load just leaves the link out.
    private func loadOtherMeanings() async {
        guard let wordID = card.wordId, let detail = try? await learner.wordDetail(id: wordID) else { return }
        let others = detail.meanings.filter { $0.meaningId != card.meaningId }
        motion.perform(MotionTokens.transition) { otherMeanings = others }
    }
}

private struct OtherMeaningsLink: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "book")
                    .accessibilityHidden(true)
                Text("Other meanings")
                StatusPill(Text(count, format: .number), tone: .accent)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.link)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(Text("Other meanings, \(count)"))
        .accessibilityHint(Text("For reference only. Not part of this lesson."))
        .padding(.top, Spacing.xs)
    }
}

/// Shown under the results when this session used up a topic or the whole collection.
struct ScopeCompletionCard: View {
    let events: ScopeEvents
    @Environment(PracticeSessionStore.self) private var store
    @Environment(LearningPlanStore.self) private var plan
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.s) {
                IconBadge(systemImage: "trophy.fill", tone: .reward)
                    .symbolBounceOnce(after: MotionTokens.resultSymbolBounce)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    title
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your learned words will still be reviewed. Choose another collection to learn new words.")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.m)
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    private var title: Text {
        if events.collectionCompleted, let collection = plan.current.collection {
            return Text("You’ve learned every word in \(collection.name)!")
        }
        let names = TopicCatalog.topics(ids: Set(events.completedTopicIds)).map(\.name)
            .formatted(.list(type: .and).locale(AppLanguage.active.locale))
        return Text("You’ve learned every word in \(names)")
    }
}
