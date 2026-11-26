import XCTest
@testable import Syll

@MainActor
final class LearningJourneyTests: XCTestCase {
    // Wednesday 2026-11-25 in the learner's zone: Monday and Wednesday studied, Thursday on ahead.
    static let json = #"""
    {"asOf":"2026-11-25T04:00:00.000Z","timezone":"Asia/Ho_Chi_Minh","historyAvailableFrom":"2026-08-01","historyComplete":true,
     "week":{"startDate":"2026-11-23","endDateExclusive":"2026-11-30","newWords":7,"completedSessions":3,"activeDays":2,"weeklySessionGoal":3,"recentWords":[{"wordId":"w1","lemma":"resilient"},{"wordId":"w2","lemma":"thrive"}],
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
        XCTAssertEqual(week.studiedDays.map(\.date), ["2026-11-23", "2026-11-25"])
        XCTAssertFalse(week.goalReached, "three sessions over two days is 2/3 study days")
        XCTAssertEqual(week.recentWords?.map(\.lemma), ["resilient", "thrive"])
        XCTAssertEqual(week.otherNewWords, 5)
        XCTAssertTrue(week.days[3].isFuture)
    }

    func testTheGoalCountsStudyDaysNotSessions() throws {
        let json = Self.json.replacingOccurrences(of: #""weeklySessionGoal":3"#, with: #""weeklySessionGoal":2"#)
        XCTAssertTrue(try APIClient.decoder.decode(LearningJourney.self, from: Data(json.utf8)).week.goalReached)
    }

    func testWithoutTopicsFromAnOlderBackendTheBreakdownIsNil() throws {
        XCTAssertNil(try Self.journey().period.newWordsByTopic)
    }

    func testDecodesNewWordsByTopic() throws {
        let json = Self.json.replacingOccurrences(of: #""reviewedMeanings":12,"#, with: #"""
        "reviewedMeanings":12,"newWordsByTopic":[
          {"topicId":"t-travel","title":"Travel","iosIcon":"airplane","color":"#3E68DB","count":5,"recentLemmas":["itinerary","layover","customs"],"finishedInPeriod":true},
          {"topicId":null,"title":null,"iosIcon":null,"count":2,"recentLemmas":["serendipity","thrive"],"finishedInPeriod":false},
          {"topicId":"t-food","title":"Food","count":1}],
        """#)
        let topics = try XCTUnwrap(try APIClient.decoder.decode(LearningJourney.self, from: Data(json.utf8)).period.newWordsByTopic)
        XCTAssertEqual(topics.map(\.key), ["t-travel", "none", "t-food"])
        XCTAssertTrue(topics[0].finishedInPeriod)
        XCTAssertEqual(topics[0].colorHex, 0x3E68DB)
        XCTAssertEqual(topics[0].recentLine, "itinerary, layover, customs…")
        XCTAssertTrue(topics[1].isOwnWords)
        XCTAssertEqual(topics[1].recentLine, "serendipity, thrive", "nothing more to hint at")
        XCTAssertEqual(topics[2].recentLemmas, [], "missing fields fall back")
        XCTAssertFalse(topics[2].finishedInPeriod)
        XCTAssertNil(topics[2].recentLine)
        XCTAssertNil(topics[2].colorHex)
    }

    func testTopicColourFallsBackForOwnWordsAndBadValues() {
        let topic = { (id: String?, color: String?) in TopicNewWords(topicId: id, title: nil, iosIcon: nil, color: color, count: 1) }
        XCTAssertEqual(topic("t", "#22387D").colorHex, 0x22387D)
        XCTAssertNil(topic("t", "22387D").colorHex)
        XCTAssertNil(topic("t", "#22387G").colorHex)
        XCTAssertNil(topic("t", "#+2387D").colorHex)
        XCTAssertNil(topic(nil, "#22387D").colorHex, "own words are always Ink 300")
    }

    func testFourTopicsShowThenTheRestFold() {
        let topics = (1...6).map { TopicNewWords(topicId: "t\($0)", title: nil, iosIcon: nil, count: 10 - $0) }
        let folded = TopicNewWords.visible(topics, expanded: false)
        XCTAssertEqual(folded.rows.map(\.key), ["t1", "t2", "t3", "t4"])
        XCTAssertEqual(folded.hidden, 2)
        XCTAssertEqual(TopicNewWords.visible(topics, expanded: true).rows.count, 6)
        XCTAssertEqual(TopicNewWords.visible(Array(topics.prefix(4)), expanded: false).hidden, 0)
    }

    func testMeaningsJoinWithADotAndKeepTheirCommas() throws {
        let page = try APIClient.decoder.decode(JourneyWordsPage.self, from: Data(#"""
        {"total":2,"items":[
          {"wordId":"a","lemma":"in","meaningTexts":["trong, ở trong","bằng"],"learnedOn":"2026-11-26"},
          {"wordId":"b","lemma":"clarify","meaningTexts":[],"learnedOn":"2026-11-24"}]}
        """#.utf8))
        XCTAssertEqual(page.items[0].glossary, "trong, ở trong · bằng")
        XCTAssertEqual(page.items[1].glossary, "")
    }

    func testTopicWordsPageByTopicAndPeriod() async throws {
        let api = StubVocabAPI()
        let word = { (id: String) in JourneyWord(wordId: id, lemma: id, meaningTexts: [], learnedOn: "2026-11-26") }
        api.journeyWordPages = [
            JourneyWordsPage(total: 3, items: [word("a"), word("b")]),
            JourneyWordsPage(total: 3, items: [word("c")]),
        ]
        let store = LearningJourneyStore(api: api)
        await store.loadTopicWords(.month, topic: "t-travel")
        await store.loadTopicWords(.month, topic: "t-travel", more: true)
        let key = LearningJourneyStore.TopicWordsKey(period: .month, topic: "t-travel")
        XCTAssertEqual(store.topicWords[key]?.map(\.wordId), ["a", "b", "c"])
        XCTAssertEqual(api.journeyWordRequests.map { $0.offset }, [0, 2])
        XCTAssertEqual(api.journeyWordRequests.map { $0.topic }, ["t-travel", "t-travel"])
        XCTAssertEqual(api.journeyWordRequests.map { $0.limit }, [LearningJourneyStore.wordPage, LearningJourneyStore.wordPage])
        await store.loadTopicWords(.month, topic: "t-travel", more: true)
        XCTAssertEqual(api.journeyWordRequests.count, 2, "nothing left to load")
        await store.loadTopicWords(.month, topic: "t-travel")
        XCTAssertEqual(api.journeyWordRequests.count, 2, "a loaded topic isn't asked for again unless forced")

        XCTAssertNil(store.topicWords[.init(period: .week, topic: "t-travel")], "each period keeps its own pages")
        XCTAssertNil(store.topicWords[.init(period: .month, topic: TopicNewWords.ownWordsKey)])
    }

    func testAFailedPageKeepsTheLoadedWords() async throws {
        let api = StubVocabAPI()
        api.journeyWordPages = [JourneyWordsPage(total: 3, items: [JourneyWord(wordId: "a", lemma: "a", meaningTexts: [], learnedOn: "2026-11-26")])]
        let store = LearningJourneyStore(api: api)
        let key = LearningJourneyStore.TopicWordsKey(period: .all, topic: "none")
        await store.loadTopicWords(.all, topic: "none")
        await store.loadTopicWords(.all, topic: "none", more: true)
        XCTAssertEqual(store.topicWords[key]?.map(\.wordId), ["a"])
        guard case .failed = store.topicWordLoads[key] else { return XCTFail("expected a failed load") }
        store.reset()
        XCTAssertTrue(store.topicWords.isEmpty)
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
