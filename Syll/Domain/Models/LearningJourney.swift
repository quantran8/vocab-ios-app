import Foundation

/// The period the journey detail shows. Home always shows the current week.
enum JourneyPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, all

    var id: String { rawValue }
}

/// `GET /me/learning-journey` (backend FRONTEND_FLOW §17): history only, built from committed sessions.
/// Dates are the learner's local days as `yyyy-MM-dd`, in the server's `timezone`.
struct LearningJourney: Decodable, Equatable {
    struct Day: Decodable, Equatable, Identifiable {
        let date: String
        /// Nil for days still ahead.
        let completed: Bool?
        let completedSessions: Int?
        let newWords: Int?

        var id: String { date }
        var isFuture: Bool { completed == nil }
    }

    struct Week: Decodable, Equatable {
        let startDate: String
        let endDateExclusive: String
        let newWords: Int
        let completedSessions: Int
        let activeDays: Int
        /// Study days the learner aims for each week (the app sets it to the days they chose); nil when unset.
        let weeklySessionGoal: Int?
        /// The week's newest words, at most three. Nil from an older backend.
        var recentWords: [RecentWord]? = nil
        let days: [Day]

        /// The last day that isn't ahead: today in the learner's time zone.
        var today: Day? { days.last { !$0.isFuture } }
        /// The goal counts study days, never sessions: a Daily split in two still makes one day.
        var goalReached: Bool { weeklySessionGoal.map { activeDays >= $0 } ?? false }
        /// The days that earned a stamp, in order.
        var studiedDays: [Day] { days.filter { $0.completed == true } }
        /// New words beyond the ones named on Home.
        var otherNewWords: Int { max(0, newWords - (recentWords?.count ?? 0)) }
    }

    struct RecentWord: Decodable, Equatable {
        let wordId: String
        let lemma: String
    }

    struct Point: Decodable, Equatable {
        /// The bucket's last day (today for the bucket in progress).
        let date: String
        let cumulativeWords: Int
    }

    struct Period: Decodable, Equatable {
        let kind: String
        let startDate: String
        let endDateExclusive: String
        /// day | month | quarter | year
        let bucketGranularity: String
        let wordsAtStart: Int?
        let wordsAtEnd: Int?
        let newWords: Int?
        let activeDays: Int?
        let completedSessions: Int?
        let reviewedMeanings: Int?
        let points: [Point]
        /// The period's new words per topic, most first. Nil from an older backend: the detail then leaves the
        /// topics card out rather than showing zeros.
        var newWordsByTopic: [TopicNewWords]? = nil
    }

    let asOf: Date
    let timezone: String
    /// The first day with any learning; nil for a learner who hasn't finished a session yet.
    let historyAvailableFrom: String?
    let week: Week
    let period: Period

    var hasHistory: Bool { historyAvailableFrom != nil }
}

/// Parses and labels the journey's `yyyy-MM-dd` days. They are calendar days, so they read in UTC whatever the device zone.
enum JourneyDate {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(_ day: String) -> Date? { parser.date(from: day) }

    private static func style(_ base: Date.FormatStyle) -> Date.FormatStyle {
        var style = base
        style.locale = AppLanguage.active.locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }

    /// "M", "T"… for the day strip.
    static func weekdayInitial(_ day: String) -> String {
        guard let date = date(day) else { return "" }
        return date.formatted(style(Date.FormatStyle().weekday(.narrow)))
    }

    /// "Monday" for VoiceOver.
    static func weekdayName(_ day: String) -> String {
        guard let date = date(day) else { return day }
        return date.formatted(style(Date.FormatStyle().weekday(.wide)))
    }

    /// The day a stamp was earned, short enough for the stamp ("Mon", "T2").
    static func stampLabel(_ day: String) -> String {
        guard let date = date(day) else { return "" }
        return date.formatted(style(Date.FormatStyle().weekday(.abbreviated)))
    }

    /// "23–29/11" for the week on Home.
    static func weekRange(start: String, endExclusive: String) -> String {
        guard let from = date(start), let to = date(endExclusive)?.addingTimeInterval(-86_400) else { return start }
        let formatter = DateIntervalFormatter()
        formatter.locale = AppLanguage.active.locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateTemplate = "dM"
        return formatter.string(from: from, to: to)
    }

    /// "12 Nov 2026".
    static func long(_ day: String) -> String {
        guard let date = date(day) else { return day }
        return date.formatted(style(Date.FormatStyle(date: .abbreviated, time: .omitted)))
    }

    /// A chart axis label: day and month for daily buckets, else month and year, or the year alone.
    static func axis(_ date: Date, granularity: String) -> String {
        if granularity == "day" { return date.formatted(style(Date.FormatStyle().day().month(.defaultDigits))) }
        if granularity == "year" { return date.formatted(style(Date.FormatStyle().year())) }
        return date.formatted(style(Date.FormatStyle().month(.abbreviated).year(.twoDigits)))
    }
}

/// One topic's share of the period's new words (`period.newWordsByTopic`). Words the learner added themselves come
/// as one group without a topic.
struct TopicNewWords: Equatable, Identifiable {
    let topicId: String?
    let title: String?
    /// An SF Symbol name set by the backend.
    let iosIcon: String?
    /// The topic's fixed `#RRGGBB`; nil (or unparseable) draws Ink 300, as does the own-words group.
    var color: String? = nil
    let count: Int
    /// The topic's newest words in the period, at most three.
    var recentLemmas: [String] = []
    /// The topic's last meaning was learned in this period: an event of the period, not progress.
    var finishedInPeriod: Bool = false

    /// `topicId` for the words endpoint: the literal "none" for the learner's own words.
    static let ownWordsKey = "none"
    /// The rows shown before "Show N more topics".
    static let collapsedLimit = 4

    var key: String { topicId ?? Self.ownWordsKey }
    var id: String { key }
    var isOwnWords: Bool { topicId == nil }
    /// The parsed `color`, as `0xRRGGBB`; nil for the own-words group or a missing or malformed colour.
    var colorHex: UInt32? { isOwnWords ? nil : TopicCatalog.hex(color) }

    /// "itinerary, layover, customs…": the newest words, with "…" when the topic added more than those.
    var recentLine: String? {
        guard !recentLemmas.isEmpty else { return nil }
        let names = recentLemmas.joined(separator: ", ")
        return count > recentLemmas.count ? names + "…" : names
    }

    /// The rows to show and how many stay folded under "Show N more topics".
    static func visible(_ topics: [TopicNewWords], expanded: Bool) -> (rows: [TopicNewWords], hidden: Int) {
        let hidden = max(0, topics.count - collapsedLimit)
        return (expanded || hidden == 0 ? topics : Array(topics.prefix(collapsedLimit)), hidden)
    }
}

extension TopicNewWords: Decodable {
    private enum CodingKeys: String, CodingKey {
        case topicId, title, iosIcon, color, count, recentLemmas, finishedInPeriod
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topicId = try container.decodeIfPresent(String.self, forKey: .topicId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        iosIcon = try container.decodeIfPresent(String.self, forKey: .iosIcon)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        count = try container.decode(Int.self, forKey: .count)
        recentLemmas = try container.decodeIfPresent([String].self, forKey: .recentLemmas) ?? []
        finishedInPeriod = try container.decodeIfPresent(Bool.self, forKey: .finishedInPeriod) ?? false
    }
}

/// `GET /me/learning-journey/words`: one topic's new words in the period, newest first (backend FRONTEND_FLOW §17).
struct JourneyWordsPage: Decodable, Equatable {
    let total: Int
    let items: [JourneyWord]
}

struct JourneyWord: Decodable, Equatable, Identifiable {
    let wordId: String
    let lemma: String
    /// The meanings of the word learned in the period, in learned order.
    let meaningTexts: [String]
    /// The local day the word was first learned.
    let learnedOn: String

    var id: String { wordId }

    /// Joins meanings in the glossary; a meaning's own synonyms keep their commas.
    static let meaningSeparator = " · "
    /// Every meaning as one line, for VoiceOver (never clamped).
    var glossary: String { meaningTexts.joined(separator: Self.meaningSeparator) }
}
