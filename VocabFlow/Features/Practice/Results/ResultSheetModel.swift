import Foundation

/// What the detail sheet lists, as data: blocks of groups, the groups needing attention first.
struct ResultSheetBlock: Equatable, Identifiable {
    enum Title: Equatable {
        case review, newWords, answers, answersFor(ResultSkill), skillChanges, weakWords, frequentMistakes
    }

    let section: ResultSection
    let title: Title
    var groups: [ResultSheetGroup]
    /// Practice: answers that could not judge a skill, and why.
    var excluded: PracticeSummary.Excluded? = nil
    /// Random: due words this practice counted as their review.
    var countedAsReview: [ResultItem] = []

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
        case regressed, leveledUp
        case stillNeedsPractice, waitingToConfirm, settled
    }

    let kind: Kind
    let items: [ResultItem]
    var collapsedByDefault = false
    /// Weak practice: a pair without a skill issue is only "a frequent mistake lately".
    var marksFrequentMistakes = false

    var id: String { "\(kind)" }
    /// Which part of the block's bar this group is; its header carries that part's swatch.
    var barLevel: Int? { kind.barLevel }
    /// Group headers with a "back on …" line: the items in a group come back at about the same time.
    var showsNextReview: Bool { [.relearn, .shaky, .solid, .revealed, .retried, .smooth, .known].contains(kind) }
}

extension ResultSheetGroup.Kind {
    /// 0 strong, 1 mid, 2 weak; nil for groups that are not a share of the block (known words, skill changes).
    var barLevel: Int? {
        switch self {
        case .solid, .smooth, .clean: 0
        case .shaky, .retried, .helped: 1
        case .relearn, .revealed, .missed: 2
        case .known, .regressed, .leveledUp, .stillNeedsPractice, .waitingToConfirm, .settled: nil
        }
    }
}

enum ResultSheetModel {
    static func blocks(for result: PracticeResult) -> [ResultSheetBlock] {
        let summary = result.summary
        switch result.kind {
        case .daily:
            var blocks: [ResultSheetBlock] = []
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
            return blocks.filter { !$0.groups.isEmpty }
        case .randomPractice:
            return randomBlocks(summary, chosenSkills: result.chosenSkills)
        case .weakPractice:
            return weakBlocks(summary)
        case .checkpoint:
            return []
        }
    }

    private static func randomBlocks(_ summary: CommitSummary, chosenSkills: [PracticeSkill]?) -> [ResultSheetBlock] {
        let practice = summary.practice ?? PracticeSummary()
        let answers = practiceGroups(practice.groups) { _ in true }
        var blocks: [ResultSheetBlock] = []
        if let chosenSkills, !chosenSkills.isEmpty {
            // Chosen skills: the answers are grouped by skill first.
            let skills = chosenSkills.compactMap { ResultSkill(rawValue: $0.rawValue) }
            for skill in skills {
                let groups = practiceGroups(practice.groups) { $0.skill == skill }
                if !groups.isEmpty { blocks.append(ResultSheetBlock(section: .practice, title: .answersFor(skill), groups: groups)) }
            }
            if !blocks.isEmpty {
                blocks[blocks.count - 1].excluded = practice.excluded
            }
        } else if !answers.isEmpty {
            blocks.append(ResultSheetBlock(section: .practice, title: .answers, groups: answers, excluded: practice.excluded))
        }
        if blocks.isEmpty, let excluded = practice.excluded, excluded.count > 0 {
            blocks.append(ResultSheetBlock(section: .practice, title: .answers, groups: [], excluded: excluded))
        }
        let changes = summary.skillChanges ?? ResultGroups()
        let skillGroups = nonEmpty([
            ResultSheetGroup(kind: .regressed, items: changes[.regressed]),
            ResultSheetGroup(kind: .leveledUp, items: changes[.leveledUp]),
        ])
        let counted = summary.countedAsReview ?? []
        if !skillGroups.isEmpty || !counted.isEmpty {
            blocks.append(ResultSheetBlock(section: .skills, title: .skillChanges, groups: skillGroups, countedAsReview: counted))
        }
        return blocks
    }

    private static func weakBlocks(_ summary: CommitSummary) -> [ResultSheetBlock] {
        let practice = summary.practice ?? PracticeSummary()
        let changes = summary.skillChanges ?? ResultGroups()
        let pairs = Set((changes[.pendingConfirm] + changes[.cleared]).map { "\($0.meaningId)|\($0.skill?.rawValue ?? "")" })
        let hadIssue = { (item: ResultItem) in item.hadIssue != false }
        let stillNeeds = (practice.groups[.missed] + practice.groups[.helped])
            .filter { hadIssue($0) && !pairs.contains("\($0.meaningId)|\($0.skill?.rawValue ?? "")") }
        let weak = nonEmpty([
            ResultSheetGroup(kind: .stillNeedsPractice, items: stillNeeds),
            ResultSheetGroup(kind: .waitingToConfirm, items: changes[.pendingConfirm]),
            ResultSheetGroup(kind: .settled, items: changes[.cleared]),
        ])
        var blocks: [ResultSheetBlock] = []
        if !weak.isEmpty {
            let collapsed = weak.map { group in
                var group = group
                group.collapsedByDefault = group.kind == .settled && weak.count > 1
                return group
            }
            blocks.append(ResultSheetBlock(section: .skills, title: .weakWords, groups: collapsed))
        }
        // Words picked for frequent mistakes, not for a skill issue: only how the answers went.
        let frequent = practiceGroups(practice.groups) { !hadIssue($0) }.map { group in
            var group = group
            group.marksFrequentMistakes = true
            return group
        }
        if !frequent.isEmpty || (practice.excluded?.count ?? 0) > 0 {
            blocks.append(ResultSheetBlock(section: .practice, title: .frequentMistakes, groups: frequent, excluded: practice.excluded))
        }
        return blocks
    }

    private static func practiceGroups(_ groups: ResultGroups<PracticeGroup>, where keep: (ResultItem) -> Bool) -> [ResultSheetGroup] {
        collapsing(.clean, in: [
            ResultSheetGroup(kind: .missed, items: groups[.missed].filter(keep)),
            ResultSheetGroup(kind: .helped, items: groups[.helped].filter(keep)),
            ResultSheetGroup(kind: .clean, items: groups[.clean].filter(keep)),
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
