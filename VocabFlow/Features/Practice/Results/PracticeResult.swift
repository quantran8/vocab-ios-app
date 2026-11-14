import Foundation

/// Everything the results screen shows. Built from the last commit, with a daily chain's review merged in.
struct PracticeResult: Equatable, Decodable {
    enum Kind: String, Decodable {
        case daily, randomPractice, weakPractice, checkpoint
    }

    var kind: Kind
    var summary: CommitSummary
    /// Random practice on chosen skills groups its answers by skill first.
    var chosenSkills: [PracticeSkill]? = nil

    init(kind: Kind, summary: CommitSummary, chosenSkills: [PracticeSkill]? = nil) {
        self.kind = kind
        self.summary = summary
        self.chosenSkills = chosenSkills
    }

    init(mode: SessionMode, summary: CommitSummary, chosenSkills: [PracticeSkill]?) {
        let kind: Kind = switch mode {
        case .daily: .daily
        case .randomPractice: .randomPractice
        case .weakWordsPractice: .weakPractice
        case .checkpointChallenge: .checkpoint
        }
        self.init(kind: kind, summary: summary, chosenSkills: chosenSkills)
    }

    /// The tiles with something to show (an empty one is left out), or nil when this commit has no result groups
    /// (checkpoint, or an older backend). LP is not a tile: the LP card below already shows it.
    var tiles: [ResultTile]? { ResultTiles.tiles(for: self) }
}

/// A part of the detail sheet; tapping a tile scrolls to it.
enum ResultSection: Hashable {
    case review, newWords, practice, skills
}

/// What a tile shows, as data, so the rules can be tested without SwiftUI.
struct ResultTile: Equatable, Identifiable {
    enum Kind: Hashable {
        case review, newWords, practice, skillsLeveledUp, weakRemaining
    }

    enum Number: Equatable {
        /// "—"
        case none
        case fraction(Int, of: Int)
        /// "+3"
        case plus(Int)
        case count(Int)
    }

    enum Caption: Equatable {
        case remembered, noReviews
        case pickedUp, noNewWords
        case practiceClean, noSkillMeasured
        case skillsLeveledUp
        case weakRemaining, noWeakWordsLeft
    }

    enum Line: Equatable {
        case relearn(Int), shaky(Int)
        case neededRetry(Int), sawAnswer(Int), alreadyKnew(Int)
        case missed(Int), helped(Int)
        case regressed(Int), newlyVerified(Int), verifiedHint
        /// Signed change in weak words since before the session.
        case weakDelta(Int), weakPending(Int)
    }

    let kind: Kind
    let number: Number
    let caption: Caption
    /// The weaker parts first (zeros left out), then any other note. The proportion bar lives on the sheet.
    var lines: [Line] = []
    /// Nothing to report: the screen leaves the tile out.
    var isEmpty = false
    /// Weak practice cleared every weak word.
    var celebrates = false

    var id: Kind { kind }

    var section: ResultSection {
        switch kind {
        case .review: .review
        case .newWords: .newWords
        case .practice: .practice
        case .skillsLeveledUp, .weakRemaining: .skills
        }
    }
}

/// The tile rules from "Session Result Statistics" §4.3 and §11. Pure: the server already chose every group.
enum ResultTiles {
    static func tiles(for result: PracticeResult) -> [ResultTile]? {
        let summary = result.summary
        let tiles: [ResultTile]
        switch result.kind {
        case .daily:
            guard summary.review != nil || summary.newWords != nil else { return nil }
            tiles = [reviewTile(summary.review), newWordsTile(summary.newWords)]
        case .randomPractice:
            guard summary.practice != nil else { return nil }
            tiles = [practiceTile(summary.practice), skillsTile(summary.skillChanges)]
        case .weakPractice:
            guard summary.practice != nil else { return nil }
            tiles = [practiceTile(summary.practice), weakTile(summary.needPractice, changes: summary.skillChanges)]
        case .checkpoint:
            return nil
        }
        return tiles.filter { !$0.isEmpty }
    }

    static func reviewTile(_ review: ReviewSummary?) -> ResultTile {
        let groups = review?.groups ?? ResultGroups()
        let (solid, shaky, relearn) = (groups.count(.solid), groups.count(.shaky), groups.count(.relearn))
        let total = solid + shaky + relearn
        guard total > 0 else { return ResultTile(kind: .review, number: .none, caption: .noReviews, isEmpty: true) }
        return ResultTile(kind: .review, number: .fraction(solid, of: total), caption: .remembered,
                          lines: parts(.shaky(shaky), shaky, .relearn(relearn), relearn))
    }

    /// Known words sit outside the fraction: they skipped learning, so they say nothing about how it went.
    static func newWordsTile(_ newWords: NewWordSummary?) -> ResultTile {
        let groups = newWords?.groups ?? ResultGroups()
        let (smooth, retried, revealed, known) = (groups.count(.smooth), groups.count(.retried), groups.count(.revealed), groups.count(.known))
        let total = smooth + retried + revealed
        let knew: [ResultTile.Line] = known > 0 ? [.alreadyKnew(known)] : []
        if total == 0 {
            guard known > 0 else { return ResultTile(kind: .newWords, number: .none, caption: .noNewWords, isEmpty: true) }
            return ResultTile(kind: .newWords, number: .none, caption: .pickedUp, lines: knew)
        }
        // Where each word stumbled is on the sheet, per word.
        return ResultTile(kind: .newWords, number: .fraction(smooth, of: total), caption: .pickedUp,
                          lines: parts(.neededRetry(retried), retried, .sawAnswer(revealed), revealed) + knew)
    }

    static func practiceTile(_ practice: PracticeSummary?) -> ResultTile {
        let groups = practice?.groups ?? ResultGroups()
        let (clean, helped, missed) = (groups.count(.clean), groups.count(.helped), groups.count(.missed))
        let total = clean + helped + missed
        guard total > 0 else { return ResultTile(kind: .practice, number: .none, caption: .noSkillMeasured, isEmpty: true) }
        return ResultTile(kind: .practice, number: .fraction(clean, of: total), caption: .practiceClean,
                          lines: parts(.helped(helped), helped, .missed(missed), missed))
    }

    static func skillsTile(_ changes: ResultGroups<SkillChangeGroup>?) -> ResultTile {
        let changes = changes ?? ResultGroups()
        let leveled = changes.count(.leveledUp)
        let regressed = changes.count(.regressed)
        let verified = changes[.leveledUp].filter { $0.to == .verified }.count
        let lines: [ResultTile.Line]
        if regressed > 0 {
            lines = [.regressed(regressed)]
        } else if verified > 0 {
            lines = [.newlyVerified(verified)]
        } else if leveled == 0 {
            // Practising all day and still at 0 is what this line explains.
            lines = [.verifiedHint]
        } else {
            lines = []
        }
        return ResultTile(kind: .skillsLeveledUp, number: leveled > 0 ? .plus(leveled) : .count(0), caption: .skillsLeveledUp, lines: lines)
    }

    /// Shows what is left, not what was cleared: the delta line says what this session did.
    static func weakTile(_ count: NeedPracticeCount?, changes: ResultGroups<SkillChangeGroup>?) -> ResultTile {
        guard let after = count?.after else { return ResultTile(kind: .weakRemaining, number: .none, caption: .weakRemaining, isEmpty: true) }
        var lines: [ResultTile.Line] = []
        if let before = count?.before, before != after {
            lines.append(.weakDelta(after - before))
        }
        let pending = changes?.count(.pendingConfirm) ?? 0
        if pending > 0 { lines.append(.weakPending(pending)) }
        return ResultTile(kind: .weakRemaining, number: .count(after), caption: after == 0 ? .noWeakWordsLeft : .weakRemaining,
                          lines: lines, celebrates: after == 0)
    }

    /// The weaker groups, by name and count; an empty one gets no line.
    private static func parts(_ mid: ResultTile.Line, _ midCount: Int, _ weak: ResultTile.Line, _ weakCount: Int) -> [ResultTile.Line] {
        (midCount > 0 ? [mid] : []) + (weakCount > 0 ? [weak] : [])
    }
}
