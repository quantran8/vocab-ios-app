import XCTest
@testable import Syll

/// Freemium (backend FRONTEND_FLOW §16): wire decoding, the topic limit, the Home card, free speaking and purchases.
@MainActor
final class PremiumTests: XCTestCase {
    private let api = StubVocabAPI()
    private let recorder = StubRecorder()
    private let transcriber = StubTranscriber()

    // MARK: Decoding

    func testDecodesThePlanAndFeatures() throws {
        let json = #"""
        {"id":"0193f0a0-0000-7000-8000-000000000001","proficiencyLevel":"B1","learningLevel":null,
         "settings":{"explanationLocale":"vi-VN","uiLocale":"vi-VN","timeZone":"Asia/Ho_Chi_Minh","dailyNewWordGoal":5},
         "scope":null,
         "plan":{"tier":"free","premiumUntil":null,"source":null,"productId":null,"autoRenew":null,
                 "limits":{"maxTopics":3,"maxNewWords":150,"newWordsUsed":140}},
         "features":{"freemiumEnabled":true,"redeemEnabled":false}}
        """#
        let profile = try APIClient.decoder.decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.plan?.tier, .free)
        XCTAssertEqual(profile.plan?.limits?.newWordsLeft, 10)
        XCTAssertEqual(profile.features?.redeemEnabled, false)
    }

    func testAnOlderBackendLimitsNothing() throws {
        let json = #"""
        {"id":"u1","proficiencyLevel":null,"learningLevel":null,
         "settings":{"explanationLocale":"vi-VN","uiLocale":"vi-VN","timeZone":"Asia/Ho_Chi_Minh","dailyNewWordGoal":5},"scope":null}
        """#
        let profile = try APIClient.decoder.decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertNil(profile.plan)
        XCTAssertNil(profile.features)
    }

    func testUnknownTierAndSourceStillDecode() throws {
        let plan = try APIClient.decoder.decode(PremiumPlan.self, from: Data(#"{"tier":"gold","source":"play"}"#.utf8))
        XCTAssertEqual(plan.tier, .free)
        XCTAssertEqual(plan.source, .unknown)
        XCTAssertEqual(try APIClient.decoder.decode(NewWordReason.self, from: Data(#""free_limit""#.utf8)), .freeLimit)
    }

    // MARK: Topic limit

    func testTopicLimitRefusesToAddButAlwaysRemoves() {
        var preferences = LearningPreferences.default
        preferences.selectCollection("business")
        let ids = Array(TopicCatalog.collection(id: "business")!.topicIDs).sorted()
        XCTAssertTrue(preferences.toggleTopic(ids[0], limit: 2))
        XCTAssertTrue(preferences.toggleTopic(ids[1], limit: 2))
        XCTAssertFalse(preferences.toggleTopic(ids[2], limit: 2))
        XCTAssertEqual(preferences.topicIDs.count, 2)
        XCTAssertTrue(preferences.toggleTopic(ids[0], limit: 2))
        XCTAssertEqual(preferences.topicIDs.count, 1)
    }

    func testSelectAllOnlyClearsUnderALimitTheCollectionExceeds() {
        var preferences = LearningPreferences.default
        preferences.selectCollection("business")
        XCTAssertTrue(preferences.limitsTopics(3))
        preferences.toggleAllTopics(limit: 3)
        XCTAssertTrue(preferences.topicIDs.isEmpty)
        preferences.toggleAllTopics(limit: 50)
        XCTAssertTrue(preferences.hasAllTopics)
    }

    // MARK: Home card

    private func home(effective: Int, remaining: Int) -> LearnHome {
        LearnHome(dueCount: 4, checkpointAvailable: 0, checkpointSessionsDone: 0, checkpointSessionsRequired: 7, learnedTotal: 150,
                  reviewLoad: ReviewLoad(backlog: 4, dueCap: 10, effectiveNewPerSession: effective, newWordReason: .freeLimit,
                                         override: nil, autoBalance: false, promptChoice: false),
                  freeAllowance: FreeAllowance(used: 150 - remaining, max: 150, remaining: remaining))
    }

    func testUsedUpFreeWordsOfferReviewsAndPremium() {
        let status = DailyLessonStatus(home: home(effective: 0, remaining: 0), goal: 5)
        XCTAssertEqual(status.reason, .freeLimit(remaining: 0, max: 150))
        XCTAssertEqual(status.freeWordsUsedUp, 150)
    }

    func testAFewFreeWordsLeftStillStartTheLesson() {
        let status = DailyLessonStatus(home: home(effective: 2, remaining: 2), goal: 5)
        XCTAssertEqual(status.newWords, 2)
        XCTAssertNil(status.freeWordsUsedUp)
    }

    // MARK: Free speaking

    private func makeStore(scoring: RecordingScoring) -> PracticeSessionStore {
        api.plan = .success(SessionPlan(sessionID: "s1", mode: .daily, steps: [.practice(phase: .newPractice, task: PracticeFixtures.recording())]))
        return PracticeSessionStore(api: api, audio: SilentAudioClips(), recorder: recorder, haptics: NoOpFeedback(),
                                    recordingScoring: scoring, transcriber: transcriber)
    }

    func testFreeScoringReadsThePlanAtEachSessionStart() async {
        let store = makeStore(scoring: .backend)
        store.scoringForSession = { .onDeviceOnly }
        await store.start(.daily)
        XCTAssertEqual(store.recordingScoring, .onDeviceOnly)
        XCTAssertTrue(store.isFreeSpeaking)
    }

    func testFreeTakeIsCheckedOnTheDevice() async {
        let store = makeStore(scoring: .onDeviceOnly)
        transcriber.candidates = ["clarify"]
        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r1", validity: "valid", passed: true, accuracyScore: 90))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.transcribed("clarify")])
    }

    func testFreeTakeWithoutRecognitionNeverUploads() async {
        let store = makeStore(scoring: .onDeviceOnly)
        transcriber.hasAccess = false
        api.assessResult = .success(RecordingAssessment(assessmentReceiptId: "r1", validity: "valid", passed: true, accuracyScore: 90))
        await store.start(.daily)
        await store.startRecording()
        XCTAssertEqual(store.recording, .blocked(reason: PracticeSessionStore.UnavailableReason.onDeviceUnavailable))
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action),
                       [.unavailable(reason: PracticeSessionStore.UnavailableReason.onDeviceUnavailable)])
    }

    func testLapsedPremiumFallsBackToTheDevice() async {
        let store = makeStore(scoring: .backend)
        transcriber.candidates = ["clarify"]
        api.assessResult = .failure(.server(status: 403, code: "PREMIUM_REQUIRED", message: "", retryable: false, requestID: nil))
        await store.start(.daily)
        await store.startRecording()
        await store.stopRecording()
        XCTAssertEqual(store.recordingScoring, .onDeviceOnly)
        store.acceptRecording()
        XCTAssertEqual(store.attempts["t-recording"]?.events.map(\.action), [.transcribed("clarify")])
    }

    // MARK: Purchases

    private func signedInLearner() async -> LearnerStore {
        api.storedProfile = UserProfile(
            id: "0193f0a0-0000-7000-8000-000000000001", proficiencyLevel: .b1, learningLevel: nil,
            settings: UserSettings(explanationLocale: "vi-VN", uiLocale: "vi-VN", timeZone: TimeZone.current.identifier, dailyNewWordGoal: 5),
            scope: nil,
            plan: PremiumPlan(tier: .free, limits: .init(maxTopics: 3, maxNewWords: 150, newWordsUsed: 0))
        )
        let plan = LearningPlanStore(storage: InMemoryPreferencesStore(preferences: .default, hasCompletedOnboarding: true), reminders: NoReminders())
        let learner = LearnerStore(api: api, plan: plan)
        await learner.reloadProfile()
        return learner
    }

    func testAPurchaseIsFinishedOnlyAfterTheServerAccepts() async {
        let learner = await signedInLearner()
        let client = FakeStoreKit()
        api.syncResults = [.failure(.transport)]
        let store = PurchaseStore(client: client, api: api, learner: learner)
        await store.purchase(FakeStoreKit.offer)
        XCTAssertEqual(client.finished, [], "Kept for StoreKit to deliver again")
        XCTAssertEqual(client.purchaseTokens, [learner.accountToken])

        api.syncResults = [.success(PremiumPlan(tier: .premium, source: .appstore))]
        await store.purchase(FakeStoreKit.offer)
        XCTAssertEqual(client.finished, [1])
        XCTAssertEqual(api.syncedTransactions, ["jws-1", "jws-1"])
    }

    func testATransactionOwnedByAnotherAccountIsFinished() async {
        let learner = await signedInLearner()
        let client = FakeStoreKit()
        api.syncResults = [.failure(.server(status: 409, code: "APPSTORE_TRANSACTION_OWNED", message: "", retryable: false, requestID: nil))]
        let store = PurchaseStore(client: client, api: api, learner: learner)
        await store.purchase(FakeStoreKit.offer)
        XCTAssertEqual(client.finished, [1])
        XCTAssertNotNil(store.notice)
    }
}

@MainActor
final class AdStoreTests: XCTestCase {
    private let api = StubVocabAPI()

    private func learner(free: Bool, every: Int?) async -> LearnerStore {
        api.storedProfile = UserProfile(
            id: "u1", proficiencyLevel: .b1, learningLevel: nil,
            settings: UserSettings(explanationLocale: "vi-VN", uiLocale: "vi-VN", timeZone: TimeZone.current.identifier, dailyNewWordGoal: 5),
            scope: nil,
            plan: free ? PremiumPlan(tier: .free, limits: .init(maxTopics: 3, maxNewWords: 150, newWordsUsed: 0)) : PremiumPlan(tier: .premium),
            features: AppFeatures(freemiumEnabled: true, redeemEnabled: false, adEverySessions: every)
        )
        let plan = LearningPlanStore(storage: InMemoryPreferencesStore(preferences: .default, hasCompletedOnboarding: true), reminders: NoReminders())
        let learner = LearnerStore(api: api, plan: plan)
        await learner.reloadProfile()
        return learner
    }

    func testAnAdFollowsEveryThirdSessionForFreeLearners() async {
        let provider = FakeAds()
        let ads = AdStore(provider: provider, learner: await learner(free: true, every: 3), defaults: nil)
        ads.sessionFinished()
        ads.sessionFinished()
        await ads.presentIfDue()
        XCTAssertEqual(provider.presented, 0)
        ads.sessionFinished()
        await ads.presentIfDue()
        XCTAssertEqual(provider.presented, 1)
        XCTAssertEqual(ads.sessionsSinceAd, 0)
    }

    func testAnAdThatWasNotReadyStaysDue() async {
        let provider = FakeAds()
        provider.isReady = false
        let ads = AdStore(provider: provider, learner: await learner(free: true, every: 1), defaults: nil)
        ads.sessionFinished()
        await ads.presentIfDue()
        XCTAssertTrue(ads.isDue)
        provider.isReady = true
        await ads.presentIfDue()
        XCTAssertEqual(provider.presented, 1)
    }

    func testNoAdsForPremiumOrWhenTurnedOffOrAtLaunch() async {
        for (free, every) in [(false, 3), (true, 0)] {
            let provider = FakeAds()
            let ads = AdStore(provider: provider, learner: await learner(free: free, every: every), defaults: nil)
            ads.sessionFinished()
            await ads.presentIfDue()
            XCTAssertEqual(provider.presented, 0)
            XCTAssertNil(ads.interval)
        }
        let defaults = UserDefaults(suiteName: "AdStoreTests")!
        defaults.set(5, forKey: "ads.sessionsSinceAd")
        let provider = FakeAds()
        let ads = AdStore(provider: provider, learner: await learner(free: true, every: 3), defaults: defaults)
        await ads.presentIfDue()
        XCTAssertEqual(provider.presented, 0, "Not when the app opens")
        defaults.removePersistentDomain(forName: "AdStoreTests")
    }
}

final class FakeAds: InterstitialAdProviding {
    var isReady = true
    private(set) var presented = 0
    func prepare() async {}
    func preload() async {}
    func present() async -> Bool {
        guard isReady else { return false }
        presented += 1
        return true
    }
}

/// Scripted StoreKit: every purchase succeeds with transaction 1.
final class FakeStoreKit: StoreKitClient, @unchecked Sendable {
    static let offer = PremiumOffer(id: PremiumProduct.monthly, displayName: "Monthly", displayPrice: "$6.99", period: .month,
                                    monthlyDisplayPrice: nil, freeTrial: nil)
    var entitlements: [UInt64] = []
    private(set) var finished: [UInt64] = []
    private(set) var purchaseTokens: [UUID?] = []

    private func transaction(_ id: UInt64) -> VerifiedTransaction {
        VerifiedTransaction(id: id, productID: PremiumProduct.monthly, signedTransaction: "jws-\(id)") { [weak self] in
            await MainActor.run { self?.finished.append(id) }
        }
    }

    func offers(ids: [String]) async throws -> [PremiumOffer] { [Self.offer] }
    func purchase(productID: String, accountToken: UUID) async throws -> PurchaseOutcome {
        purchaseTokens.append(accountToken)
        return .purchased(transaction(1))
    }
    func transactionUpdates() -> AsyncStream<VerifiedTransaction> { AsyncStream { $0.finish() } }
    func currentEntitlements() async -> [VerifiedTransaction] { entitlements.map(transaction) }
    func sync() async throws {}
}
