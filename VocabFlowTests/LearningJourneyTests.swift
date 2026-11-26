import XCTest
@testable import VocabFlow

@MainActor
final class LearningJourneyTests: XCTestCase {
    // Wednesday 2026-11-25 in the learner's zone: Monday and Wednesday studied, Thursday on ahead.
    static let json = #"""
    {"asOf":"2026-11-25T04:00:00.000Z","timezone":"Asia/Ho_Chi_Minh","historyAvailableFrom":"2026-08-01","historyComplete":true,
     "week":{"startDate":"2026-11-23","endDateExclusive":"2026-11-30","newWords":7,"completedSessions":3,"activeDays":2,"weeklySessionGoal":3,
       "days":[{"date":"2026-11-23","completed":true,"completedSessions":2,"newWords":5},
               {"date":"2026-11-24","completed":false,"completedSessions":0,"newWords":0},
               {"date":"2026-11-25","completed":true,"completedSessions":1,"newWords":2},
               {"date":"2026-11-26","completed":null,"completedSessions":null,"newWords":null},
               {"date":"2026-11-27","completed":null,"completedSessions":null,"newWords":null},
               {"date":"2026-11-28","completed":null,"completedSessions":null,"newWords":null},
               {"date":"2026-11-29","completed":null,"completedSessions":null,"newWords":null}]},
     "period":{"kind":"week","startDate":"2026-11-23","endDateExclusive":"2026-11-30","bucketGranularity":"day",
       "wordsAtStart":241,"wordsAtEnd":248,"newWords":7,"activeDays":2,"completedSessions":3,"reviewedMeanings":12,
       "points":[{"date":"2026-11-23","cumulativeWords":246},{"date":"2026-11-24","cumulativeWords":246},{"date":"2026-11-25","cumulativeWords":248}]}}
    """#

    static func journey() throws -> LearningJourney {
        try APIClient.decoder.decode(LearningJourney.self, from: Data(json.utf8))
    }

    func testDecodesTheWeekAndTellsTodayFromTheDaysAhead() throws {
        let week = try Self.journey().week
        XCTAssertEqual(week.today?.date, "2026-11-25")
        XCTAssertEqual(week.cumulativeNewWords, [5, 5, 7])
        XCTAssertTrue(week.goalReached)
        XCTAssertTrue(week.days[3].isFuture)
    }

    func testAGoallessWeekIsNeverReached() throws {
        let json = Self.json.replacingOccurrences(of: #""weeklySessionGoal":3"#, with: #""weeklySessionGoal":null"#)
        let week = try APIClient.decoder.decode(LearningJourney.self, from: Data(json.utf8)).week
        XCTAssertNil(week.weeklySessionGoal)
        XCTAssertFalse(week.goalReached)
    }

    func testANewLearnerHasNoHistory() throws {
        let json = Self.json.replacingOccurrences(of: #""historyAvailableFrom":"2026-08-01""#, with: #""historyAvailableFrom":null"#)
        XCTAssertFalse(try APIClient.decoder.decode(LearningJourney.self, from: Data(json.utf8)).hasHistory)
    }

    func testKeepsTheLastSummaryWhenARefreshFails() async throws {
        let api = StubVocabAPI()
        api.journeyResults[.week] = .success(try Self.journey())
        let store = LearningJourneyStore(api: api)
        await store.refreshSummary()
        XCTAssertNotNil(store.summary)

        api.journeyResults[.week] = .failure(.transport)
        await store.refreshSummary(force: true)
        XCTAssertNotNil(store.summary, "a failed refresh must not blank the card")
        guard case .failed = store.summaryLoad else { return XCTFail("expected a failed load") }
    }

    func testAFreshSummaryIsNotReloaded() async throws {
        let api = StubVocabAPI()
        api.journeyResults[.week] = .success(try Self.journey())
        let store = LearningJourneyStore(api: api)
        await store.refreshSummary()
        await store.refreshSummary()
        XCTAssertEqual(api.journeyPeriodsRequested, [.week])
        await store.refreshSummary(force: true)
        XCTAssertEqual(api.journeyPeriodsRequested, [.week, .week])
    }

    func testResetDropsEverythingForTheNextAccount() async throws {
        let api = StubVocabAPI()
        api.journeyResults[.month] = .success(try Self.journey())
        let store = LearningJourneyStore(api: api)
        await store.load(.month)
        XCTAssertNotNil(store.periods[.month])
        store.reset()
        XCTAssertNil(store.summary)
        XCTAssertTrue(store.periods.isEmpty)
    }
}

@MainActor
final class ContentReportTests: XCTestCase {
    private let target = ContentReportTarget(
        context: .practiceTask(sessionID: "s1", taskID: "t1", excerpt: ReportAttemptExcerpt(submittedText: "resilient")),
        subtitle: nil,
        reasons: ContentReportTarget.taskReasons(canAppeal: true, hasAudio: false)
    )

    private func json(_ request: ContentReportRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any]
    }

    func testOnlyTheAppealCarriesTheAnswer() throws {
        let appeal = ContentReportRequest(clientReportId: "k", source: .practiceTask, reason: .answerShouldBeAccepted, context: target.context, note: nil)
        let context = try json(appeal)["context"] as! [String: Any]
        XCTAssertEqual(context["taskId"] as? String, "t1")
        XCTAssertEqual((context["attemptExcerpt"] as? [String: Any])?["submittedText"] as? String, "resilient")

        let question = ContentReportRequest(clientReportId: "k", source: .practiceTask, reason: .incorrectQuestion, context: target.context, note: nil)
        XCTAssertNil((try json(question)["context"] as! [String: Any])["attemptExcerpt"])
    }

    func testReasonsFollowWhatTheContentHas() {
        XCTAssertEqual(ContentReportTarget.meaningReasons(hasDefinition: false, hasExample: true, hasAudio: false),
                       [.incorrectMeaning, .incorrectExample, .other])
        XCTAssertFalse(ContentReportTarget.taskReasons(canAppeal: false, hasAudio: true).contains(.answerShouldBeAccepted))
        XCTAssertEqual(ContentReportTarget.taskReasons(canAppeal: true, hasAudio: true).last, .other)
    }

    func testARetryReusesTheKeyAndAnAnswerSpendsIt() async {
        let api = StubVocabAPI()
        var ids = ["k1", "k2", "k3"]
        let store = ContentReportStore(api: api, makeID: { ids.removeFirst() })
        api.contentReportResults = [.failure(.transport), .success(ContentReportReceipt(reportId: "r", duplicate: false))]

        let first = await store.submit(target, reason: .incorrectQuestion, note: " typo ")
        XCTAssertFalse(first)
        let second = await store.submit(target, reason: .incorrectQuestion, note: "typo")
        XCTAssertTrue(second)
        XCTAssertEqual(api.contentReports.map(\.clientReportId), ["k1", "k1"])
        XCTAssertEqual(api.contentReports.last?.note, "typo")

        _ = await store.submit(target, reason: .incorrectQuestion, note: "typo")
        XCTAssertEqual(api.contentReports.last?.clientReportId, "k3", "a new send after success is a new report")
    }

    func testAChangedReportGetsANewKey() async {
        let api = StubVocabAPI()
        var ids = ["k1", "k2"]
        let store = ContentReportStore(api: api, makeID: { ids.removeFirst() })
        api.contentReportResults = [.failure(.transport)]
        _ = await store.submit(target, reason: .incorrectQuestion, note: "")
        _ = await store.submit(target, reason: .incorrectMeaning, note: "")
        XCTAssertEqual(api.contentReports.map(\.clientReportId), ["k1", "k2"])
    }

    func testAnOwnEditIsExplained() async {
        let api = StubVocabAPI()
        let store = ContentReportStore(api: api)
        api.contentReportResults = [.failure(.server(status: 422, code: "REPORT_TARGET_OVERRIDDEN", message: "", retryable: false, requestID: nil))]
        let sent = await store.submit(target, reason: .incorrectMeaning, note: "")
        XCTAssertFalse(sent)
        XCTAssertEqual(store.phase, .failed(ContentReportStore.message(for: .server(status: 422, code: "REPORT_TARGET_OVERRIDDEN", message: "", retryable: false, requestID: nil))))
    }

    func testAJudgedWrongAnswerCanBeAppealed() {
        var attempt = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        XCTAssertFalse(attempt.canAppealAnswer, "no appeal before an answer")
        _ = attempt.submitText("clarifyy")
        XCTAssertTrue(attempt.canAppealAnswer)
        XCTAssertEqual(attempt.reportExcerpt?.submittedText, "clarifyy")

        var solved = TaskAttempt(task: PracticeFixtures.typing(), phase: .dueReview)
        _ = solved.submitText("clarify")
        XCTAssertFalse(solved.canAppealAnswer, "an accepted answer has nothing to appeal")
    }
}
