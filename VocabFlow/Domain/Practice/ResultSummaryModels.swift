import Foundation

// Results-screen blocks of a commit summary (backend FRONTEND_FLOW.md §15).
// Every field is optional: sessions committed by an older backend replay without them.

/// The skill a result item is about. An unknown value hides the line that would name it.
enum ResultSkill: String, LenientEnum, Equatable, CaseIterable {
    case spelling, listening, speaking
    case unknown
    static let fallback = ResultSkill.unknown

    /// Sessions saved by an older backend say `writing` (now spelling) and `reading` (now no skill: meaning only).
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "writing" ? .spelling : ResultSkill(rawValue: raw) ?? .fallback
    }
}

/// Why a word is in a weaker group: the answer that decided it. Unknown values show no reason.
enum ResultCause: String, LenientEnum, Equatable {
    case hinted, retried, primed
    /// Sent by an older backend only: a correct pick now counts as remembered.
    case recognizedOnly = "recognized_only"
    case revealed
    case outOfTries = "out_of_tries"
    case wrongChoice = "wrong_choice"
    case notPassed = "not_passed"
    case unknown
    static let fallback = ResultCause.unknown
}

/// One word in a group. Which fields are set depends on the block.
struct ResultItem: Decodable, Equatable {
    let meaningId: String
    var wordId: String? = nil
    var lemma = ""
    var gloss = ""
    var nextReviewAt: Date? = nil
    /// Review items only.
    var learnedAt: Date? = nil
    /// Weaker review and new-word items: what happened, and in which skill.
    var cause: ResultCause? = nil
    var struggledAt: ResultSkill? = nil
    /// Practice answers: the kind of task, as a label.
    var skill: ResultSkill? = nil
    /// Speaking changes: the status after the session, and the Azure score (nil when scored on the device).
    var status: SpeakingStatus? = nil
    var score: Double? = nil
}

// In an extension, so the memberwise initializer stays.
extension ResultItem {
    private enum CodingKeys: String, CodingKey {
        case meaningId, wordId, lemma, gloss, nextReviewAt, learnedAt, cause, struggledAt, skill, status, score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            meaningId: try c.decode(String.self, forKey: .meaningId),
            wordId: try c.decodeIfPresent(String.self, forKey: .wordId),
            lemma: try c.decodeIfPresent(String.self, forKey: .lemma) ?? "",
            gloss: try c.decodeIfPresent(String.self, forKey: .gloss) ?? "",
            nextReviewAt: try c.decodeIfPresent(Date.self, forKey: .nextReviewAt),
            learnedAt: try c.decodeIfPresent(Date.self, forKey: .learnedAt),
            cause: try c.decodeIfPresent(ResultCause.self, forKey: .cause),
            struggledAt: try c.decodeIfPresent(ResultSkill.self, forKey: .struggledAt),
            skill: try c.decodeIfPresent(ResultSkill.self, forKey: .skill),
            status: try c.decodeIfPresent(SpeakingStatus.self, forKey: .status),
            score: try c.decodeIfPresent(Double.self, forKey: .score)
        )
    }
}

/// The groups of one block. Reads only the keys the app knows: an unknown group is ignored, a missing one is empty.
struct ResultGroups<Group: Hashable & CaseIterable & RawRepresentable>: Decodable, Equatable where Group.RawValue == String {
    private var items: [Group: [ResultItem]]

    init(_ items: [Group: [ResultItem]] = [:]) {
        self.items = items
    }

    subscript(_ group: Group) -> [ResultItem] { items[group] ?? [] }

    func count(_ group: Group) -> Int { self[group].count }

    private struct Key: CodingKey {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        var items: [Group: [ResultItem]] = [:]
        for group in Group.allCases {
            items[group] = try container.decodeIfPresent([ResultItem].self, forKey: Key(stringValue: group.rawValue)) ?? []
        }
        self.items = items
    }
}

enum ReviewGroup: String, CaseIterable {
    case solid, shaky, relearn
}

enum NewWordGroup: String, CaseIterable {
    case smooth, retried, revealed, known
}

enum PracticeGroup: String, CaseIterable {
    case clean, helped, missed
}

struct ReviewSummary: Decodable, Equatable {
    var total: Int? = nil
    var groups = ResultGroups<ReviewGroup>()
}

struct NewWordSummary: Decodable, Equatable {
    var total: Int? = nil
    var groups = ResultGroups<NewWordGroup>()
}

struct PracticeSummary: Decodable, Equatable {
    struct Excluded: Decodable, Equatable {
        var count = 0
        var reasons: [String] = []
    }

    var total: Int? = nil
    var excluded: Excluded? = nil
    var groups = ResultGroups<PracticeGroup>()
}

/// `needPracticeWords` of the word stats, before and after the commit.
struct NeedPracticeCount: Decodable, Equatable {
    var before: Int? = nil
    var after: Int? = nil
}

/// Recordings scored this session: one per pronunciation, and the words whose speaking status changed.
struct SpeakingSummary: Decodable, Equatable {
    var total = 0
    var passed = 0
    var becameFluent: [ResultItem] = []
    var slipped: [ResultItem] = []

    private enum CodingKeys: String, CodingKey { case total, passed, becameFluent, slipped }

    init(total: Int = 0, passed: Int = 0, becameFluent: [ResultItem] = [], slipped: [ResultItem] = []) {
        self.total = total
        self.passed = passed
        self.becameFluent = becameFluent
        self.slipped = slipped
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        passed = try c.decodeIfPresent(Int.self, forKey: .passed) ?? 0
        becameFluent = try c.decodeIfPresent([ResultItem].self, forKey: .becameFluent) ?? []
        slipped = try c.decodeIfPresent([ResultItem].self, forKey: .slipped) ?? []
    }
}
