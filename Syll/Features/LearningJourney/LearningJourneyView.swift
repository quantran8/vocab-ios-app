import Charts
import SwiftUI

/// Pushed from Home's journey card (docs/app-redesign-v1.html, 7.1): the period control under the title scopes the
/// whole page: vocabulary growth, the period's new words by topic (a tap opens the topic's words, 7.3), and its
/// activity. History only; it starts nothing (backend FRONTEND_FLOW §17).
struct LearningJourneyView: View {
    @Environment(LearningJourneyStore.self) private var journey
    @Environment(\.motion) private var motion
    @State private var period: JourneyPeriod = .month
    @State private var topicsExpanded = false
    @State private var openTopic: OpenTopic?

    /// The sheet keeps the period it was opened in.
    private struct OpenTopic: Identifiable {
        let period: JourneyPeriod
        let topic: TopicNewWords
        var id: String { "\(period.rawValue)/\(topic.key)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Learning journey")

                if let data = journey.periods[period], !data.hasHistory {
                    emptyState
                        .padding(.top, Spacing.l)
                } else {
                    SegmentedControl(
                        options: [(value: JourneyPeriod.week, title: "Week"), (value: JourneyPeriod.month, title: "Month"), (value: JourneyPeriod.all, title: "All time")],
                        selection: $period
                    )
                    .padding(.top, Spacing.m)

                    content
                        .padding(.top, Spacing.xl)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .refreshable { await journey.load(period, force: true) }
        .task(id: period) { await journey.load(period) }
        .onChange(of: period) { topicsExpanded = false }
        .sheet(item: $openTopic) { open in
            JourneyTopicSheet(period: open.period, topic: open.topic)
        }
    }

    @ViewBuilder
    private var content: some View {
        let data = journey.periods[period]
        SectionTitle("Your vocabulary")
        growthCard(data)

        if let data {
            // An older backend sends no topics: the card is left out, never drawn as zeros.
            if let topics = data.period.newWordsByTopic {
                let total = data.period.newWords ?? topics.reduce(0) { $0 + $1.count }
                SectionTitle(newWordsCaption) {
                    Text(verbatim: "+\(total.formatted(.number.locale(AppLanguage.active.locale)))")
                        .font(Typography.secondary.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.mutedInk)
                }
                .padding(.top, Spacing.xl)
                TopicBreakdown(
                    topics: topics,
                    expanded: topicsExpanded,
                    onToggle: { motion.perform(MotionTokens.panelExpand) { topicsExpanded.toggle() } },
                    onOpen: { openTopic = OpenTopic(period: period, topic: $0) }
                )
            }

            SectionTitle(activityTitle)
                .padding(.top, Spacing.xl)
            activity(data.period)
            if let from = data.historyAvailableFrom {
                Text("Tracking since \(JourneyDate.long(from))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    // MARK: Growth

    private func growthCard(_ data: LearningJourney?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
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
            // No new-word tile: the chart and the topics above already carry that number.
            HStack(alignment: .top, spacing: Spacing.s - 2) {
                ActivityTile(title: "Days learned", value: data.activeDays, tone: .days) { DaysLearnedArt() }
                ActivityTile(title: "Sessions completed", value: data.completedSessions, tone: .sessions) { SessionsArt() }
                ActivityTile(title: "Meaning reviews", value: data.reviewedMeanings, tone: .reviews) { ReviewsArt() }
            }
            .fixedSize(horizontal: false, vertical: true)
            Text("Each finished learning or review part counts as one session.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
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

/// The period's new words by topic (7.1): a stacked bar of where they went, then one row per topic as its legend,
/// most words first. Each topic keeps its own colour. Rows say only what the period added, never topic progress.
private struct TopicBreakdown: View {
    let topics: [TopicNewWords]
    let expanded: Bool
    let onToggle: () -> Void
    let onOpen: (TopicNewWords) -> Void

    var body: some View {
        let visible = TopicNewWords.visible(topics, expanded: expanded)
        VStack(alignment: .leading, spacing: 0) {
            if topics.isEmpty {
                Text("No new words in this period.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Every topic is in the bar, folded ones too; the rows below name them.
                TopicStackedBar(topics: topics)
                    .padding(Spacing.m)
                ForEach(visible.rows) { topic in
                    CardDivider()
                    row(topic)
                }
                if visible.hidden > 0 {
                    CardDivider()
                    toggle(hidden: visible.hidden)
                }
            }
        }
        .cardSurface()
    }

    private func row(_ topic: TopicNewWords) -> some View {
        Button { onOpen(topic) } label: {
            HStack(spacing: Spacing.s) {
                TopicIconTile(topic: topic, size: Spacing.iconButton)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(JourneyTopicStyle.color(topic))
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        JourneyTopicStyle.name(topic)
                            .font(Typography.secondary.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        if topic.finishedInPeriod {
                            StatusPill("Finished", tone: .success, systemImage: "checkmark")
                                .fixedSize()
                        }
                    }
                    if let recent = topic.recentLine {
                        Text(verbatim: recent)
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "+\(topic.count.formatted(.number.locale(AppLanguage.active.locale)))")
                    .font(Typography.secondary.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ink)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink400)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
    }

    private func toggle(hidden: Int) -> some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.xs - 2) {
                if expanded {
                    Text("Show less")
                } else {
                    Text("Show \(hidden) more topics")
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.link)
            .frame(maxWidth: .infinity, minHeight: Spacing.fieldHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .staticLabelRow()
    }
}

/// 12 pt bar, one segment per topic, as wide as its share of the period's new words. Decorative: the rows carry
/// the same numbers for VoiceOver.
private struct TopicStackedBar: View {
    let topics: [TopicNewWords]
    private let gap: CGFloat = 2

    var body: some View {
        let shown = topics.filter { $0.count > 0 }
        let total = shown.reduce(0) { $0 + $1.count }
        GeometryReader { proxy in
            let room = max(0, proxy.size.width - gap * CGFloat(max(shown.count - 1, 0)))
            HStack(spacing: gap) {
                ForEach(shown) { topic in
                    Rectangle()
                        .fill(JourneyTopicStyle.color(topic))
                        .frame(width: total > 0 ? room * CGFloat(topic.count) / CGFloat(total) : 0)
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// How a topic group is drawn on the journey: its backend colour (Ink 300 for own words or none), name and icon.
enum JourneyTopicStyle {
    static func color(_ topic: TopicNewWords) -> Color {
        topic.colorHex.map { Color(hex: $0) } ?? Color.ink300
    }

    static func name(_ topic: TopicNewWords) -> Text {
        if topic.isOwnWords { return Text("Your own words") }
        let catalogName = topic.topicId.flatMap { id in TopicCatalog.collections.lazy.flatMap(\.topics).first { $0.id == id }?.name }
        return Text(verbatim: topic.title ?? catalogName ?? "")
    }

    static func systemImage(_ topic: TopicNewWords) -> String {
        topic.isOwnWords ? "square.and.pencil" : TopicCatalog.systemImage(iosIcon: topic.iosIcon, topicID: topic.topicId)
    }
}

/// The topic's symbol on an Ink 50 rounded tile.
struct TopicIconTile: View {
    let topic: TopicNewWords
    let size: CGFloat

    var body: some View {
        Image(systemName: JourneyTopicStyle.systemImage(topic))
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(Color.ink700)
            .frame(width: size, height: size)
            .background(Color.ink50, in: RoundedRectangle(cornerRadius: Radii.badge + 2, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Activity tiles

/// One activity figure on a tile tinted like its art: 50 fill, 200 border, 900 number, 700 label (Sun: 800).
private struct ActivityTile<Art: View>: View {
    enum Tone {
        case days, sessions, reviews

        var fill: Color { switch self { case .days: .blue50; case .sessions: .green50; case .reviews: .sun50 } }
        var border: Color { switch self { case .days: .blue200; case .sessions: .green200; case .reviews: .sun200 } }
        var number: Color { switch self { case .days: .blue900; case .sessions: .green900; case .reviews: .sun900 } }
        var label: Color { switch self { case .days: .blue700; case .sessions: .green700; case .reviews: .sun800 } }
    }

    let title: LocalizedStringKey
    let value: Int?
    let tone: Tone
    @ViewBuilder let art: () -> Art

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            art()
                .frame(height: 46, alignment: .bottomLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            Group {
                if let value {
                    Text(value, format: .number.locale(AppLanguage.active.locale))
                } else {
                    Text(verbatim: "–")
                }
            }
            .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
            .foregroundStyle(tone.number)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, Spacing.xs)
            Text(title)
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(tone.label)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.s + 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tone.fill, in: shape)
        .overlay(shape.strokeBorder(tone.border, lineWidth: Borders.card))
        .accessibilityElement(children: .combine)
    }
}

/// Days learned: Home's stamp, small and tilted, two of them; the perforations take the tile's Blue 50.
private struct DaysLearnedArt: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            StampView(label: "", isBonus: false, index: 1, width: 30, holeColor: .blue50)
                .opacity(0.5)
            StampView(label: "", isBonus: false, index: 0, width: 34, holeColor: .blue50)
                .offset(x: 20, y: -2)
        }
        .frame(width: 58, height: 44, alignment: .bottomLeading)
    }
}

/// Sessions completed: done cards stacked up, the top one checked.
private struct SessionsArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            card(fill: .green100, border: .green200).offset(x: 10, y: 0)
            card(fill: .green200, border: .green300).offset(x: 5, y: 6)
            card(fill: .green500, border: .green600)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .offset(x: 0, y: 13)
        }
        .frame(width: 52, height: 44, alignment: .topLeading)
    }

    private func card(fill: Color, border: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return shape.fill(fill)
            .overlay(shape.strokeBorder(border, lineWidth: 2))
            .frame(width: 38, height: 28)
    }
}

/// Meaning reviews: a meaning card on a loop of two arrows (drawn on a 50 × 44 grid).
private struct ReviewsArt: View {
    var body: some View {
        let stroke = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        let card = RoundedRectangle(cornerRadius: 3, style: .continuous).path(in: CGRect(x: 17, y: 14, width: 16, height: 17))
        ZStack {
            LoopArrows().stroke(Color.sun400, style: stroke)
            card.fill(Color.sun100)
            card.stroke(Color.sun700, lineWidth: 2)
            Path { path in
                path.move(to: CGPoint(x: 21, y: 20)); path.addLine(to: CGPoint(x: 29, y: 20))
                path.move(to: CGPoint(x: 21, y: 25)); path.addLine(to: CGPoint(x: 26, y: 25))
            }
            .stroke(Color.sun700, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: 50, height: 44)
    }

    /// Two arcs of radius 17 round the card, each ending in an arrowhead.
    private struct LoopArrows: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            // Over the top, left to right, then under, right to left (y grows downwards: not clockwise = clockwise on screen).
            path.addArc(center: CGPoint(x: 25, y: 24.6), radius: 17, startAngle: .degrees(182), endAngle: .degrees(325.6), clockwise: false)
            path.move(to: CGPoint(x: 33, y: 13)); path.addLine(to: CGPoint(x: 40, y: 15)); path.addLine(to: CGPoint(x: 41, y: 8))
            path.move(to: CGPoint(x: 42, y: 22))
            path.addArc(center: CGPoint(x: 25, y: 21.4), radius: 17, startAngle: .degrees(2), endAngle: .degrees(145.6), clockwise: false)
            path.move(to: CGPoint(x: 17, y: 33)); path.addLine(to: CGPoint(x: 10, y: 31)); path.addLine(to: CGPoint(x: 9, y: 38))
            return path
        }
    }
}
