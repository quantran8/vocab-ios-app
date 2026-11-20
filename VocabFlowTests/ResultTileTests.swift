import XCTest
@testable import VocabFlow

/// The results screen rules ("Session Result Statistics" §4.3, §11) and the sheet's grouping.
final class ResultTileTests: XCTestCase {
    private func items(_ count: Int, _ prefix: String = "m", struggledAt: ResultSkill? = nil, skill: ResultSkill? = nil, status: SpeakingStatus? = nil) -> [ResultItem] {
        (0..<count).map { ResultItem(meaningId: "\(prefix)\($0)", struggledAt: struggledAt, skill: skill, status: status) }
    }

    private func review(solid: Int = 0, shaky: Int = 0, relearn: Int = 0) -> ReviewSummary {
        ReviewSummary(groups: ResultGroups([.solid: items(solid, "s"), .shaky: items(shaky, "h"), .relearn: items(relearn, "r")]))
    }

    // MARK: Review tile

    func testReviewTileNamesEveryWeakerGroup() {
        XCTAssertEqual(ResultTiles.reviewTile(review(solid: 7, shaky: 1, relearn: 1)),
                       ResultTile(kind: .review, number: .fraction(7, of: 9), caption: .remembered, lines: [.shaky(1), .relearn(1)]))
        // An empty group gets no line; the strong group is the number itself.
        XCTAssertEqual(ResultTiles.reviewTile(review(shaky: 3, relearn: 2)).lines, [.shaky(3), .relearn(2)])
        XCTAssertEqual(ResultTiles.reviewTile(review(solid: 2, relearn: 1)).lines, [.relearn(1)])
        XCTAssertEqual(ResultTiles.reviewTile(review(solid: 4)).lines, [])
    }

    func testReviewTileIsEmptyWithoutReviews() {
        for summary in [nil, review()] {
            XCTAssertEqual(ResultTiles.reviewTile(summary),
                           ResultTile(kind: .review, number: .none, caption: .noReviews, isEmpty: true))
        }
    }

    // MARK: New words tile

    func testNewWordsFractionLeavesKnownWordsOut() {
        let summary = NewWordSummary(groups: ResultGroups([
            .smooth: items(2), .retried: items(1, "t", struggledAt: .speaking), .revealed: items(1, "v", struggledAt: .speaking), .known: items(1, "k"),
        ]))
        let tile = ResultTiles.newWordsTile(summary)
        XCTAssertEqual(tile.number, .fraction(2, of: 4))
        XCTAssertEqual(tile.lines, [.neededRetry(1), .sawAnswer(1), .alreadyKnew(1)])
    }

    func testNewWordsTileEmptyOrOnlyKnown() {
        XCTAssertEqual(ResultTiles.newWordsTile(NewWordSummary()),
                       ResultTile(kind: .newWords, number: .none, caption: .noNewWords, isEmpty: true))
        let onlyKnown = ResultTiles.newWordsTile(NewWordSummary(groups: ResultGroups([.known: items(2)])))
        XCTAssertEqual(onlyKnown.number, .none)
        XCTAssertFalse(onlyKnown.isEmpty)
        XCTAssertEqual(onlyKnown.lines, [.alreadyKnew(2)])
    }

    // MARK: Practice tiles

    func testPracticeTileLines() {
        let missed = PracticeSummary(groups: ResultGroups([.clean: items(5), .helped: items(2, "h"), .missed: items(1, "x")]))
        XCTAssertEqual(ResultTiles.practiceTile(missed),
                       ResultTile(kind: .practice, number: .fraction(5, of: 8), caption: .practiceClean, lines: [.helped(2), .missed(1)]))
        XCTAssertEqual(ResultTiles.practiceTile(PracticeSummary(groups: ResultGroups([.clean: items(1), .helped: items(2, "h")]))).lines, [.helped(2)])
    }

    func testPracticeTileWithNothingMeasured() {
        let summary = PracticeSummary(total: 0, excluded: .init(count: 4, reasons: ["weak_template"]))
        XCTAssertEqual(ResultTiles.practiceTile(summary),
                       ResultTile(kind: .practice, number: .none, caption: .noSkillMeasured, isEmpty: true))
    }

    func testWeakTileShowsWhatIsLeftWithTheDelta() {
        XCTAssertEqual(ResultTiles.weakTile(NeedPracticeCount(before: 11, after: 8)),
                       ResultTile(kind: .weakRemaining, number: .count(8), caption: .weakRemaining, lines: [.weakDelta(-3)]))
        XCTAssertEqual(ResultTiles.weakTile(NeedPracticeCount(before: 4, after: 4)).lines, [])
    }

    func testWeakTileAtZeroCelebrates() {
        let tile = ResultTiles.weakTile(NeedPracticeCount(before: 1, after: 0))
        XCTAssertEqual(tile.caption, .noWeakWordsLeft)
        XCTAssertTrue(tile.celebrates)
        XCTAssertTrue(ResultTiles.weakTile(nil).isEmpty)
    }

    // MARK: Speaking tile

    func testSpeakingTileCountsWhatWasSaidRightAndNamesChanges() {
        let speaking = SpeakingSummary(total: 5, passed: 3, becameFluent: items(2, "f", status: .fluent), slipped: items(1, "s", status: .practicing))
        XCTAssertEqual(ResultTiles.speakingTile(speaking),
                       ResultTile(kind: .speaking, number: .fraction(3, of: 5), caption: .saidRight, lines: [.becameFluent(2), .slipped(1)]))
        XCTAssertEqual(ResultTiles.speakingTile(SpeakingSummary(total: 2, passed: 2)).lines, [])
    }

    func testSpeakingTileIsEmptyWithoutScoredRecordings() {
        XCTAssertTrue(ResultTiles.speakingTile(nil).isEmpty)
        XCTAssertTrue(ResultTiles.speakingTile(SpeakingSummary()).isEmpty)
    }

    func testSignedDeltaUsesARealMinus() {
        XCTAssertEqual(ResultTile.Line.signed(-3), "\u{2212}3")
        XCTAssertEqual(ResultTile.Line.signed(2), "+2")
    }

    // MARK: Tile set

    func testEachModeShowsOnlyTheTilesWithSomethingToSay() {
        let both = PracticeResult(kind: .daily, summary: CommitSummary(review: review(solid: 1), newWords: NewWordSummary(groups: ResultGroups([.smooth: items(1)]))))
        XCTAssertEqual(both.tiles?.map(\.kind), [.review, .newWords])
        let spoken = SpeakingSummary(total: 1, passed: 1)
        let dailySpeaking = PracticeResult(kind: .daily, summary: CommitSummary(review: review(solid: 1), newWords: NewWordSummary(), speaking: spoken))
        XCTAssertEqual(dailySpeaking.tiles?.map(\.kind), [.review, .speaking])
        // Review only: no new-word tile at all, not an empty one.
        let reviewOnly = PracticeResult(kind: .daily, summary: CommitSummary(review: review(solid: 1), newWords: NewWordSummary()))
        XCTAssertEqual(reviewOnly.tiles?.map(\.kind), [.review])

        let practice = CommitSummary(practice: PracticeSummary(groups: ResultGroups([.clean: items(1)])), speaking: spoken,
                                     needPractice: NeedPracticeCount(before: 2, after: 1))
        XCTAssertEqual(PracticeResult(kind: .randomPractice, summary: practice).tiles?.map(\.kind), [.practice, .speaking])
        XCTAssertEqual(PracticeResult(kind: .weakPractice, summary: practice).tiles?.map(\.kind), [.practice, .weakRemaining])
        let unmeasured = CommitSummary(practice: PracticeSummary())
        XCTAssertEqual(PracticeResult(kind: .randomPractice, summary: unmeasured).tiles?.map(\.kind), [])
        XCTAssertEqual(PracticeResult(kind: .weakPractice, summary: unmeasured).tiles?.map(\.kind), [])
        XCTAssertEqual(PracticeResult(kind: .speakingPractice, summary: CommitSummary(speaking: spoken)).tiles?.map(\.kind), [.speaking])
    }

    func testOlderBackendsAndCheckpointsUseTheCountGrid() {
        XCTAssertNil(PracticeResult(kind: .daily, summary: CommitSummary(newWordGoalSlots: 2, reviewedMeanings: 1, practiceTasks: 8)).tiles)
        XCTAssertNil(PracticeResult(kind: .randomPractice, summary: CommitSummary(practiceTasks: 8)).tiles)
        XCTAssertNil(PracticeResult(kind: .checkpoint, summary: CommitSummary(review: review(solid: 1))).tiles)
    }

    // MARK: Sheet

    func testDailySheetPutsWhatNeedsAttentionFirstAndFoldsTheEasyGroup() {
        let result = PracticeResult(kind: .daily, summary: CommitSummary(review: review(solid: 3, relearn: 1), newWords: NewWordSummary(groups: ResultGroups([.smooth: items(2)]))))
        let blocks = ResultSheetModel.blocks(for: result)
        XCTAssertEqual(blocks.map(\.section), [.review, .newWords])
        XCTAssertEqual(blocks[0].groups.map(\.kind), [.relearn, .solid])
        XCTAssertEqual(blocks[0].groups.map(\.collapsedByDefault), [false, true])
        // Alone in its block, the easy group stays open.
        XCTAssertEqual(blocks[1].groups.map(\.collapsedByDefault), [false])
        // The bar sits in the sheet: one per block, from its groups.
        XCTAssertEqual(blocks[0].bar, [3, 0, 1])
        XCTAssertEqual(blocks[1].bar, [2, 0, 0])
    }

    func testWeakSheetListsEveryAnswerInOneBlock() {
        let practice = PracticeSummary(excluded: .init(count: 1, reasons: ["unavailable"]), groups: ResultGroups([
            .clean: [ResultItem(meaningId: "a", skill: .listening)],
            .missed: [ResultItem(meaningId: "b", skill: .spelling), ResultItem(meaningId: "c", skill: nil)],
        ]))
        let blocks = ResultSheetModel.blocks(for: PracticeResult(kind: .weakPractice, summary: CommitSummary(practice: practice)))
        XCTAssertEqual(blocks.map(\.title), [.answers])
        XCTAssertEqual(blocks[0].groups.map(\.kind), [.missed, .clean])
        XCTAssertEqual(blocks[0].groups[0].items.map(\.meaningId), ["b", "c"])
        XCTAssertEqual(blocks[0].excluded?.count, 1)
    }

    func testSpeakingBlockFollowsTheOthersWhenARecordingWasScored() {
        let speaking = SpeakingSummary(total: 3, passed: 2, becameFluent: items(1, "f", status: .fluent), slipped: items(1, "s", status: .practicing))
        let daily = ResultSheetModel.blocks(for: PracticeResult(kind: .daily, summary: CommitSummary(review: review(solid: 1), speaking: speaking)))
        XCTAssertEqual(daily.map(\.section), [.review, .speaking])
        XCTAssertEqual(daily[1].groups.map(\.kind), [.slipped, .becameFluent])
        XCTAssertEqual(daily[1].spoken, .init(passed: 2, total: 3))
        XCTAssertNil(daily[1].bar)

        // No status changed: the block still says how it went, so the tile has somewhere to open.
        let quiet = ResultSheetModel.blocks(for: PracticeResult(kind: .speakingPractice, summary: CommitSummary(speaking: SpeakingSummary(total: 2, passed: 1))))
        XCTAssertEqual(quiet.map(\.title), [.speaking])
        XCTAssertEqual(quiet[0].groups, [])
        XCTAssertTrue(ResultSheetModel.blocks(for: PracticeResult(kind: .speakingPractice, summary: CommitSummary())).isEmpty)
    }

    func testRandomSheetListsAnswersThenTheReviewsTheyCounted() {
        let practice = PracticeSummary(groups: ResultGroups([
            .clean: [ResultItem(meaningId: "a", skill: .spelling), ResultItem(meaningId: "b", skill: .listening)],
        ]))
        let result = PracticeResult(kind: .randomPractice, summary: CommitSummary(practice: practice, countedAsReview: [ResultItem(meaningId: "a")]))
        let blocks = ResultSheetModel.blocks(for: result)
        XCTAssertEqual(blocks.map(\.title), [.answers])
        XCTAssertEqual(blocks[0].groups.map(\.kind), [.clean])
        XCTAssertEqual(blocks[0].countedAsReview.map(\.meaningId), ["a"])
    }

    // MARK: Dates

    func testNextReviewIsRelativeInTheLearnersTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let now = ISO8601DateFormatter().date(from: "2026-11-13T10:00:00Z")! // 17:00 local
        let at = { (iso: String) in ISO8601DateFormatter().date(from: iso)! }
        XCTAssertEqual(ResultDateText.nextReview(at("2026-11-13T15:00:00Z"), now: now, calendar: calendar), .tonight)
        // 01:00 UTC on the 14th is already the 14th in Hanoi.
        XCTAssertEqual(ResultDateText.nextReview(at("2026-11-13T18:00:00Z"), now: now, calendar: calendar), .tomorrow)
        let sunday = at("2026-11-15T05:00:00Z")
        XCTAssertEqual(ResultDateText.nextReview(sunday, now: now, calendar: calendar), .weekday(sunday))
        XCTAssertEqual(ResultDateText.nextReview(at("2026-11-25T05:00:00Z"), now: now, calendar: calendar), .inDays(12))
        XCTAssertNotNil(ResultDateText.recentlyLearned(at("2026-11-09T05:00:00Z"), now: now, calendar: calendar))
        XCTAssertNil(ResultDateText.recentlyLearned(at("2026-11-01T05:00:00Z"), now: now, calendar: calendar))
    }

    // MARK: Lab fixtures

    func testBundledResultFixturesDecodeAndShowTiles() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "results_lab", withExtension: "json"))
        let fixtures = try ResultLabFixtures.decode(Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(fixtures.count, 5)
        XCTAssertEqual(Set(fixtures.map(\.id)).count, fixtures.count)
        for fixture in fixtures {
            XCTAssertNotNil(fixture.result.tiles, fixture.id)
        }
        XCTAssertEqual(Set(fixtures.map(\.result.kind)), [.daily, .randomPractice, .weakPractice, .speakingPractice])
    }
}
