import Foundation
import Observation

/// The learning journey (backend FRONTEND_FLOW §17): Home's week and the detail's periods.
/// History only: nothing here plans, commits or changes progress. A failed load keeps what was on screen
/// and never turns into zeros.
@Observable
@MainActor
final class LearningJourneyStore {
    enum Load: Equatable {
        case idle, loading, loaded, failed(String)
    }

    /// Home's summary: always the current week.
    private(set) var summary: LearningJourney?
    private(set) var summaryLoad: Load = .idle
    /// The detail's data per period. A stale entry stays visible while it reloads.
    private(set) var periods: [JourneyPeriod: LearningJourney] = [:]
    private(set) var periodLoads: [JourneyPeriod: Load] = [:]

    private let api: VocabAPI
    private let now: () -> Date
    /// Bumped by `reset` and `invalidate`, so an answer for the previous account or an older state is dropped.
    private var generation = 0
    private var summaryLoadedAt: Date?
    private var periodLoadedAt: [JourneyPeriod: Date] = [:]
    /// Reloaded after this long, or once the day changes.
    private static let freshFor: TimeInterval = 5 * 60

    init(api: VocabAPI, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.now = now
    }

    /// Loads the week unless it is fresh. `force` after a commit, pull-to-refresh or a goal change.
    func refreshSummary(force: Bool = false) async {
        guard force || isStale(summaryLoadedAt) else { return }
        let started = generation
        summaryLoad = .loading
        do {
            let fresh = try await api.learningJourney(period: .week)
            guard started == generation else { return }
            summary = fresh
            periods[.week] = fresh
            summaryLoadedAt = now()
            periodLoadedAt[.week] = summaryLoadedAt
            summaryLoad = .loaded
        } catch {
            guard started == generation, !Task.isCancelled else { return }
            summaryLoad = .failed(error.asAPIError.userMessage)
        }
    }

    func load(_ period: JourneyPeriod, force: Bool = false) async {
        guard force || isStale(periodLoadedAt[period]) || periods[period] == nil else { return }
        let started = generation
        periodLoads[period] = .loading
        do {
            let fresh = try await api.learningJourney(period: period)
            guard started == generation else { return }
            periods[period] = fresh
            periodLoadedAt[period] = now()
            periodLoads[period] = .loaded
            if period == .week { summary = fresh; summaryLoadedAt = periodLoadedAt[period] }
        } catch {
            guard started == generation, !Task.isCancelled else { return }
            periodLoads[period] = .failed(error.asAPIError.userMessage)
        }
    }

    /// After a committed session: everything is stale, but stays on screen until it reloads.
    func invalidate() {
        generation += 1
        summaryLoadedAt = nil
        periodLoadedAt = [:]
        if summaryLoad == .loading { summaryLoad = .idle }
        for (period, load) in periodLoads where load == .loading { periodLoads[period] = .idle }
    }

    /// Sign-out and account deletion: nothing carries over to the next account.
    func reset() {
        generation += 1
        summary = nil
        summaryLoad = .idle
        summaryLoadedAt = nil
        periods = [:]
        periodLoads = [:]
        periodLoadedAt = [:]
    }

    private func isStale(_ loadedAt: Date?) -> Bool {
        guard let loadedAt else { return true }
        let current = now()
        return current.timeIntervalSince(loadedAt) > Self.freshFor || !Calendar.current.isDate(loadedAt, inSameDayAs: current)
    }
}
