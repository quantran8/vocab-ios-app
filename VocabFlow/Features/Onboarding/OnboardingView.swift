import SwiftUI

/// Welcome → Level (optionally through the placement test) → Collection → Topics → Routine → Ready
/// (docs/app-redesign-v1.html, flow 0b). Welcome, the test and Ready are whole screens;
/// the four questions share `SetupFlowView`'s frame.
struct OnboardingView: View {
    private enum Screen {
        case welcome, setup, placement, ready
    }

    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    private var current: Screen {
        switch store.step {
        case .welcome: .welcome
        case .placement: .placement
        case .ready: .ready
        default: .setup
        }
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            screen
                .id(current)
                .transition(motion.stepTransition(isMovingBack: { store.isMovingBack }))
        }
        // Here rather than at each call site: some steps only change once a request answers.
        .animation(motion.animation(MotionTokens.stepSlide), value: store.step)
    }

    @ViewBuilder
    private var screen: some View {
        switch current {
        case .welcome: WelcomeScreen()
        case .setup: SetupFlowView()
        case .placement: PlacementScreen()
        case .ready: ReadyScreen()
        }
    }
}

// MARK: - Welcome

private struct WelcomeScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // At this frame his body is about 160 pt wide.
                SyllieView(mood: .happy)
                    .frame(width: 267, height: 220)
                    .padding(.vertical, -Spacing.l)
                    .accessibilityHidden(true)

                ScreenTitle("Hi, I’m Syllie")
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xl)

                Text("Answer four quick questions and I’ll put together a daily lesson that suits you.")
                    .font(Typography.body)
                    .foregroundStyle(Color.bodyInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .defaultScrollAnchor(.center)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Get started") {
                    motion.perform(MotionTokens.transition) { store.begin() }
                }
            }
        }
    }
}

/// A step's question (28 pt extrabold) and an optional line under it.
struct OnboardingTitle: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.stepTitle)
                .tracking(Typography.sheetTracking)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.l)
    }
}

// MARK: - Setup flow

/// Steps counted by the header: Level, Collection, Topics, Routine.
private let setupStepCount = 4

/// One persistent frame for the four questions. The header and pinned action stay mounted;
/// only the step's content slides, forward on next and backward on back.
private struct SetupFlowView: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(step: stepNumber) { store.back() }

            ZStack(alignment: .top) {
                content
                    .id(store.step)
                    .transition(motion.stepTransition(isMovingBack: { store.isMovingBack }))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            PinnedActionBar {
                PrimaryButton(title: actionTitle, isEnabled: canAct, action: act)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.step {
        case .collection: CollectionStep()
        case .topics: TopicsStep()
        case .routine: RoutineStep()
        default: LevelStep()
        }
    }

    private var stepNumber: Int {
        switch store.step {
        case .collection: 2
        case .topics: 3
        case .routine: 4
        default: 1
        }
    }

    private var actionTitle: LocalizedStringKey {
        store.step == .routine ? "Create my study plan" : "Continue"
    }

    private var canAct: Bool {
        switch store.step {
        case .level: store.level != nil && !store.isSaving
        case .collection: store.canContinueFromCollection
        case .topics: store.canContinueFromTopics
        case .routine: store.draft.isComplete && !store.isSaving
        default: false
        }
    }

    private func act() {
        switch store.step {
        case .level: Task { await store.continueToCollection() }
        case .collection: store.continueToTopics()
        case .topics: store.continueToRoutine()
        case .routine: Task { await store.createFlow() }
        default: break
        }
    }
}

/// Round back button and one segment per question; the bar says which step this is, so there's no "Step 2 of 4".
private struct SetupHeader: View {
    let step: Int
    let onBack: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.s) {
            IconButton(systemImage: "chevron.left", label: "Back", action: onBack)

            HStack(spacing: Spacing.xs - 2) {
                ForEach(1...setupStepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.interactive : Color.track)
                        .frame(height: 6)
                }
            }
            .animation(motion.animation(MotionTokens.progress), value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Step \(step) of \(setupStepCount)"))

            // Balances the back button so the bar stays centred.
            Color.clear.frame(width: Spacing.minTouchTarget, height: 1)
        }
        .padding(.horizontal, Spacing.screenGutter - (Spacing.minTouchTarget - Spacing.iconButton) / 2)
        .padding(.top, Spacing.xs)
    }
}

/// A scrolling step body with the frame's margins.
private struct StepPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
    }
}

private struct SaveErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Label {
                Text(verbatim: message)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(Typography.secondary.weight(.medium))
            .foregroundStyle(Color.destructiveInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.m)
        }
    }
}

// MARK: - Level

private struct LevelStep: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(PlacementTestStore.self) private var placement
    @Environment(\.motion) private var motion

    var body: some View {
        StepPage {
            OnboardingTitle(title: "What’s your English level?")

            placementCard
                .padding(.top, Spacing.l)

            Eyebrow(text: "Or choose it yourself")
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.s - 2)

            LevelList(selected: store.level) { level in
                motion.perform(MotionTokens.snap) { store.selectLevel(level) }
            }

            SaveErrorText(message: store.errorMessage)
        }
    }

    /// First, so someone unsure sees it before guessing on the list.
    private var placementCard: some View {
        Button {
            placement.start()
            store.openPlacementTest()
        } label: {
            HStack(spacing: Spacing.s) {
                IconBadge(systemImage: "scope", tone: .accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not sure? Take the test")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text("Syll scores it and picks your level")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink400)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.m)
            .cardSurface()
            .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PlacementScreen: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        PlacementTestView(
            doneTitle: "Use this level",
            isDoneEnabled: !store.isSaving,
            doneError: store.errorMessage,
            onDone: { result in
                Task { await store.acceptPlacement(result) }
            },
            onChooseLevel: { result in
                store.chooseLevelByHand(after: result)
            },
            onLeave: {
                store.back()
            }
        )
    }
}

// MARK: - Collection

private struct CollectionStep: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        StepPage {
            OnboardingTitle(
                title: "Which collection do you want to learn?",
                subtitle: "Pick one. You can change it any time."
            )

            CollectionList(selectedID: store.draft.collectionID) { id in
                motion.perform(MotionTokens.snap) { store.selectCollection(id) }
            }
            .padding(.top, Spacing.l)
        }
    }
}

// MARK: - Topics

private struct TopicsStep: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        StepPage {
            OnboardingTitle(
                title: "Which topics interest you?",
                subtitle: "New words come from the topics you choose."
            )

            if let collection = store.draft.collection {
                TopicPicker(
                    collection: collection,
                    selectedIDs: store.draft.topicIDs,
                    onToggleTopic: { store.toggleTopic($0) },
                    onToggleAll: { store.toggleAllTopics() },
                    countsSelection: true,
                    showsProgress: false
                )
                .padding(.top, Spacing.l)
            }
        }
    }
}

// MARK: - Routine

private struct RoutineStep: View {
    @Environment(OnboardingStore.self) private var store

    var body: some View {
        @Bindable var store = store

        StepPage {
            OnboardingTitle(title: "Your routine")

            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.s - 2) {
                    PlanSectionTitle(text: "New words / day")
                    WordsPerDayStepper(value: store.draft.wordsPerDay) { store.adjustWordsPerDay(by: $0) }
                }
                LearningDaysPicker(
                    selected: store.draft.learningDays,
                    onToggleDay: { store.toggleDay($0) },
                    onToggleEveryDay: { store.toggleEveryDay() }
                )
                ReminderPicker(preferences: $store.draft)
            }
            .padding(.top, Spacing.l + 4)

            SaveErrorText(message: store.errorMessage)
        }
    }
}

// MARK: - Ready

/// The plan in one card, and the first lesson one tap away.
private struct ReadyScreen: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // At this frame his body is about 112 pt wide.
                SyllieView(mood: .proud)
                    .frame(width: 187, height: 154)
                    .padding(.vertical, -Spacing.m)
                    .accessibilityHidden(true)

                ScreenTitle("Your plan is ready")
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.l)

                Text("Your first lesson has \(store.draft.wordsPerDay) new words.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)

                summary
                    .padding(.top, Spacing.xl)

                Text("You can change this in Profile.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.s)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xl + Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Start my first lesson", kind: .practice, action: startFirstLesson)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 0) {
            if let level = store.level {
                row("Level") { Text(verbatim: level.rawValue) }
                CardDivider()
            }
            if let collection = store.draft.collection {
                row("Collection") {
                    HStack(spacing: Spacing.xs) {
                        CollectionMarkDot(color: CollectionMarkColor.color(for: collection))
                        Text("\(collection.name) · \(store.draft.topicIDs.count) topics")
                    }
                }
                CardDivider()
            }
            row("Each day") { Text("\(store.draft.wordsPerDay) new words") }
            CardDivider()
            row("Learning days") { LearningDaysSummary.text(store.draft.learningDays) }
            CardDivider()
            row("Reminder") { reminderText }
        }
        .cardSurface()
    }

    private func row<Value: View>(_ label: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        CardRow {
            Text(label)
                .foregroundStyle(Color.bodyInk)
            Spacer(minLength: Spacing.s)
            value()
                .font(Typography.emphasis)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var reminderText: Text {
        guard store.draft.reminderEnabled else { return Text("Off") }
        return Text(verbatim: store.draft.reminderDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.active.locale)
        ))
    }

    /// Both in one main-actor turn: the route leaves onboarding straight for the session, never showing Home.
    private func startFirstLesson() {
        Task {
            store.finish()
            await practice.start(.daily)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(OnboardingStore(
            plan: LearningPlanStore(storage: InMemoryPreferencesStore(), reminders: NoReminders()),
            haptics: NoOpFeedback()
        ))
        .environment(PlacementTestStore(api: OfflineVocabAPI(), haptics: NoOpFeedback()))
        .environment(PracticeSessionStore(
            api: OfflineVocabAPI(),
            audio: SilentAudioClips(),
            recorder: NoVoiceRecorder(),
            haptics: NoOpFeedback(),
            transcriber: NoSpeechTranscriber()
        ))
}
