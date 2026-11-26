import SwiftUI

/// Home's journey block, after "Learning" (docs/app-redesign-v1.html, 1.1): this week's new words and study days,
/// the days drawn as a stamp card. History only. "See details" (and the whole card) opens `LearningJourneyView`.
/// A failed load shows a retry line and never zeros (backend FRONTEND_FLOW §17).
struct LearningJourneyCard: View {
    let onOpen: () -> Void
    @Environment(LearningJourneyStore.self) private var journey

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your journey") {
                if journey.summary != nil {
                    TextLink(title: "See details", action: onOpen)
                }
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let summary = journey.summary {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    if summary.hasHistory {
                        NewWordsBlock(week: summary.week)
                        CardDivider()
                        StudyDaysBlock(week: summary.week)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
                .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint(Text("Opens your learning history"))
        } else if case .failed = journey.summaryLoad {
            HStack(spacing: Spacing.xs) {
                Text("Couldn’t load your journey")
                    .foregroundStyle(Color.mutedInk)
                TextLink(title: "Try again") {
                    Task { await journey.refreshSummary(force: true) }
                }
            }
            .font(Typography.secondary)
        } else {
            skeleton
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
        }
        .multilineTextAlignment(.leading)
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(verbatim: "+00").font(Typography.screenTitle.weight(.heavy))
            Text(verbatim: "New words this week").font(Typography.secondary)
            Text(verbatim: "▢ ▢ ▢").font(Typography.screenTitle)
        }
        .redacted(reason: .placeholder)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityHidden(true)
    }
}

/// The count and caption shared by both blocks, so they read as peers.
private struct JourneyFigure: View {
    let value: String
    let caption: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs - 2) {
            Text(verbatim: value)
                .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(caption)
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(Color.mutedInk)
        }
    }
}

/// "+24 · New words this week", then the newest words by name so the number says what it is made of.
private struct NewWordsBlock: View {
    let week: LearningJourney.Week

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            JourneyFigure(value: "+\(week.newWords.formatted(.number.locale(AppLanguage.active.locale)))", caption: "New words this week")
            if let names {
                names
                    .font(Typography.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "resilient, meticulous, ambiguous and 21 more"; nil in a week without new words.
    private var names: Text? {
        guard let words = week.recentWords, !words.isEmpty else { return nil }
        let list = words.map(\.lemma).formatted(.list(type: .and, width: .narrow).locale(AppLanguage.active.locale))
        let named = Text(verbatim: list).fontWeight(.semibold).foregroundColor(Color.ink800)
        guard week.otherNewWords > 0 else { return named }
        return Text("\(named) and \(week.otherNewWords) more").foregroundColor(Color.mutedInk)
    }
}

/// "2/3 · Study days this week" with its stamps right under it: the stamps are that count.
private struct StudyDaysBlock: View {
    let week: LearningJourney.Week

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top) {
                JourneyFigure(value: count, caption: "Study days this week")
                Spacer(minLength: Spacing.s)
                Text(verbatim: JourneyDate.weekRange(start: week.startDate, endExclusive: week.endDateExclusive))
                    .font(Typography.micro.weight(.bold))
                    .tracking(Typography.eyebrowTracking)
                    .foregroundStyle(Color.ink400)
            }
            StampCard(week: week)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var count: String {
        week.weeklySessionGoal.map { "\(week.activeDays)/\($0)" } ?? "\(week.activeDays)"
    }

    private var label: Text {
        let days = week.studiedDays.map { JourneyDate.weekdayName($0.date) }
            .formatted(.list(type: .and).locale(AppLanguage.active.locale))
        let summary = week.weeklySessionGoal.map { Text("\(week.activeDays) of \($0) study days this week") }
            ?? Text("\(week.activeDays) study days this week")
        guard !days.isEmpty else { return summary }
        return Text("\(summary), studied on \(days)")
    }
}

/// One stamp per day learned in as many slots as the goal: never the seven weekdays, so a planned day off is never
/// a miss. Stamps past the goal are green; a postmark is struck once the goal is met.
struct StampCard: View {
    let week: LearningJourney.Week
    var stampWidth: CGFloat = 56

    var body: some View {
        let studied = week.studiedDays
        let goal = week.weeklySessionGoal ?? studied.count
        let slots = max(goal, studied.count)
        HStack(alignment: .top, spacing: 0) {
            WrapLayout(spacing: Spacing.s) {
                ForEach(0..<slots, id: \.self) { index in
                    if index < studied.count {
                        StampView(label: JourneyDate.stampLabel(studied[index].date), isBonus: index >= goal, index: index, width: stampWidth)
                    } else {
                        EmptyStampSlot(width: stampWidth)
                    }
                }
            }
            Spacer(minLength: 0)
            if week.goalReached {
                Postmark()
                    .padding(.top, -Spacing.xl)
            }
        }
    }
}

private struct StampView: View {
    let label: String
    let isBonus: Bool
    let index: Int
    let width: CGFloat

    private static let tilts: [Double] = [-4, 3, -2, 4, -3, 2, -1]
    @Environment(\.motion) private var motion

    var body: some View {
        let height = (width * 1.18).rounded()
        ZStack {
            // Even-odd cuts the holes; clipping drops their halves outside the edge.
            PerforatedStamp(holeRadius: width / 18, step: width / 7)
                .fill(isBonus ? Color.green500 : Color.blue500, style: FillStyle(eoFill: true))
                .clipped()
            Rectangle()
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.2)
                .padding(width / 9)
            VStack(spacing: Spacing.xxs) {
                Text(verbatim: label)
                    .font(.system(size: width * 0.27, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: "checkmark")
                    .font(.system(size: width * 0.2, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, width / 7)
        }
        .frame(width: width, height: height)
        // Pressed by hand: a slight alternating tilt. Upright with reduced motion.
        .rotationEffect(.degrees(motion.reduceMotion ? 0 : Self.tilts[index % Self.tilts.count]))
        .accessibilityHidden(true)
    }
}

/// A stamp's outline with half-circle perforations along every edge.
private struct PerforatedStamp: Shape {
    let holeRadius: CGFloat
    let step: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        var x = step / 2
        while x < rect.width {
            path.addEllipse(in: CGRect(x: x - holeRadius, y: -holeRadius, width: holeRadius * 2, height: holeRadius * 2))
            path.addEllipse(in: CGRect(x: x - holeRadius, y: rect.height - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
            x += step
        }
        var y = step / 2
        while y < rect.height {
            path.addEllipse(in: CGRect(x: -holeRadius, y: y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
            path.addEllipse(in: CGRect(x: rect.width - holeRadius, y: y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
            y += step
        }
        return path
    }
}

private struct EmptyStampSlot: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(Color.ink200, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .frame(width: width, height: (width * 1.18).rounded())
            .accessibilityHidden(true)
    }
}

/// The round "reached" postmark struck over the stamps.
private struct Postmark: View {
    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "SYLL")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
            Text("Reached")
                .font(.system(size: 12, weight: .black))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Color.green700)
        .padding(Spacing.xs)
        .frame(width: 72, height: 72)
        .overlay(Circle().strokeBorder(Color.green600, lineWidth: 2.5))
        .rotationEffect(.degrees(-12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Weekly goal reached"))
    }
}

/// Lays children out left to right, wrapping to a new row when one doesn't fit.
struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { row in row.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height = rows.map { row in row.map(\.size.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var rowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = rows[rows.count - 1].isEmpty ? size.width : rowWidth + spacing + size.width
            if needed > width, !rows[rows.count - 1].isEmpty {
                rows.append([Item(subview: subview, size: size)])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(Item(subview: subview, size: size))
                rowWidth = needed
            }
        }
        return rows
    }
}
