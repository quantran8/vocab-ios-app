import Foundation

/// What the detail sheet lists, as data: blocks of groups, the groups needing attention first.
struct ResultSheetBlock: Equatable, Identifiable {
    enum Title: Equatable {
        case review, newWords, answers, speaking
    }

    let section: ResultSection
    let title: Title
    var groups: [ResultSheetGroup]
    /// Practice: answers that could not judge a skill, and why.
    var excluded: PracticeSummary.Excluded? = nil
    /// Random: due words this practice counted as their review.
    var countedAsReview: [ResultItem] = []
    /// Speaking: how many recordings were said right, out of those scored.
    var spoken: SpokenTally? = nil

    struct SpokenTally: Equatable {
        let passed: Int
        let total: Int
    }

    var id: String { "\(section)-\(title)" }

    /// Counts for the proportion bar (strong, mid, weak), from the groups that have a level; nil when none does.
    var bar: [Int]? {
        let leveled = groups.filter { $0.kind.barLevel != nil }
        guard !leveled.isEmpty else { return nil }
        return (0..<3).map { level in leveled.filter { $0.kind.barLevel == level }.reduce(0) { $0 + $1.items.count } }
    }
}

struct ResultSheetGroup: Equatable, Identifiable {
    enum Kind: Equatable {
        case relearn, shaky, solid
        case revealed, retried, smooth, known
        case missed, helped, clean
        case notPassed, spokeRight
        case becameFluent, slipped
    }

    let kind: Kind
    let items: [ResultItem]
    var collapsedByDefault = false

    var id: String { "\(kind)" }
    /// Which part of the block's bar this group is; its header carries that part's swatch.
    var barLevel: Int? { kind.barLevel }
    /// Group headers with a "back on …" line: the items in a group come back at about the same time.
    var showsNextReview: Bool { [.relearn, .shaky, .solid, .revealed, .retried, .smooth, .known].contains(kind) }
}

extension ResultSheetGroup.Kind {
    /// 0 strong, 1 mid, 2 weak; nil for groups that are not a share of the block (known words, speaking changes).
    var barLevel: Int? {
        switch self {
        case .solid, .smooth, .clean, .spokeRight: 0
        case .shaky, .retried, .helped: 1
        case .relearn, .revealed, .missed, .notPassed: 2
        case .known, .becameFluent, .slipped: nil
        }
    }
}

enum ResultSheetModel {
    static func blocks(for result: PracticeResult) -> [ResultSheetBlock] {
        let summary = result.summary
        var blocks: [ResultSheetBlock]
        switch result.kind {
        case .daily:
            blocks = []
            if let review = summary.review {
                let g = review.groups
                blocks.append(ResultSheetBlock(section: .review, title: .review, groups: collapsing(.solid, in: [
                    ResultSheetGroup(kind: .relearn, items: g[.relearn]),
                    ResultSheetGroup(kind: .shaky, items: g[.shaky]),
                    ResultSheetGroup(kind: .solid, items: g[.solid]),
                ])))
            }
            if let newWords = summary.newWords {
                let g = newWords.groups
                blocks.append(ResultSheetBlock(section: .newWords, title: .newWords, groups: collapsing(.smooth, in: [
                    ResultSheetGroup(kind: .revealed, items: g[.revealed]),
                    ResultSheetGroup(kind: .retried, items: g[.retried]),
                    ResultSheetGroup(kind: .smooth, items: g[.smooth]),
                    ResultSheetGroup(kind: .known, items: g[.known]),
                ])))
            }
            blocks = blocks.filter { !$0.groups.isEmpty }
        case .randomPractice:
            blocks = randomBlocks(summary)
        case .weakPractice:
            blocks = answerBlocks(summary.practice ?? PracticeSummary())
        case .speakingPractice:
            blocks = []
        case .checkpoint:
            return []
        }
        if let speaking = speakingBlock(summary.speaking) { blocks.append(speaking) }
        return blocks
    }

    private static func randomBlocks(_ summary: CommitSummary) -> [ResultSheetBlock] {
        var blocks = answerBlocks(summary.practice ?? PracticeSummary())
        let counted = summary.countedAsReview ?? []
        if !counted.isEmpty {
            if blocks.isEmpty { blocks.append(ResultSheetBlock(section: .practice, title: .answers, groups: [])) }
            blocks[blocks.count - 1].countedAsReview = counted
        }
        return blocks
    }

    /// Every answer in one block; a block with only uncounted answers still says why they didn't count.
    private static func answerBlocks(_ practice: PracticeSummary) -> [ResultSheetBlock] {
        let groups = practiceGroups(practice.groups)
        guard !groups.isEmpty || (practice.excluded?.count ?? 0) > 0 else { return [] }
        return [ResultSheetBlock(section: .practice, title: .answers, groups: groups, excluded: practice.excluded)]
    }

    /// Present whenever a recording was scored, so the speaking tile always has a block to open.
    /// Every scored word, not passed first, each with its score; the status changes follow, collapsed.
    /// An older backend sent only the counts: then the "said right" line stands in for the two groups.
    private static func speakingBlock(_ speaking: SpeakingSummary?) -> ResultSheetBlock? {
        guard let speaking, speaking.total > 0 else { return nil }
        let results = speaking.groups.map { g in [
            ResultSheetGroup(kind: .notPassed, items: g[.notPassed]),
            ResultSheetGroup(kind: .spokeRight, items: g[.passed]),
        ] } ?? []
        let changes = [
            ResultSheetGroup(kind: .slipped, items: speaking.slipped),
            ResultSheetGroup(kind: .becameFluent, items: speaking.becameFluent),
        ].map { group in
            var group = group
            group.collapsedByDefault = speaking.groups != nil
            return group
        }
        return ResultSheetBlock(
            section: .speaking, title: .speaking, groups: nonEmpty(results + changes),
            spoken: speaking.groups == nil ? .init(passed: speaking.passed, total: speaking.total) : nil
        )
    }

    private static func practiceGroups(_ groups: ResultGroups<PracticeGroup>) -> [ResultSheetGroup] {
        collapsing(.clean, in: [
            ResultSheetGroup(kind: .missed, items: groups[.missed]),
            ResultSheetGroup(kind: .helped, items: groups[.helped]),
            ResultSheetGroup(kind: .clean, items: groups[.clean]),
        ])
    }

    /// Drops empty groups; `kind` starts collapsed when another group in the block has words.
    private static func collapsing(_ kind: ResultSheetGroup.Kind, in groups: [ResultSheetGroup]) -> [ResultSheetGroup] {
        let shown = nonEmpty(groups)
        return shown.map { group in
            var group = group
            group.collapsedByDefault = group.kind == kind && shown.count > 1
            return group
        }
    }

    private static func nonEmpty(_ groups: [ResultSheetGroup]) -> [ResultSheetGroup] {
        groups.filter { !$0.items.isEmpty }
    }
}

/// Relative dates for the sheet, in the learner's time zone.
enum ResultDateText {
    enum NextReview: Equatable {
        case tonight, tomorrow
        /// Within the coming week: the weekday's name.
        case weekday(Date)
        case inDays(Int)
    }

    static func nextReview(_ date: Date, now: Date, calendar: Calendar) -> NextReview {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return .tonight
        case 1: return .tomorrow
        case 2...6: return .weekday(date)
        default: return .inDays(days)
        }
    }

    /// The day a review word was learned, when that was within the last 7 days.
    static func recentlyLearned(_ learnedAt: Date?, now: Date, calendar: Calendar) -> Date? {
        guard let learnedAt else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: learnedAt), to: calendar.startOfDay(for: now)).day ?? .max
        return (0..<7).contains(days) ? learnedAt : nil
    }

    static func calendar(timeZone identifier: String?) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = identifier.flatMap(TimeZone.init(identifier:)) ?? .current
        calendar.locale = AppLanguage.active.locale
        return calendar
    }
}
