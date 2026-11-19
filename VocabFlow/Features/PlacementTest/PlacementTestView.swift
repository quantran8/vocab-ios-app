import SwiftUI

/// The placement test, from loading to its result. Onboarding hosts it as a step and Profile as a full-screen cover,
/// so where each exit leads is up to the host.
struct PlacementTestView: View {
    let doneTitle: LocalizedStringKey
    var isDoneEnabled = true
    /// A failure in whatever the host does next, shown beside the action that retries it.
    var doneError: String?
    let onDone: (PlacementResult) -> Void
    /// The learner sets a level themselves. Carries the result if there is one, which is saved already.
    let onChooseLevel: (PlacementResult?) -> Void
    let onLeave: () -> Void

    @Environment(PlacementTestStore.self) private var store

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            content
        }
        // Answering questions is practice: Blue actions with a depth edge.
        .actionContext(.practice)
    }

    @ViewBuilder
    private var content: some View {
        switch store.stage {
        case .idle, .loading:
            StatusScreen(title: "Preparing your test", isBusy: true, showsFlyingSyllie: true) {
                SecondaryButton(title: "Cancel", action: leave)
            }
        case .noContent:
            StatusScreen(title: "The test isn’t ready yet", message: Text("Choose the level that feels closest. You can change it any time.")) {
                PrimaryButton(title: "Choose my level") { onChooseLevel(nil) }
            }
        case .loadFailed(let message):
            StatusScreen(title: "Couldn’t load the test", message: Text(verbatim: message)) {
                PrimaryButton(title: "Try again") { store.start() }
                SecondaryButton(title: "Choose my level") { onChooseLevel(nil) }
            }
        case .answering:
            if let question = store.currentQuestion {
                PlacementQuestionScreen(question: question, onLeave: leave)
            }
        case .submitting:
            StatusScreen(title: "Working out your level", isBusy: true, showsFlyingSyllie: true)
        case .submitFailed(let message, let canRetry):
            StatusScreen(title: "Couldn’t get your result", message: Text(verbatim: message)) {
                if canRetry {
                    PrimaryButton(title: "Try again") {
                        Task { await store.retrySubmit() }
                    }
                }
                SecondaryButton(title: "Choose my level") { onChooseLevel(nil) }
            }
        case .finished(let result):
            PlacementResultScreen(result: result) {
                if let doneError {
                    Text(verbatim: doneError)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryButton(title: doneTitle, isEnabled: isDoneEnabled) { onDone(result) }
                SecondaryButton(title: "Choose a different level") { onChooseLevel(result) }
            }
        }
    }

    private func leave() {
        store.cancel()
        onLeave()
    }
}

/// The level in large type with its name and example line, the same words as the level list,
/// so the learner knows what it means.
private struct PlacementResultScreen<Actions: View>: View {
    let result: PlacementResult
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: Spacing.m) {
            Spacer()
            VStack(spacing: 0) {
                // At this frame his body is about 96 pt wide.
                SyllieView(mood: .proud)
                    .frame(width: 160, height: 132)
                    .padding(.vertical, -Spacing.m)
                    .accessibilityHidden(true)
                Text("Your level")
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, Spacing.l)
                Text(verbatim: result.proficiencyLevel.rawValue)
                    .font(.system(size: 96, weight: .black))
                    .tracking(-4)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, Spacing.xxs)
                Text(result.proficiencyLevel.title)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Color.ink)
                    .padding(.top, Spacing.xs)
                Text(result.proficiencyLevel.example)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.bodyInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                Text("\(result.correctCount)/\(result.totalCount) correct")
                    .font(Typography.secondary.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ink700)
                    .padding(.horizontal, Spacing.s + 2)
                    .frame(minHeight: 32)
                    .background(Color.neutralSurface, in: Capsule())
                    .padding(.top, Spacing.m + 4)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            VStack(spacing: Spacing.s) {
                actions
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.bottom, Spacing.m)
    }
}

private struct PlacementQuestionScreen: View {
    let question: PlacementQuestion
    let onLeave: () -> Void

    @Environment(PlacementTestStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var isConfirmingLeave = false
    @State private var lastSkip = Date.distantPast

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                stage: "Placement test",
                stageCurrent: store.index + 1,
                stageTotal: store.questions.count,
                step: store.index + 1,
                totalSteps: store.questions.count,
                closeLabel: "Leave the test",
                onClose: { isConfirmingLeave = true }
            )
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.vertical, Spacing.xs)

            ScrollView {
                VStack(spacing: Spacing.l) {
                    if let text = question.question {
                        ExerciseHeading(title: Text(verbatim: text))
                    }
                    Text(verbatim: question.prompt.text)
                        .font(Typography.challengeTerm)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s)
                    answers
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.l)
            }
            .id(question.id)
            .transition(motion.stepTransition)
        }
        .animation(motion.animation(MotionTokens.transition), value: question.id)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    Text("Not sure? Tap Skip: a guess can place you too high.")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Spacing.s) {
                        // A third of the row: Next is the action this screen wants.
                        SecondaryButton(title: "Skip", kind: .outline, action: skip)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                (width - Spacing.screenGutter * 2 - Spacing.s) / 3
                            }
                        PrimaryButton(
                            title: store.isOnLastQuestion ? "See my level" : "Next",
                            isEnabled: store.selectedOptionID != nil
                        ) {
                            Task { await store.confirmAnswer() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isConfirmingLeave) {
            ConfirmSheet(
                style: .leavePractice,
                title: "Leave the test?",
                message: "Your answers won’t be saved.",
                cancelTitle: "Keep going",
                confirmTitle: "Leave"
            ) {
                isConfirmingLeave = false
                onLeave()
            }
        }
    }

    /// Skip stays enabled and in place from one question to the next, so a double tap must not skip two.
    private func skip() {
        guard Date.now.timeIntervalSince(lastSkip) > 0.4 else { return }
        lastSkip = .now
        Task { await store.skipQuestion() }
    }

    private var answers: some View {
        VStack(spacing: Spacing.s) {
            ForEach(question.options) { option in
                ChoiceTileButton(text: option.text, state: store.selectedOptionID == option.id ? .selected : .idle) {
                    store.select(option.id)
                }
            }
        }
    }
}
