import Foundation

// Contract: backend docs/FRONTEND_FLOW.md §18 and docs/content-reports.md.

enum ContentReportSource: String, Encodable {
    case learnCard = "learn_card"
    case practiceTask = "practice_task"
    case wordDetail = "word_detail"
}

enum ContentReportReason: String, Encodable, CaseIterable, Identifiable {
    case incorrectMeaning = "incorrect_meaning"
    case incorrectDefinition = "incorrect_definition"
    case incorrectExample = "incorrect_example"
    case answerShouldBeAccepted = "answer_should_be_accepted"
    case incorrectQuestion = "incorrect_question"
    case audioIssue = "audio_issue"
    case other

    var id: String { rawValue }
}

/// The learner's answer, as a hint for the reviewer. Never audio, never the whole event stream.
struct ReportAttemptExcerpt: Encodable, Equatable {
    var submittedText: String?
    var optionId: String?
    var tileIds: [String]?
    var receiptId: String?

    static let maxTextLength = 256
}

/// What the report sheet is about, captured when it opens so a later step change can't retarget it.
struct ContentReportTarget: Equatable, Identifiable {
    enum Context: Equatable {
        case learnCard(sessionID: String, learnStepID: String)
        case practiceTask(sessionID: String, taskID: String, excerpt: ReportAttemptExcerpt?)
        case wordDetail(meaningID: String)
    }

    let id = UUID()
    let context: Context
    /// The word or question, shown under the sheet title.
    let subtitle: String?
    /// The reasons this content can have, in display order; `other` is always last.
    let reasons: [ContentReportReason]
    /// A recording task: the answer reason reads "My pronunciation was marked wrong".
    var isRecording = false

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

extension ContentReportTarget {
    /// Learn card or word detail: the reasons depend on what the meaning shows.
    static func meaningReasons(hasDefinition: Bool, hasExample: Bool, hasAudio: Bool) -> [ContentReportReason] {
        var reasons: [ContentReportReason] = [.incorrectMeaning]
        if hasDefinition { reasons.append(.incorrectDefinition) }
        if hasExample { reasons.append(.incorrectExample) }
        if hasAudio { reasons.append(.audioIssue) }
        return reasons + [.other]
    }

    /// A task: the answer appeal only once an answer was judged (never before feedback, never when it was accepted).
    static func taskReasons(canAppeal: Bool, hasAudio: Bool) -> [ContentReportReason] {
        var reasons: [ContentReportReason] = [.incorrectQuestion]
        if canAppeal { reasons.append(.answerShouldBeAccepted) }
        reasons.append(.incorrectMeaning)
        if hasAudio { reasons.append(.audioIssue) }
        return reasons + [.other]
    }
}

struct ContentReportRequest: Encodable, Equatable {
    static let maxNoteLength = 500

    let clientReportId: String
    let source: ContentReportSource
    let reason: ContentReportReason
    let context: ContentReportTarget.Context
    let note: String?

    /// Same report, ignoring the idempotency key: a retry must reuse the key.
    func isSameReport(as other: ContentReportRequest) -> Bool {
        source == other.source && reason == other.reason && context == other.context && note == other.note
    }

    private enum CodingKeys: String, CodingKey { case clientReportId, source, reason, context, note }
    private enum ContextKeys: String, CodingKey { case sessionId, learnStepId, taskId, attemptExcerpt, meaningId }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientReportId, forKey: .clientReportId)
        try container.encode(source, forKey: .source)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(note, forKey: .note)
        var nested = container.nestedContainer(keyedBy: ContextKeys.self, forKey: .context)
        switch context {
        case .learnCard(let sessionID, let learnStepID):
            try nested.encode(sessionID, forKey: .sessionId)
            try nested.encode(learnStepID, forKey: .learnStepId)
        case .practiceTask(let sessionID, let taskID, let excerpt):
            try nested.encode(sessionID, forKey: .sessionId)
            try nested.encode(taskID, forKey: .taskId)
            // Only the appeal carries the answer.
            if reason == .answerShouldBeAccepted { try nested.encodeIfPresent(excerpt, forKey: .attemptExcerpt) }
        case .wordDetail(let meaningID):
            try nested.encode(meaningID, forKey: .meaningId)
        }
    }
}

extension ContentReportTarget.Context {
    var source: ContentReportSource {
        switch self {
        case .learnCard: .learnCard
        case .practiceTask: .practiceTask
        case .wordDetail: .wordDetail
        }
    }
}

struct ContentReportReceipt: Decodable, Equatable {
    let reportId: String
    let duplicate: Bool
}

extension TaskAttempt {
    /// The latest judged answer, for an "accept my answer" report; nil before any answer or for answers with no text.
    var reportExcerpt: ReportAttemptExcerpt? {
        for event in events.reversed() {
            switch event.action {
            case .submitValue(let text), .transcribed(let text):
                return ReportAttemptExcerpt(submittedText: String(text.prefix(ReportAttemptExcerpt.maxTextLength)))
            case .submitOption(let id):
                return ReportAttemptExcerpt(optionId: String(id))
            case .submitTiles(let ids):
                return ReportAttemptExcerpt(tileIds: ids.prefix(ReportAttemptExcerpt.maxTextLength).map(String.init))
            case .assessed(let receiptID):
                return ReportAttemptExcerpt(receiptId: receiptID)
            default:
                continue
            }
        }
        return nil
    }

    /// The answer was judged and not accepted: the only time an appeal makes sense.
    /// A recording is judged per take, so a failed take can be appealed before the task ends.
    var canAppealAnswer: Bool {
        guard reportExcerpt != nil else { return false }
        if task.template == .recording { return !isRightFirstTime }
        switch status {
        case .wrong, .exhausted, .revealed: return true
        case .answering, .solved, .recorded: return false
        }
    }
}
