import Foundation
import Observation

/// Shows full-screen ads between sessions. The provider hides the ad SDK, so stores, tests and previews never load it.
@MainActor
protocol InterstitialAdProviding: AnyObject {
    /// Consent (UMP), App Tracking Transparency and SDK start-up. Safe to call more than once.
    func prepare() async
    /// Loads the next ad in the background, if none is waiting.
    func preload() async
    /// Presents a loaded ad and returns once it is dismissed. False when none was ready.
    func present() async -> Bool
}

final class NoInterstitialAds: InterstitialAdProviding {
    func prepare() async {}
    func preload() async {}
    func present() async -> Bool { false }
}

/// Free learners (`plan.limits`) see an interstitial after every `features.adEverySessions` finished sessions
/// (backend FRONTEND_FLOW §16), never during one: the shell asks once the session screen is gone.
/// The count lives on the device and survives relaunches; an ad that wasn't ready keeps it due for next time.
@Observable
@MainActor
final class AdStore {
    private(set) var sessionsSinceAd: Int
    /// Ads follow a session the learner just finished, never the app opening.
    private var finishedSinceLaunch = false

    private let provider: InterstitialAdProviding
    private let learner: LearnerStore
    private let defaults: UserDefaults?
    private static let counterKey = "ads.sessionsSinceAd"

    init(provider: InterstitialAdProviding, learner: LearnerStore, defaults: UserDefaults? = .standard) {
        self.provider = provider
        self.learner = learner
        self.defaults = defaults
        sessionsSinceAd = defaults?.integer(forKey: Self.counterKey) ?? 0
    }

    /// Sessions between ads for this learner; nil when they see none (Premium, ads off, an older backend).
    var interval: Int? {
        guard learner.freeLimits != nil, let every = learner.profile?.features?.adEverySessions, every > 0 else { return nil }
        return every
    }

    var isDue: Bool { interval.map { sessionsSinceAd >= $0 } ?? false }

    /// Once the profile is known. Asks for consent early, so the first ad isn't held up by the forms.
    func prepare() async {
        guard let interval else { return }
        await provider.prepare()
        if sessionsSinceAd + 1 >= interval { await provider.preload() }
    }

    /// A session was saved (any mode but the Lab). The ad loads one session early so it is ready on time.
    func sessionFinished() {
        guard let interval else { return }
        sessionsSinceAd += 1
        finishedSinceLaunch = true
        save()
        if sessionsSinceAd + 1 >= interval {
            Task { await provider.preload() }
        }
    }

    /// Called when the shell reappears after a session screen closed.
    func presentIfDue() async {
        guard isDue, finishedSinceLaunch else { return }
        guard await provider.present() else {
            // Not loaded yet (no fill, offline): try again after the next session.
            Task { await provider.preload() }
            return
        }
        sessionsSinceAd = 0
        save()
    }

    private func save() {
        defaults?.set(sessionsSinceAd, forKey: Self.counterKey)
    }
}
