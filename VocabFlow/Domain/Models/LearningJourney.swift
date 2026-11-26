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
        /// Sessions the learner aims for each week; nil when the server has none.
        let weeklySessionGoal: Int?
        let days: [Day]

        /// The last day that isn't ahead: today in the learner's time zone.
        var today: Day? { days.last { !$0.isFuture } }
        var goalReached: Bool { weeklySessionGoal.map { completedSessions >= $0 } ?? false }

        /// New words learned so far this week, one running total per elapsed day.
        var cumulativeNewWords: [Int] {
            var total = 0
            return days.filter { !$0.isFuture }.map { day in
                total += day.newWords ?? 0
                return total
            }
        }
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
