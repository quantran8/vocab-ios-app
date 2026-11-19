import SwiftUI

struct HomeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(LearnerStore.self) private var learner
    @Environment(LearningPlanStore.self) private var plan
    @Environment(ChallengeMapStore.self) private var challengeMap
    @Environment(\.motion) private var motion
    /// Pushes the Challenge Map onto Home's navigation stack.
    var onOpenChallengeMap: () -> Void = {}
    /// Opens the Focus sheet (topics and collection).
    var onChooseTopics: () -> Void = {}
    var onOpenRandomPractice: () -> Void = {}
    @State private var isChoosingReviewLoad = false
    @State private var isShowingLessonInfo = false
    @State private var showsAllTopics = false

    var body: some View {
        let due = learner.home?.dueCount ?? 0
        let status = DailyLessonStatus(home: learner.home, goal: plan.current.wordsPerDay)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                dailyLesson(status, due: due)
                    .padding(.top, LessonMascot.bottomMargin)

                if let collection = TopicCatalog.collection(id: plan.current.collectionID) {
                    learningSection(collection)
                        .padding(.top, Spacing.xl + Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .refreshable {
            async let learnerRefresh: Void = learner.refresh()
            async let mapRefresh: Void = challengeMap.refresh()
            _ = await (learnerRefresh, mapRefresh)
        }
        // Never mid-session (Home isn't on screen then), at most once per launch.
        .task(id: learner.home?.reviewLoad?.promptChoice) {
            if learner.shouldOfferReviewChoice, !practice.isActive { isChoosingReviewLoad = true }
        }
        .sheet(isPresented: $isChoosingReviewLoad, onDismiss: {
            Task { await learner.acknowledgeReviewChoice() }
        }) {
            if let load = learner.home?.reviewLoad {
                ReviewLoadChoiceSheet(
                    load: load,
                    goal: learner.profile?.settings.dailyNewWordGoal ?? plan.current.wordsPerDay,
                    onExtraReview: { startReviewOnly() },
                    onLower: { value, mode in try await learner.setNewWordOverride(value: value, mode: mode) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvas)
            }
        }
    }

    /// The footer offers reviews beyond this daily session’s allocation.
    /// Out of new words, the Daily card's own button already reviews.
    private func showsExtraReview(_ status: DailyLessonStatus) -> Bool {
        if case .exhaustedNoCustom = status.scope { return false }
        return status.backlog > status.sessionReviews
    }

    // MARK: Header

    /// One row, no wordmark and no greeting (docs/app-redesign-v1.html, 1.1): Syllie on the left, the learner's lifetime LP
    /// on the right, centred on his body. LP is the only number at the top; "Today’s lesson" is the screen's VoiceOver header.
    private var header: some View {
        HStack(alignment: .top) {
            LessonMascot()
            Spacer(minLength: Spacing.s)
            if let lp = learner.profile?.tierSummary?.lifetimeLP {
                lpPill(lp)
                    .padding(.top, LessonMascot.bodyCenterY - Self.lpPillHeight / 2)
            }
        }
        // The artboard keeps room above Syllie for his props; that room may run under the status bar.
        .padding(.top, Spacing.xs - LessonMascot.topMargin)
    }

    private static let lpPillHeight: CGFloat = Spacing.l + Spacing.xs

    private func lpPill(_ lp: Int) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "bolt.fill")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(Color.reward)
                .accessibilityHidden(true)
            Text(lp, format: .number.locale(AppLanguage.active.locale))
                .font(Typography.secondary.weight(.bold).monospacedDigit())
                .contentTransition(.numericText(value: Double(lp)))
        }
        .foregroundStyle(Color.rewardInk)
        .padding(.horizontal, Spacing.s)
        .frame(height: Self.lpPillHeight)
        .background(Color.rewardSurface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(lp) LP"))
    }

    // MARK: Daily lesson

    /// The screen's one main action: this session's counts and the Blue practice button.
    private func dailyLesson(_ status: DailyLessonStatus, due: Int) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.xxs) {
                    Eyebrow(text: "Today’s lesson")
                        .accessibilityAddTraits(.isHeader)
                    // Full touch target without making the eyebrow row taller.
                    if status.scope != .exhaustedNoCustom {
                        lessonInfoButton(status)
                            .padding(.vertical, -(Spacing.minTouchTarget - Spacing.l) / 2)
                    }
                }
                .frame(minHeight: Spacing.l)

                if case .exhaustedNoCustom = status.scope {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        IconBadge(systemImage: "trophy.fill", tone: .reward)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            (plan.current.hasAllTopics
                             ? Text("You’ve learned all of \(plan.current.collection?.name ?? "")")
                             : Text("You’ve learned all your selected topics"))
                                .font(Typography.screenTitle.weight(.heavy))
                            Text("Your learned words will still be reviewed. Choose another collection to learn new words.")
                                .font(Typography.secondary)
                                .foregroundStyle(Color.bodyInk)
                        }
                    }
                    .padding(.top, Spacing.s)
                } else {
                    Text("\(status.sessionReviews) to review · \(status.newWords) new")
                        .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
                        .padding(.top, Spacing.xxs)
                }

                actions(status, due: due)
                    .padding(.top, Spacing.screenGutter)
            }
            .padding(Spacing.screenGutter)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsExtraReview(status) {
                VStack(spacing: 0) {
                    CardDivider()
                    Button(action: startReviewOnly) {
                        HStack(spacing: Spacing.s) {
                            IconBadge(systemImage: "arrow.clockwise", tone: .success)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("\(max(0, status.backlog - status.sessionReviews)) more words waiting")
                                    .font(Typography.secondary.weight(.bold))
                                Text("Review \(status.sessionReviews) words separately, without new words")
                                    .font(Typography.micro).foregroundStyle(Color.mutedInk)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Color.ink400)
                        }
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, Spacing.screenGutter)
                        .padding(.vertical, Spacing.m)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.surface)
            }
        }
        .cardSurface()
    }

    // MARK: Learning now

    /// The collection being learned and its chosen topics (the first five until expanded); bars use the collection's
    /// mark colour, a finished collection's or topic's bar is green.
    private func learningSection(_ collection: VocabCollection) -> some View {
        let mark = CollectionMarkColor.color(for: collection)
        let topics = TopicCatalog.topics(ids: plan.current.topicIDs)
        return VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Learning") {
                TextLink(title: "Change", action: onChooseTopics)
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Dot and name take the whole line; a long name shrinks to 80% and then truncates.
                    HStack(spacing: Spacing.xs) {
                        CollectionMarkDot(color: mark)
                        Text(verbatim: collection.name)
                            .font(Typography.wordClass.weight(.bold))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let total = collection.total, total > 0 {
                        let learned = collection.learned ?? 0
                        ProgressBar(fraction: CGFloat(learned) / CGFloat(total), color: learned >= total ? Color.success : mark, height: 10)
                            .padding(.top, Spacing.s)
                        // Under the bar: "128 / 600 words", or once finished the pill and the total (no "600 / 600").
                        HStack(spacing: Spacing.xs) {
                            if learned >= total {
                                StatusPill("Complete", tone: .success, systemImage: "checkmark")
                                Text("\(total) words")
                            } else {
                                Text("\(learned) / \(total) words")
                            }
                        }
                        .font(Typography.secondary.monospacedDigit())
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.xs)
                    }
                }
                .accessibilityElement(children: .combine)
                .padding(Spacing.m)

                let visible = showsAllTopics ? topics : Array(topics.prefix(Self.collapsedTopicLimit))
                ForEach(visible) { topic in
                    CardDivider()
                    topicRow(topic, mark: mark)
                }
                if topics.count > Self.collapsedTopicLimit {
                    CardDivider()
                    Button {
                        motion.perform(MotionTokens.transition) { showsAllTopics.toggle() }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text(showsAllTopics ? "Show less" : "Show all (\(topics.count))")
                            Image(systemName: showsAllTopics ? "chevron.up" : "chevron.down")
                                .font(Typography.micro.weight(.bold))
                        }
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(Color.link)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardSurface()
        }
    }

    private static let collapsedTopicLimit = 5

    private func topicRow(_ topic: Topic, mark: Color) -> some View {
        HStack(spacing: Spacing.s) {
            IconBadge(systemImage: topic.systemImage, tone: .neutral, size: Spacing.iconButton)
            VStack(alignment: .leading, spacing: Spacing.xs - 2) {
                Text(verbatim: topic.name)
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let total = topic.total, total > 0 {
                    ProgressBar(fraction: CGFloat(topic.learned ?? 0) / CGFloat(total),
                                color: topic.isFinished ? Color.success : mark, height: 6)
                }
            }
            if let total = topic.total {
                let learned = topic.learned ?? 0
                Text(verbatim: "\(learned)/\(total)")
                    .font(Typography.micro.monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
                    .frame(minWidth: Spacing.xl + Spacing.m, alignment: .trailing)
                    .accessibilityLabel(Text("\(learned) of \(total) words learned"))
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s + 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: Lesson info

    private var topicNames: String {
        TopicCatalog.topics(ids: plan.current.topicIDs).map(\.name)
            .formatted(.list(type: .and).locale(AppLanguage.active.locale))
    }

    /// The card shows only this session's counts; why it looks this way (scope, lowered goal, backlog) sits behind ⓘ.
    @ViewBuilder
    private func lessonInfoButton(_ status: DailyLessonStatus) -> some View {
        let lines = noteLines(status)
        if !lines.isEmpty {
            Button {
                isShowingLessonInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("About today’s session"))
            .popover(isPresented: $isShowingLessonInfo) {
                lessonInfo(lines, status: status)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func lessonInfo(_ lines: [Text], status: DailyLessonStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                line
                    .font(Typography.secondary)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .low = status.scope, !plan.current.hasAllTopics {
                Button {
                    isShowingLessonInfo = false
                    onChooseTopics()
                } label: {
                    Text("Add topics")
                        .font(Typography.micro.weight(.heavy))
                        .foregroundStyle(Color.selectedInk)
                        .frame(minHeight: Spacing.minTouchTarget)
                }
            }
        }
        .padding(Spacing.m)
        .frame(width: 280, alignment: .leading)
    }

    private func noteLines(_ status: DailyLessonStatus) -> [Text] {
        var lines: [Text] = []
        switch status.scope {
        case .exhaustedNoCustom:
            lines.append(plan.current.hasAllTopics
                ? Text("You’ve learned every new word in \(topicNames). You can still review and practise them. Choose another collection to learn new words.")
                : Text("You’ve learned every new word in \(topicNames). You can still review and practise them. Choose another topic or collection to learn new words."))
        case .exhaustedWithCustom(let custom):
            lines.append(Text("No new words left in your topics. \(custom) words you added are still to learn."))
        case .low(let remaining, let sessions):
            lines.append(Text("\(remaining) new words left, about \(sessions) sessions"))
        case .ok:
            break
        }
        switch status.reason {
        case .userOverride(let until):
            if let until {
                lines.append(Text("\(status.newWords) new words today (lowered until \(until.formatted(.dateTime.weekday(.wide).locale(AppLanguage.active.locale))))"))
            } else {
                lines.append(Text("\(status.newWords) new words today (lowered until fewer words are waiting)"))
            }
        case .autoBalanced:
            lines.append(Text("\(status.newWords) new words today, balanced with your reviews"))
        case .scopeLimited:
            if case .ok = status.scope { lines.append(Text("Only \(status.newWords) new words left today in \(topicNames)")) }
        case .none:
            break
        }
        if status.backlog > status.sessionReviews {
            lines.append(Text("\(status.backlog) words waiting for review"))
        }
        return lines
    }

    @ViewBuilder
    private func actions(_ status: DailyLessonStatus, due: Int) -> some View {
        if case .exhaustedNoCustom = status.scope {
            VStack(spacing: Spacing.s) {
                if due > 0 {
                    PrimaryButton(title: "Review \(status.sessionReviews) words", shimmers: true, kind: .practice) { startReviewOnly() }
                } else {
                    PrimaryButton(title: "Practise", shimmers: true, kind: .practice, action: onOpenRandomPractice)
                }
                // Every topic of the collection is already chosen: only another collection brings new words.
                SecondaryButton(title: plan.current.hasAllTopics ? "Choose another collection" : "Choose more topics", action: onChooseTopics)
            }
        } else {
            PrimaryButton(title: due > 0 ? "Start" : "Start Flow", shimmers: true, kind: .practice) { start(.daily) }
        }
    }

    private func startReviewOnly() {
        Task { await practice.startReviewOnly() }
    }

    private func start(_ mode: SessionMode, challengeID: String? = nil) {
        Task { await practice.start(mode, challengeID: challengeID) }
    }
}

// MARK: - Daily lesson status

/// What the Daily Lesson card says, from `GET /me/learn-home`. Without the newer blocks it shows the goal as before.
struct DailyLessonStatus: Equatable {
    enum Scope: Equatable {
        case ok
        /// Less than one week of new words left.
        case low(remaining: Int, sessions: Int)
        case exhaustedWithCustom(Int)
        case exhaustedNoCustom
    }

    enum Reason: Equatable {
        case userOverride(until: Date?)
        case autoBalanced
        /// Fewer new words than chosen because that's all the scope holds.
        case scopeLimited
    }

    let newWords: Int
    let backlog: Int
    /// Reviews the next daily session holds: the backlog up to the planner's cap.
    let sessionReviews: Int
    let scope: Scope
    let reason: Reason?

    init(home: LearnHome?, goal: Int) {
        let load = home?.reviewLoad
        newWords = load?.effectiveNewPerSession ?? goal
        backlog = load?.backlog ?? home?.dueCount ?? 0
        let due = home?.dueCount ?? backlog
        sessionReviews = load.map { min(due, $0.dueCap) } ?? due
        switch home?.scope {
        case let scope? where scope.status == .exhausted:
            self.scope = scope.pendingCustomMeanings > 0 ? .exhaustedWithCustom(scope.pendingCustomMeanings) : .exhaustedNoCustom
        case let scope? where scope.status == .low:
            self.scope = .low(remaining: scope.remainingNewMeanings, sessions: scope.sessionsLeftEstimate ?? 1)
        default:
            self.scope = .ok
        }
        switch load?.newWordReason {
        case .userOverride?: reason = .userOverride(until: load?.override?.mode == .untilDate ? load?.override?.until : nil)
        case .autoBalanced?: reason = .autoBalanced
        case .scopeLimited?: reason = .scopeLimited
        default: reason = nil
        }
    }
}

// MARK: - Mascot

/// Syllie at the top of Home (the `HomeSyllie` artboard), on a loop: a short idle, one random play scene (a letter
/// to bounce or a paper plane to chase), a nap (snoring) for `sleepBeat`, waking up, and round again.
/// A tap wakes him early. With reduced motion he skips the play, just dozes off and stays asleep until tapped.
/// Decorative except for that tap.
private struct LessonMascot: View {
    /// How long Syllie idles before he plays.
    private static let idleBeat: Duration = .seconds(2)
    /// How long Syllie naps before he wakes up on his own.
    private static let sleepBeat: Duration = .seconds(6)

    /// The 520×560 artboard at a size where his body is about 104 pt wide (w-[104px]): the body spans ~81% of the width.
    static let size = CGSize(width: 128, height: 138)
    /// Empty room above his body (for the letter and the plane), below it, and the height of his body's centre.
    static let topMargin: CGFloat = 52
    static let bottomMargin: CGFloat = 13
    static let bodyCenterY: CGFloat = 87

    @Environment(\.motion) private var motion
    @State private var scene = HomeSyllieScene.idle

    var body: some View {
        // Accessibility comes from HomeSyllieView: hidden while awake, a "wake him up" button while asleep.
        HomeSyllieView(scene: scene) { scene = .idle }
            .frame(width: Self.size.width, height: Self.size.height)
        .task(id: scene) {
            switch scene {
            case .idle:
                guard await pause(Self.idleBeat) else { return }
                scene = motion.reduceMotion ? .sleepy : (HomeSyllieScene.plays.randomElement() ?? .playLetters)
            case .playLetters, .planeChase:
                guard let duration = scene.duration, await pause(duration) else { return }
                scene = .sleepy
            case .sleepy:
                guard !motion.reduceMotion, await pause(Self.sleepBeat) else { return }
                scene = .wakeUp
            case .wakeUp:
                guard let duration = scene.duration, await pause(duration) else { return }
                scene = .idle
            }
        }
    }

    /// Sleeps for `duration`; false if the task was cancelled (the scene changed or the view went away).
    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return true
        } catch {
            return false
        }
    }
}
