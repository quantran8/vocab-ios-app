import Charts
import SwiftUI

/// Home's journey summary, after "Learning": this week's new words and sessions. History only; the whole card
/// opens `LearningJourneyView`. A failed load shows a retry line and never zeros (backend FRONTEND_FLOW §17).
struct LearningJourneyCard: View {
    let onOpen: () -> Void
    @Environment(LearningJourneyStore.self) private var journey

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your journey")
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let summary = journey.summary {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    if summary.hasHistory {
                        filled(summary.week)
                    } else {
                        empty
                    }
                    if case .failed = journey.summaryLoad {
                        Text("Not up to date")
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
                            .padding(.horizontal, Spacing.m)
                            .padding(.bottom, Spacing.s)
                    }
                }
                .cardSurface()
                .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint(Text("Opens your learning history"))
        } else if case .failed = journey.summaryLoad {
            failed
        } else {
            skeleton
        }
    }

    private func filled(_ week: LearningJourney.Week) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: "+\(week.newWords.formatted(.number.locale(AppLanguage.active.locale)))")
                        .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Color.ink)
                    Text("New words this week")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                }
                Spacer(minLength: Spacing.s)
                WeekSparkline(values: week.cumulativeNewWords)
                    .frame(width: 96, height: 40)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(week.newWords) new words this week"))
            .padding(Spacing.m)

            CardDivider()

            WeekRhythm(week: week)
                .padding(Spacing.m)
        }
    }

    private var empty: some View {
        HStack(spacing: Spacing.s) {
            IconBadge(systemImage: "point.topleft.down.to.point.bottomright.curvepath", tone: .accent)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Your journey starts with one word")
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.ink)
                Text("Finish your first session to begin.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.ink400)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var failed: some View {
        HStack(spacing: Spacing.xs) {
            Text("Couldn’t load your journey")
                .foregroundStyle(Color.mutedInk)
            TextLink(title: "Try again") {
                Task { await journey.refreshSummary(force: true) }
            }
        }
        .font(Typography.secondary)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(verbatim: "+00").font(Typography.screenTitle.weight(.heavy))
            Text(verbatim: "New words this week").font(Typography.secondary)
            Text(verbatim: "M T W T F S S").font(Typography.secondary)
        }
        .redacted(reason: .placeholder)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityHidden(true)
    }
}

/// This week's running total of new words; no future points, a dot when only one day has passed.
struct WeekSparkline: View {
    let values: [Int]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At the largest text sizes the number and label need the room.
        if !typeSize.isAccessibilitySize, !values.isEmpty {
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    if values.count == 1 {
                        PointMark(x: .value("Day", index), y: .value("Words", value))
                            .foregroundStyle(Color.blue500)
                    } else {
                        LineMark(x: .value("Day", index), y: .value("Words", value))
                            .foregroundStyle(Color.blue500)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .chartXScale(domain: 0...6)
            .chartYScale(domain: 0...max(values.last ?? 0, 1))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .accessibilityHidden(true)
        }
    }
}

/// Sessions done against the weekly goal, over Monday–Sunday marks. Each mark has a symbol, not only a colour.
struct WeekRhythm: View {
    let week: LearningJourney.Week

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Text("Sessions this week")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Spacer(minLength: Spacing.xs)
                if week.goalReached {
                    StatusPill("Weekly goal reached", tone: .success, systemImage: "checkmark")
                }
                Group {
                    if let goal = week.weeklySessionGoal {
                        Text(verbatim: "\(week.completedSessions)/\(goal)")
                    } else {
                        Text(verbatim: "\(week.completedSessions)")
                    }
                }
                .font(Typography.secondary.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.ink)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rhythmLabel)

            HStack(spacing: 0) {
                ForEach(week.days) { day in
                    DayMark(day: day, isToday: day.id == week.today?.id)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var rhythmLabel: Text {
        if let goal = week.weeklySessionGoal {
            return Text("\(week.completedSessions) of \(goal) sessions this week")
        }
        return Text("\(week.completedSessions) sessions this week")
    }
}

private struct DayMark: View {
    let day: LearningJourney.Day
    let isToday: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(verbatim: JourneyDate.weekdayInitial(day.date))
                .font(Typography.micro.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.ink : Color.mutedInk)
            symbol
                .frame(width: 22, height: 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var symbol: some View {
        switch (day.completed, isToday) {
        case (true?, _):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.blue500)
        case (false?, true):
            Image(systemName: "circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.ink400)
        case (false?, false):
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ink300)
        case (nil, _):
            Circle()
                .fill(Color.ink100)
                .frame(width: 8, height: 8)
        }
    }

    private var label: Text {
        let name = JourneyDate.weekdayName(day.date)
        switch (day.completed, isToday) {
        case (true?, _): return Text("\(name), studied")
        case (false?, true): return Text("\(name), today, not studied yet")
        case (false?, false): return Text("\(name), not studied")
        case (nil, _): return Text("\(name), upcoming")
        }
    }
}
