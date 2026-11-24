import Foundation
import Observation

/// One part of a session, with its own progress.
struct SessionPartProgress: Equatable {
    enum Part {
        case review, newWords, practice
    }

    let part: Part
    let current: Int
    let total: Int
}

/// Runs one planned session: renders steps in order, scores instantly with each task's answer key,
/// and commits the recorded events at the end. Nothing counts until the commit succeeds.
@Observable
@MainActor
final class PracticeSessionStore {
    enum Stage: Equatable {
        case idle
        case planning
        /// Nothing to learn or review right now.
        case empty
        /// The words this session reviews, shown until the learner continues.
        case reviewPreview([ReviewWord])
        /// Between a daily session's review and its new words, whether those share the plan or got their own.
        case reviewFinished
        case running
        case committing
        case finished(CommitSummary)
        case failed(Failure)
    }

    enum Failure: Equatable {
        case planning(String)
        /// Unknown outcome or a passing outage: retrying resends the same bytes.
        case commit(String)
        /// The session can't be saved any more; only a new plan helps.
        case sessionLost(String)
    }

    enum RecordingStage: Equatable {
        case idle
        case recording
        case uploading
        case assessed(RecordingAssessment)
        /// Can retry the same audio; a persistent failure ends in `unavailable`.
        case uploadFailed
        /// Can't record at all. The reason goes into the `unavailable` event.
        case blocked(reason: String)
    }

    /// Where the shell goes after a session screen closes, when the learner picked a next step there.
    enum FollowUp: Equatable {
        case chooseTopics, randomPractice
        /// The free plan's new words ran out: open Premium.
        case upgrade
    }

    enum UnavailableReason {
        static let micDenied = "micPermissionDenied"
        static let recorderFailed = "recorderFailed"
        static let assessmentFailed = "assessmentFailed"
        static let speechUnavailable = "speechProviderUnavailable"
        /// Free tier: on-device recognition can't run (or the task has no text to check), and uploads need Premium.
        static let onDeviceUnavailable = "onDeviceRecognitionUnavailable"
        static let skipped = "userSkipped"
    }

    private(set) var stage: Stage = .idle {
        // An interstitial (review preview, review finished) is not time spent on the task.
        didSet { if stage == .running, oldValue != .running { stepShownAt = now() } }
    }
    private(set) var steps: [PlanStep] = []
    private(set) var stepIndex = 0 {
        didSet { stepShownAt = now() }
    }
    /// When the current step appeared; events carry the time since.
    private var stepShownAt: ContinuousClock.Instant?
    private let now: () -> ContinuousClock.Instant
    private(set) var attempts: [String: TaskAttempt] = [:]
    private(set) var recording: RecordingStage = .idle
    /// New for every session; keys the route so screens never carry over.
    private(set) var sessionToken = UUID()
    private(set) var audioFailed = false
    /// Practice Lab: tasks are scored locally and nothing is planned, assessed or committed.
    private(set) var isSandbox = false
    var onSandboxEnd: (() -> Void)?
    /// The last daily plan's new-word figures: why it had fewer new words than the goal, if it did.
    private(set) var newWords: NewWordsIssue?
    /// From the last commit; set only by the commit that used up a topic, the scope or the collection.
    private(set) var scopeEvents: ScopeEvents?
    /// LP and Tier from every commit since the session screen opened (review, then new words). Nil from an old backend.
    private(set) var effort: SessionEffort?
    /// Read and cleared by the shell once the session screen is gone.
    private(set) var followUp: FollowUp?
    /// A daily chain's first commit (the review), kept for the results screen once the new words are saved.
    private(set) var pendingReviewSummary: ReviewSummary?
    /// Backend (Azure) by default. `.onDevice` is opt-in and falls back to the backend when the task has no reference text or recognition can't run.
    /// `.onDeviceOnly` is the free tier. Re-read from `scoringForSession` whenever a session starts.
    var recordingScoring: RecordingScoring
    /// Set by the app: who scores recordings in the next session (the learner's plan can change between sessions).
    var scoringForSession: (@MainActor () -> RecordingScoring)?
    /// A session was saved and its results are on screen (not the Lab). The ads count these.
    var onSessionFinished: (@MainActor () -> Void)?

    let audio: AudioClipPlaying
    let haptics: FeedbackProviding
    private let sounds: SoundEffectsPlaying

    private let api: VocabAPI
    private let recorder: VoiceRecording
    private let transcriber: SpeechTranscribing
    private var sessionID: String?
    private var lastRequest: Request?
    private var completedLearnIDs: Set<String> = []
    private var knownChecks: [String: KnownCheck] = [:]
    /// Known-check tasks the learner declined, and the tasks a passed check made unnecessary. Never committed.
    private var skippedTaskIDs: Set<String> = []
    /// Learn steps a passed known check skipped.
    private var knownLearnIDs: Set<String> = []

    private struct Request {
        var mode: SessionMode
        var challengeID: String? = nil
        var filter: PracticeFilter? = nil
        var reviewOnly = false
    }
    /// Encoded once: a retried commit must be byte-identical or the backend reports a conflict.
    private var commitBody: Data?
    private var pendingAudio: RecordedAudio?
    private var latestReceiptID: String?
    /// Decided on a task's first take: its events can't mix receipts and transcripts.
    private var canTranscribe: Bool?
    /// Starting waits on permissions and the audio session; a second tap in that gap must not start a second recorder.
    private var isStartingRecording = false

    init(
        api: VocabAPI,
        audio: AudioClipPlaying,
        recorder: VoiceRecording,
        haptics: FeedbackProviding,
        sounds: SoundEffectsPlaying = SilentSoundEffects(),
        recordingScoring: RecordingScoring = .backend,
        transcriber: SpeechTranscribing? = nil,
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.now = now
        self.api = api
        self.audio = audio
        self.recorder = recorder
        self.haptics = haptics
        self.sounds = sounds
        self.recordingScoring = recordingScoring
        self.transcriber = transcriber ?? OnDeviceSpeechTranscriber()
        recorder.onLimitReached = { [weak self] in
            Task { await self?.stopRecording() }
        }
    }

    var isActive: Bool { stage != .idle }
    var currentStep: PlanStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }

    var currentAttempt: TaskAttempt? {
        guard case .practice(_, let task) = currentStep else { return nil }
        return attempts[task.id]
    }

    /// The check step is never answered: it shows its word's Learn card, offering "I know this word".
    /// See memory known-check-on-intro-card.
    var knownCheckOffer: LearnCard? {
        guard case .practice(.knownCheck, let task)? = currentStep,
              let learnID = knownChecks[task.id]?.learnStepID else { return nil }
        for case .learn(learnID, let card) in steps { return card }
        return nil
    }

    /// Words passed with "I know this" so far in this session.
    var knownWordCount: Int { knownLearnIDs.count }

    /// Where the learner is in the current part. Review always comes before new words in a plan,
    /// and new words start counting from the beginning rather than continuing review's count.
    var partProgress: SessionPartProgress {
        let reviewCount = steps.prefix(while: \.isDueReview).count
        if stepIndex < reviewCount {
            return SessionPartProgress(part: .review, current: stepIndex + 1, total: reviewCount)
        }
        let hasNewWords = reviewCount > 0 || steps.contains { if case .learn = $0 { true } else { false } }
        return SessionPartProgress(
            part: hasNewWords ? .newWords : .practice,
            current: stepIndex - reviewCount + 1,
            total: steps.count - reviewCount
        )
    }

    /// The words the rest of the session introduces, in plan order.
    var upcomingCards: [LearnCard] {
        steps.dropFirst(stepIndex).compactMap { step in
            guard case .learn(_, let card) = step else { return nil }
            return card
        }
    }

    var firstTryCount: Int {
        attempts.values.filter(\.isRightFirstTime).count
    }

    var isWeakPractice: Bool { lastRequest?.mode == .weakWordsPractice }
    var isSpeakingPractice: Bool { lastRequest?.mode == .speakingPractice }
    var isDaily: Bool { lastRequest?.mode == .daily }
    var isReviewOnly: Bool { lastRequest?.reviewOnly == true }
    var practiceFilter: PracticeFilter? { lastRequest?.filter }
    /// Random, Weak and Speaking end with "Practice again", which plans the same request anew.
    var canPracticeAgain: Bool { lastRequest.map { [.randomPractice, .weakWordsPractice, .speakingPractice].contains($0.mode) } ?? false }

    /// What the results screen shows for `summary`, the summary in `.finished`.
    func result(for summary: CommitSummary) -> PracticeResult {
        PracticeResult(mode: lastRequest?.mode ?? .daily, summary: summary)
    }
    /// A denied microphone empties a speaking plan, and only Settings can fix that.
    var canRecord: Bool { recorder.canRecord }

    // MARK: Lifecycle

    func start(_ mode: SessionMode, challengeID: String? = nil) async {
        guard stage == .idle else { return }
        await begin(Request(mode: mode, challengeID: challengeID))
    }

    /// A daily session of due reviews only: no new words and no Journey slot.
    func startReviewOnly() async {
        guard stage == .idle else { return }
        await begin(Request(mode: .daily, reviewOnly: true))
    }

    /// Random practice from `filter` (nil is every learned word).
    func startPractice(filter: PracticeFilter? = nil) async {
        guard stage == .idle else { return }
        await begin(Request(mode: .randomPractice, filter: filter))
    }

    /// From the results of a Random, Weak or Speaking session: a new session with the same source.
    func practiceAgain() async {
        guard case .finished = stage, canPracticeAgain, let request = lastRequest else { return }
        close()
        await begin(request)
    }

    private func begin(_ request: Request) async {
        lastRequest = request
        pendingReviewSummary = nil
        if let scoringForSession { recordingScoring = scoringForSession() }
        await plan(request)
    }

    /// The shell reads this once the session screen is gone.
    func consumeFollowUp() -> FollowUp? {
        defer { followUp = nil }
        return followUp
    }

    func retry() async {
        switch stage {
        case .failed(.planning):
            guard let lastRequest else { return }
            await plan(lastRequest)
        case .failed(.commit):
            await commit()
        default:
            break
        }
    }

    func continueToPractice() {
        switch stage {
        case .reviewPreview, .reviewFinished: stage = .running
        default: break
        }
    }

    /// Plays bundled tasks with no backend. Ends through `onSandboxEnd` instead of committing.
    func startSandbox(_ tasks: [PracticeTask]) {
        guard stage == .idle, !tasks.isEmpty else { return }
        isSandbox = true
        sessionID = "sandbox"
        steps = tasks.map { .practice(phase: .randomPractice, task: $0) }
        stepIndex = 0
        completedLearnIDs = []
        commitBody = nil
        attempts = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, TaskAttempt(task: $0, phase: .randomPractice)) })
        resetStepState()
        stage = .running
        let steps = steps
        Task { await preloadAudio(for: steps) }
    }

    /// Nothing is written: words stay unlearned until a session commits.
    /// `followUp` is where the learner asked to go next (choose topics, practise).
    func close(followUp: FollowUp? = nil) {
        audio.stop()
        recorder.cancel()
        steps = []
        attempts = [:]
        stepIndex = 0
        completedLearnIDs = []
        knownChecks = [:]
        skippedTaskIDs = []
        knownLearnIDs = []
        self.followUp = followUp
        sessionID = nil
        commitBody = nil
        isSandbox = false
        // A chain left halfway has no results screen; its review must not show up under the next session.
        pendingReviewSummary = nil
        resetStepState()
        stage = .idle
        sessionToken = UUID()
    }

    func advance() {
        guard stage == .running, let step = currentStep else { return }
        switch step {
        case .learn(let id, _):
            completedLearnIDs.insert(id)
        case .practice(_, let task):
            guard attempts[task.id]?.isFinished == true else { return }
        }
        moveForward(from: step)
    }

    /// "Continue" on the offered card: the word is learned from it, and the check is never answered.
    func declineKnownCheck() {
        guard stage == .running, case .practice(.knownCheck, let task)? = currentStep,
              let learnID = knownChecks[task.id]?.learnStepID else { return }
        skippedTaskIDs.insert(task.id)
        completedLearnIDs.insert(learnID)
        moveForward(from: currentStep!)
    }

    /// "I know this word": no recall; the word goes out in `knownLearnSteps`, its card and own tasks are skipped.
    func markKnown() {
        guard stage == .running, case .practice(.knownCheck, let task)? = currentStep,
              let check = knownChecks[task.id] else { return }
        knownLearnIDs.insert(check.learnStepID)
        skippedTaskIDs.insert(task.id)
        skippedTaskIDs.formUnion(check.skippableTaskIDs)
        moveForward(from: currentStep!)
    }

    private func isSkipped(_ step: PlanStep) -> Bool {
        switch step {
        case .learn(let id, _): knownLearnIDs.contains(id) || completedLearnIDs.contains(id)
        case .practice(_, let task): skippedTaskIDs.contains(task.id)
        }
    }

    private func moveForward(from step: PlanStep) {
        audio.stop()
        resetStepState()
        if let next = steps.indices.first(where: { $0 > stepIndex && !isSkipped(steps[$0]) }) {
            stepIndex = next
            if step.isDueReview, currentStep?.isDueReview == false {
                stage = .reviewFinished
                haptics.success()
            }
        } else if isSandbox {
            onSandboxEnd?()
        } else {
            Task { await commit() }
        }
    }

    // MARK: Answers

    func submitOption(_ id: Int) { score { $0.submitOption(id) } }
    func submitText(_ text: String) { score { $0.submitText(text) } }
    func submitTiles() { score { $0.submitTiles() } }

    func submitRepair(edits: [Int: String]) {
        score { $0.submitRepair(edits: edits) }
    }

    func submitPair(leftID: Int, rightID: Int) {
        score { $0.submitPair(leftID: leftID, rightID: rightID) }
    }

    func tapTile(_ id: Int) { update(click: true) { $0.tapTile(id) } }
    func removeTile(_ id: Int) { update(click: true) { $0.removeTile(id) } }
    func moveTile(_ id: Int, to index: Int) { update(click: true) { $0.moveTile(id, to: index) } }
    func useHint() { update { $0.useHint() } }
    func reveal() { update { $0.reveal() } }
    func tryAgain() { mutate { $0.tryAgain() } }

    // MARK: Audio

    func playPromptAudio() async {
        guard let attempt = currentAttempt, case .audio(let clip)? = attempt.task.prompt else { return }
        let succeeded = await audio.play(clip.url)
        attempts[attempt.task.id]?.recordAudioPlayback(succeeded: succeeded)
        if currentAttempt?.task.id == attempt.task.id {
            audioFailed = !succeeded
        }
    }

    func playClip(_ clip: AudioClip) {
        Task { _ = await audio.play(clip.url) }
    }

    // MARK: Recording

    func startRecording() async {
        guard recording != .recording, !isStartingRecording, currentAttempt?.canRecordAgain == true else { return }
        isStartingRecording = true
        defer { isStartingRecording = false }
        let taskID = currentAttempt?.task.id
        audio.stop()
        guard await recorder.requestAccess() else {
            recording = .blocked(reason: UnavailableReason.micDenied)
            return
        }
        if canTranscribe == nil {
            canTranscribe = transcriptTarget != nil ? await transcriber.requestAccess() : false
        }
        if mustScoreOnDevice, canTranscribe != true {
            // Nothing could check the take; don't ask the learner to read for nothing.
            recording = .blocked(reason: UnavailableReason.onDeviceUnavailable)
            return
        }
        do {
            try await recorder.start()
            // The learner may have left the task meanwhile; don't leave the mic running behind them.
            guard currentAttempt?.task.id == taskID else {
                recorder.cancel()
                return
            }
            recording = .recording
        } catch is CancellationError {
            // Stopped or cancelled while the audio hardware was starting; nothing failed.
        } catch {
            recording = .blocked(reason: UnavailableReason.recorderFailed)
        }
    }

    func inputLevel() -> Double {
        recording == .recording ? recorder.inputLevel() : 0
    }

    func stopRecording() async {
        guard recording == .recording else { return }
        guard let captured = recorder.stop() else {
            recording = .blocked(reason: UnavailableReason.recorderFailed)
            return
        }
        pendingAudio = captured
        if canTranscribe == true, let transcriptTarget {
            await assessOnDevice(against: transcriptTarget)
        } else if mustScoreOnDevice {
            recording = .blocked(reason: UnavailableReason.onDeviceUnavailable)
        } else {
            await upload()
        }
    }

    /// The free tier outside the Lab: a take is checked on the device or not at all.
    private var mustScoreOnDevice: Bool { recordingScoring == .onDeviceOnly && !isSandbox }

    /// A free learner's take: checked on the device, with no pronunciation score. Drives the Premium hint.
    var isFreeSpeaking: Bool { recordingScoring == .onDeviceOnly && !isSandbox }

    func retryUpload() async {
        await upload()
    }

    /// Leaves a take's result for the mic. The take stays the one to commit until a new one replaces it.
    func retryRecording() {
        guard case .assessed = recording, currentAttempt?.canRecordAgain == true else { return }
        recording = .idle
    }

    /// Ends the task with the last assessment. An invalid one still counts as this task's attempt.
    func acceptRecording() {
        if let latestReceiptID {
            mutate { $0.finishRecording(receiptID: latestReceiptID) }
        } else if currentAttempt?.hasTranscripts == true {
            mutate { $0.finishTranscribed() }
        } else {
            let reason: String
            switch recording {
            case .blocked(let blocked): reason = blocked
            case .uploadFailed: reason = UnavailableReason.speechUnavailable
            default: reason = UnavailableReason.skipped
            }
            mutate { $0.markRecordingUnavailable(reason: reason) }
        }
        advance()
    }

    /// The current take is checked by the device's transcript, not scored by the backend (no score to show).
    var scoresOnDevice: Bool { canTranscribe == true && transcriptTarget != nil }

    private var transcriptTarget: String? {
        guard recordingScoring != .backend, case .recording(let accepted)? = currentAttempt?.task.body else { return nil }
        return accepted.first
    }

    private func assessOnDevice(against target: String) async {
        guard let pendingAudio, let taskID = currentAttempt?.task.id else { return }
        recording = .uploading
        let candidates = await transcriber.transcribe(pendingAudio)
        guard currentAttempt?.task.id == taskID else { return }
        let assessment = TranscriptMatcher.assess(candidates, target: target)
        mutate { $0.recordTranscript(assessment.heard ?? "", passed: assessment.passed == true) }
        recording = .assessed(assessment)
        assessmentFeedback(passed: assessment.passed == true)
    }

    /// Every way a take gets scored ends with the same cue as an answered task.
    private func assessmentFeedback(passed: Bool) {
        if passed {
            haptics.success()
            sounds.playCorrect()
        } else {
            haptics.error()
            sounds.playWrong()
        }
    }

    private func upload() async {
        guard let pendingAudio, let sessionID, let taskID = currentAttempt?.task.id else { return }
        recording = .uploading
        if isSandbox {
            // No speech scoring in the Lab; any take counts as a pass so the flow can be tried end to end.
            latestReceiptID = "sandbox"
            mutate { $0.countAssessment(passed: true) }
            recording = .assessed(RecordingAssessment(assessmentReceiptId: "sandbox", validity: "valid", passed: true, accuracyScore: nil))
            assessmentFeedback(passed: true)
            return
        }
        do {
            let assessment = try await api.assessRecording(sessionID: sessionID, taskID: taskID, audio: pendingAudio)
            guard currentAttempt?.task.id == taskID else { return }
            latestReceiptID = assessment.assessmentReceiptId
            mutate { $0.countAssessment(passed: assessment.passed == true) }
            recording = .assessed(assessment)
            assessmentFeedback(passed: assessment.passed == true)
        } catch {
            guard currentAttempt?.task.id == taskID else { return }
            let failure = error.asAPIError
            if Self.endsSession(failure) {
                stage = .failed(.sessionLost(String(localized: "This session is no longer available. Start a new one to keep going.", bundle: .appLanguage)))
            } else if failure.code == "PREMIUM_REQUIRED" {
                // Premium lapsed mid-session: score this and later takes on the device instead.
                recordingScoring = .onDeviceOnly
                // A task whose earlier take has a receipt keeps it: its events can't mix receipts and transcripts.
                if latestReceiptID == nil, transcriptTarget != nil, await transcriber.requestAccess(),
                   let transcriptTarget, currentAttempt?.task.id == taskID {
                    canTranscribe = true
                    await assessOnDevice(against: transcriptTarget)
                } else {
                    recording = .blocked(reason: UnavailableReason.onDeviceUnavailable)
                }
            } else if failure.isRetryable || failure.code == "PAYLOAD_TOO_LARGE" {
                recording = .uploadFailed
            } else {
                recording = .blocked(reason: UnavailableReason.assessmentFailed)
            }
        }
    }

    // MARK: Private

    /// The longest a session waits for its audio before showing the first step; clips still loading keep going.
    private static let audioPreloadLimit: Duration = .seconds(6)

    /// Every clip the plan can play (new words' Learn cards and audio prompts), fetched before the session starts.
    private func preloadAudio(for steps: [PlanStep]) async {
        let urls = steps.compactMap { step -> URL? in
            switch step {
            case .learn(_, let card):
                return card.audio?.url
            case .practice(_, let task):
                guard case .audio(let clip)? = task.prompt else { return nil }
                return clip.url
            }
        }
        guard !urls.isEmpty else { return }
        let audio = audio
        let download = Task { await audio.preload(urls) }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await download.value }
            group.addTask { try? await Task.sleep(for: Self.audioPreloadLimit) }
            await group.next()
            group.cancelAll()
        }
    }

    private func plan(_ request: Request) async {
        stage = .planning
        scopeEvents = nil
        effort = nil
        do {
            let plan = try await api.planSession(planRequest(request))
            guard stage == .planning else { return }
            newWords = plan.newWords
            guard let id = plan.sessionID, !plan.steps.isEmpty else {
                stage = .empty
                return
            }
            async let preloaded: Void = preloadAudio(for: plan.steps)
            let reviewWords = await loadReviewWords(for: plan)
            await preloaded
            guard stage == .planning else { return }
            load(plan, id: id)
            stage = reviewWords.isEmpty ? .running : .reviewPreview(reviewWords)
        } catch let error as APIError where error.code == "NOT_FOUND" {
            // `checkpointChallenge` answers 404 when no challenge is open.
            if stage == .planning { stage = .empty }
        } catch {
            if stage == .planning { stage = .failed(.planning(error.asAPIError.userMessage)) }
        }
    }

    private var capabilities: PlanRequest.Capabilities {
        PlanRequest.Capabilities(audioPlayback: audio.canPlay, microphone: recorder.canRecord)
    }

    private func planRequest(_ request: Request) -> PlanRequest {
        let isDaily = request.mode == .daily
        return PlanRequest(
            mode: request.mode,
            capabilities: capabilities,
            challengeId: request.challengeID,
            reviewOnly: isDaily && request.reviewOnly ? true : nil,
            knownCheck: isDaily && !request.reviewOnly ? true : nil,
            filter: request.filter
        )
    }

    private func load(_ plan: SessionPlan, id: String) {
        sessionID = id
        steps = plan.steps
        stepIndex = 0
        completedLearnIDs = []
        knownChecks = plan.knownChecks
        skippedTaskIDs = []
        knownLearnIDs = []
        commitBody = nil
        attempts = [:]
        for case .practice(let phase, let task) in plan.steps {
            attempts[task.id] = TaskAttempt(task: task, phase: phase)
        }
        resetStepState()
    }

    /// The preview is only informational, so a failed lookup goes straight to practice.
    /// A current backend names the reviewed words with their topic; an older one leaves the library guess.
    private func loadReviewWords(for plan: SessionPlan) async -> [ReviewWord] {
        guard plan.steps.contains(where: \.isDueReview) else { return [] }
        if let planned = plan.reviewWords {
            var seen = Set<String>()
            return planned.filter { seen.insert($0.wordId).inserted }.map {
                ReviewWord(id: $0.wordId, lemma: $0.lemma, dueAt: .now, topic: $0.sourceTopic?.name)
            }
        }
        guard let words = try? await api.allWords() else { return [] }
        return ReviewWord.due(in: words, on: .now)
    }

    private func commit() async {
        guard let sessionID else { return }
        do {
            let body = try commitBody ?? JSONEncoder().encode(makeCommitBody())
            commitBody = body
            stage = .committing
            let response = try await api.commitSession(sessionID: sessionID, body: body)
            guard stage == .committing else { return }
            record(response)
            await finish(response.summary)
        } catch {
            guard stage == .committing else { return }
            await handleCommitFailure(error.asAPIError, sessionID: sessionID)
        }
    }

    private func makeCommitBody() -> CommitBody {
        let results = steps.compactMap { step -> TaskResult? in
            guard case .practice(_, let task) = step, !skippedTaskIDs.contains(task.id) else { return nil }
            return attempts[task.id]?.result
        }
        let learnIDs = steps.compactMap { step -> String? in
            guard case .learn(let id, _) = step else { return nil }
            return id
        }
        let known = learnIDs.filter(knownLearnIDs.contains)
        return CommitBody(
            learnStepsCompleted: learnIDs.filter(completedLearnIDs.contains),
            knownLearnSteps: known.isEmpty ? nil : known,
            taskResults: results
        )
    }

    private func handleCommitFailure(_ error: APIError, sessionID: String) async {
        if error.code == "SESSION_PAYLOAD_CONFLICT" {
            // Already committed with other data: the saved result is the one that stands.
            if let status = try? await api.commitStatus(sessionID: sessionID), let response = status.response {
                record(response)
                await finish(response.summary)
                return
            }
        }
        if error.isRetryable {
            stage = .failed(.commit(error.userMessage))
        } else if Self.endsSession(error) || error.code == "SESSION_PAYLOAD_CONFLICT" {
            stage = .failed(.sessionLost(String(localized: "This session is no longer available. Start a new one to keep going.", bundle: .appLanguage)))
        } else {
            stage = .failed(.sessionLost(error.userMessage))
        }
    }

    private func record(_ response: CommitResponse) {
        scopeEvents = response.scopeEvents
        guard let lp = response.lp else { return }
        var total = effort ?? SessionEffort()
        total.add(lp: lp, tier: response.tier)
        effort = total
    }

    private func finish(_ summary: CommitSummary) async {
        let hasNewWords = await continueToNewWords()
        if hasNewWords {
            pendingReviewSummary = summary.review
            return
        }
        // A daily chain: the review came with the first commit, the new words with this one.
        var merged = summary
        if let pendingReviewSummary { merged.review = pendingReviewSummary }
        pendingReviewSummary = nil
        stage = .finished(merged)
        haptics.success()
        if !isSandbox { onSessionFinished?() }
    }

    /// A daily session goes straight from review to new words, even when the plan held only review.
    /// The review is already saved; if this plan fails or is more review, the session just ends.
    /// Only when the plan held back nothing: any `withheldReason` means asking again would loop on the same answer.
    private func continueToNewWords() async -> Bool {
        guard let request = lastRequest, request.mode == .daily, !request.reviewOnly, newWords?.withheldReason == nil,
              steps.allSatisfy(\.isDueReview),
              let plan = try? await api.planSession(planRequest(request)),
              let id = plan.sessionID, plan.steps.first?.isDueReview == false,
              stage == .committing
        else { return false }
        await preloadAudio(for: plan.steps)
        guard stage == .committing else { return false }
        newWords = plan.newWords
        load(plan, id: id)
        stage = .reviewFinished
        haptics.success()
        return true
    }

    private static func endsSession(_ error: APIError) -> Bool {
        ["SESSION_STALE", "SESSION_EXPIRED", "SESSION_NOT_OWNED", "TASK_DATA_INVALID"].contains(error.code)
    }

    private func resetStepState() {
        recording = .idle
        pendingAudio = nil
        latestReceiptID = nil
        canTranscribe = nil
        audioFailed = false
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return max(Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000), 0)
    }

    @discardableResult
    private func mutate<Result>(_ body: (inout TaskAttempt) -> Result) -> Result? {
        guard stage == .running, let id = currentAttempt?.task.id, attempts[id] != nil else { return nil }
        attempts[id]!.elapsedMs = stepShownAt.map { Self.milliseconds(now() - $0) }
        return body(&attempts[id]!)
    }

    /// Feedback for picking an answer in a task view. Buttons outside the answer area stay silent.
    func answerPicked() {
        haptics.selectionChanged()
        sounds.playClick()
    }

    private func update(click: Bool = false, _ body: (inout TaskAttempt) -> Void) {
        let before = currentAttempt?.events.count
        mutate(body)
        guard currentAttempt?.events.count != before else { return }
        if click { answerPicked() } else { haptics.selectionChanged() }
    }

    private func score(_ body: (inout TaskAttempt) -> Bool?) {
        switch mutate(body) ?? nil {
        case true?:
            haptics.success()
            sounds.playCorrect()
        case false?:
            haptics.error()
            sounds.playWrong()
        default: break
        }
    }
}
