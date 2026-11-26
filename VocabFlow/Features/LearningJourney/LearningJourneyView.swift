import Charts
import SwiftUI

/// Pushed from Home's journey card: vocabulary growth for the chosen period, this week's rhythm and the period's
/// activity. History only; it starts nothing (backend FRONTEND_FLOW §17).
struct LearningJourneyView: View {
    @Environment(LearningJourneyStore.self) private var journey
    @State private var period: JourneyPeriod = .month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Learning journey")

                content
                    .padding(.top, Spacing.l)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .refreshable { await journey.load(period, force: true) }
        .task(id: period) { await journey.load(period) }
    }

    @ViewBuilder
    private var content: some View {
        let data = journey.periods[period]
        if let data, !data.hasHistory {
            emptyState
        } else {
            SectionTitle("Your vocabulary")
            growthCard(data)

            if let week = (journey.periods[.week] ?? data)?.week, data != nil {
                SectionTitle("This week’s rhythm")
                    .padding(.top, Spacing.xl)
                WeekRhythm(week: week)
                    .padding(Spacing.m)
                    .cardSurface()
            }

            if let data {
                SectionTitle(activityTitle)
                    .padding(.top, Spacing.xl)
                activity(data.period)
                if let from = data.historyAvailableFrom {
                    Text("Tracking since \(JourneyDate.long(from))")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.s)
                }
            }
        }
    }

    // MARK: Growth

    private func growthCard(_ data: LearningJourney?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SegmentedControl(
                options: [(value: JourneyPeriod.week, title: "Week"), (value: JourneyPeriod.month, title: "Month"), (value: JourneyPeriod.all, title: "All time")],
                selection: $period
            )

            switch (data, journey.periodLoads[period]) {
            case (let data?, _):
                growth(data.period)
            case (nil, .failed(let message)?):
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(verbatim: message)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                    SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                        Task { await journey.load(period, force: true) }
                    }
                }
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .padding(Spacing.m)
        .cardSurface()
    }

    @ViewBuilder
    private func growth(_ data: LearningJourney.Period) -> some View {
        if let start = data.wordsAtStart, let end = data.wordsAtEnd {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: "+\((end - start).formatted(.number.locale(AppLanguage.active.locale)))")
                    .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.ink)
                Text(newWordsCaption)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            }
            .accessibilityElement(children: .combine)

            GrowthChart(period: data)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Vocabulary grew from \(start) to \(end) words"))

            HStack {
                figure("At start", start)
                Spacer(minLength: Spacing.s)
                figure("Now", end)
            }
        } else {
            Text("No learning yet in this period.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
        }
    }

    private func figure(_ title: LocalizedStringKey, _ value: Int) -> some View {
        HStack(spacing: Spacing.xxs) {
            Text(title)
            Text(value, format: .number.locale(AppLanguage.active.locale))
                .fontWeight(.bold)
                .foregroundStyle(Color.ink)
        }
        .font(Typography.secondary.monospacedDigit())
        .foregroundStyle(Color.mutedInk)
        .accessibilityElement(children: .combine)
    }

    private var newWordsCaption: LocalizedStringKey {
        switch period {
        case .week: "New words this week"
        case .month: "New words this month"
        case .all: "New words since you started"
        }
    }

    private var activityTitle: LocalizedStringKey {
        switch period {
        case .week: "Activity this week"
        case .month: "Activity this month"
        case .all: "Activity since you started"
        }
    }

    // MARK: Activity

    private func activity(_ data: LearningJourney.Period) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Grid(horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
                GridRow {
                    tile("Days learned", data.activeDays, systemImage: "calendar")
                    tile("Sessions completed", data.completedSessions, systemImage: "checkmark.circle")
                }
                GridRow {
                    tile("New words", data.newWords, systemImage: "plus.circle")
                    tile("Meaning reviews", data.reviewedMeanings, systemImage: "arrow.clockwise")
                }
            }
            Text("Each finished learning or review part counts as one session.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(_ title: LocalizedStringKey, _ value: Int?, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            IconBadge(systemImage: systemImage, tone: .accent, size: Spacing.iconButton)
            Group {
                if let value {
                    Text(value, format: .number.locale(AppLanguage.active.locale))
                } else {
                    Text(verbatim: "–")
                }
            }
            .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
            .foregroundStyle(Color.ink)
            Text(title)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            IconBadge(systemImage: "point.topleft.down.to.point.bottomright.curvepath", tone: .accent)
            Text("Your journey starts with one word")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text("Finish your first session to begin.")
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// Cumulative words learned, from the period's start to today, on real date spacing. No future points,
/// no smoothing; one point draws as a dot.
private struct GrowthChart: View {
    let period: LearningJourney.Period

    private struct Sample: Identifiable {
        let date: Date
        let words: Int
        var id: Date { date }
    }

    private var samples: [Sample] {
        var result: [Sample] = []
        if let start = period.wordsAtStart, let date = JourneyDate.date(period.startDate) {
            result.append(Sample(date: date, words: start))
        }
        for point in period.points {
            guard let date = JourneyDate.date(point.date) else { continue }
            // A bucket ending on the start day replaces the baseline instead of stacking on it.
            if result.last?.date == date { result.removeLast() }
            result.append(Sample(date: date, words: point.cumulativeWords))
        }
        return result
    }

    var body: some View {
        let samples = samples
        let low = samples.map(\.words).min() ?? 0
        let high = max(samples.map(\.words).max() ?? 0, low + 1)
        Chart(samples) { sample in
            if samples.count == 1 {
                PointMark(x: .value("Date", sample.date), y: .value("Words", sample.words))
                    .foregroundStyle(Color.blue500)
            } else {
                AreaMark(x: .value("Date", sample.date), yStart: .value("Base", low), yEnd: .value("Words", sample.words))
                    .foregroundStyle(Color.blue50)
                LineMark(x: .value("Date", sample.date), y: .value("Words", sample.words))
                    .foregroundStyle(Color.blue500)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.ink100)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(verbatim: JourneyDate.axis(date, granularity: period.bucketGranularity))
                            .font(Typography.caption)
                            .foregroundStyle(Color.mutedInk)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.ink100)
                AxisValueLabel().font(Typography.caption).foregroundStyle(Color.mutedInk)
            }
        }
    }
}
