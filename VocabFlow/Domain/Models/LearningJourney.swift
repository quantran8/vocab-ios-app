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

    /// "Thursday, 26 Nov" for a timeline day.
    static func dayTitle(_ day: String) -> String {
        guard let date = date(day) else { return day }
        return date.formatted(style(Date.FormatStyle().weekday(.wide).day().month(.abbreviated)))
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

/// `GET /me/learning-journey/words`: the period's new words, newest first (backend FRONTEND_FLOW §17).
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
    var meaningText: String { meaningTexts.joined(separator: "; ") }
}

/// One day of the new-words timeline: consecutive words learned on the same day.
struct JourneyWordDay: Equatable, Identifiable {
    let date: String
    let words: [JourneyWord]

    var id: String { date }

    /// Pages arrive newest first, so a day can span two pages; it stays one group.
    static func grouped(_ words: [JourneyWord]) -> [JourneyWordDay] {
        var days: [JourneyWordDay] = []
        for word in words {
            if let last = days.last, last.date == word.learnedOn {
                days[days.count - 1] = JourneyWordDay(date: last.date, words: last.words + [word])
            } else {
                days.append(JourneyWordDay(date: word.learnedOn, words: [word]))
            }
        }
        return days
    }
}
