import SwiftUI

/// Practice scaffold shared by every template: question → prompt → exercise → feedback → pinned action.
struct TaskScaffold<Content: View, Action: View>: View {
    let attempt: TaskAttempt
    /// Replaces the attempt's own feedback, for a result that doesn't change its status (Recording).
    var feedback: FeedbackCopy? = nil
    /// Recording's unscored first step: the meaning and its question stand in for the task's question and word.
    var meaningCue: MeaningCue? = nil
    /// Called on a tap anywhere in the scroll area that no control takes, e.g. to close the keyboard (Typing).
    var onTapOutside: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action
    /// The reactions for the next right and wrong answer, picked ahead so they're ready before the answer renders.
    /// Stored, not computed: a random value read in `body` would change on every render and restart the reaction.
    @State private var happyMood: SyllieMood?
    @State private var oopsMood: SyllieMood?
    /// The loop while the question is unanswered (`thinking` or `deepThought`), stored for the same reason.
    @State private var thinkingMood: SyllieMood?
    /// The mood Syllie actually shows. It follows `mascotMood`, except that a right/wrong reaction waits for
    /// the answer's own animation (`MotionTokens.answerFeedbackSettle`), so he keeps thinking until it's over.
    @State private var shownMood: SyllieMood?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let meaningCue {
                    ExerciseHeading(title: Text(verbatim: meaningCue.question))
                    MeaningCueText(text: meaningCue.text)
                } else {
                    if let question = attempt.task.question {
                        ExerciseHeading(title: Text(verbatim: question))
                    }
                    TaskPromptView(attempt: attempt)
                }

                // While a wrong answer is shown, the exercise waits for "Try again" or "Continue".
                content
                    .allowsHitTesting(attempt.status != .wrong && attempt.status != .exhausted)
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .modifier(TapOutside(action: onTapOutside))
        .stepActionBar {
            FeedbackActionPanel(feedback: feedback ?? TaskFeedbackCopy.make(attempt), mascot: shownMood ?? mascotMood) { action }
        }
        .task(id: mascotMood) {
            let target = mascotMood
            if Self.isAnswerReaction(target), shownMood != nil {
                do {
                    try await Task.sleep(for: .seconds(MotionTokens.answerFeedbackSettle))
                } catch {
                    return
                }
            }
            shownMood = target
        }
        .onAppear {
            if happyMood == nil { happyMood = SyllieMood.nextHappyReaction() }
            if oopsMood == nil { oopsMood = SyllieMood.nextOopsReaction() }
            if thinkingMood == nil { thinkingMood = SyllieMood.nextThinking() }
        }
        .onChange(of: attempt.status) { old, new in
            // Re-pick once a reaction is over, so the pick is ready before the next one renders.
            // Wrong → exhausted keeps the same oops instead of starting a second one.
            if old == .solved { happyMood = SyllieMood.nextHappyReaction() }
            if Self.isMiss(old), !Self.isMiss(new) { oopsMood = SyllieMood.nextOopsReaction() }
            // Back to answering after "Try again": a fresh pick, so a retry may show the other loop.
            if old != .answering, new == .answering { thinkingMood = SyllieMood.nextThinking() }
        }
        .onChange(of: feedback?.kind) { old, _ in
            // Recording: each take's result comes through `feedback` while the status stays `answering`.
            if old == .success { happyMood = SyllieMood.nextHappyReaction() }
            if old == .error { oopsMood = SyllieMood.nextOopsReaction() }
        }
    }

    /// A random thinking loop (`thinking` / `deepThought`) while the question is unanswered, the next happy variant on a right answer, the next oops on a miss;
    /// `SyllieReactionView` settles the one-shot reactions back to idle.
    private var mascotMood: SyllieMood {
        // A take's result (Recording) is shown through `feedback` before the status changes.
        if let feedback, attempt.status == .answering {
            switch feedback.kind {
            case .success: return happyMood ?? .happy
            case .error: return oopsMood ?? .oops
            case .info: return .idle
            }
        }
        return switch attempt.status {
        case .solved: happyMood ?? .happy
        case .wrong, .exhausted: oopsMood ?? .oops
        case .answering: thinkingMood ?? .thinking
        case .recorded, .revealed: .idle
        }
    }

    private static func isAnswerReaction(_ mood: SyllieMood) -> Bool {
        SyllieMood.happyReactions.contains(mood) || SyllieMood.oopsReactions.contains(mood)
    }

    private static func isMiss(_ status: TaskAttempt.Status) -> Bool {
        status == .wrong || status == .exhausted
    }
}

/// Only attached when there's an action, so tasks without one (drag-based ones) get no extra gesture.
private struct TapOutside: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
        } else {
            content
        }
    }
}

/// A task has at most one prompt kind. Audio stays audio: showing the text would give the answer away.
struct TaskPromptView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store

    var body: some View {
        switch attempt.task.prompt {
        case nil:
            EmptyView()
        case .text(let text, let highlight)?:
            if attempt.task.template == .clozeSelect {
                // Cloze: the sentence's translation, a quiet line above the sentence itself.
                promptText(text, highlight: highlight)
                    .font(Typography.body)
                    .foregroundStyle(Color.bodyInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            } else {
                promptText(text, highlight: highlight)
                    .font(promptFont)
                    .tracking(Typography.displayTracking)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: Self.promptMinHeight)
            }
        case .audio?:
            VStack(spacing: Spacing.s) {
                AudioPlayButton(isSpeaking: store.audio.isPlaying, isAvailable: true, isLarge: true) {
                    Task { await store.playPromptAudio() }
                }
                if store.audioFailed {
                    Text("Sound didn’t play. Try again, or answer without it.")
                        .font(Typography.micro)
                        .foregroundStyle(Color.errorInk)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            // Heard once as the task appears, after the step transition; leaving the task cancels it.
            .task(id: attempt.task.id) {
                try? await Task.sleep(for: Self.autoplayDelay)
                guard !Task.isCancelled else { return }
                await store.playPromptAudio()
            }
        }
    }

    private static let autoplayDelay: Duration = .milliseconds(350)

    /// The word or meaning stands alone: 36 pt for a word, 30 pt for a meaning to type or spell.
    private var promptFont: Font {
        switch attempt.task.template {
        case .typing, .flyReorder: Typography.stat
        default: Typography.challengeTerm
        }
    }

    /// The prompt's area is as tall as the audio button, so text and audio prompts start the content at one height.
    static let promptMinHeight: CGFloat = 96

    private func promptText(_ text: String, highlight: PromptHighlight?) -> Text {
        guard let parts = highlight?.split(text) else { return Text(verbatim: text) }
        return Text(verbatim: parts.before)
            + Text(verbatim: parts.word).foregroundColor(Color.interactive).underline()
            + Text(verbatim: parts.after)
    }
}

/// A meaning shown in place of the word, styled like a meaning prompt (Typing, Reorder).
private struct MeaningCueText: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Typography.stat)
            .tracking(Typography.displayTracking)
            .foregroundStyle(Color.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: TaskPromptView.promptMinHeight)
    }
}

/// Feedback never names the answer until the task is finished.
enum TaskFeedbackCopy {
    static func make(_ attempt: TaskAttempt) -> FeedbackCopy? {
        let answer = attempt.solutionText
        switch attempt.status {
        case .answering, .recorded:
            return nil
        case .solved:
            return FeedbackCopy(kind: .success, title: String(localized: "Correct!", bundle: .appLanguage),
                                message: answer ?? String(localized: "All pairs matched.", bundle: .appLanguage))
        case .wrong:
            return FeedbackCopy(kind: .error, title: String(localized: "Not quite", bundle: .appLanguage),
                                message: String(localized: "Try again, or show the answer.", bundle: .appLanguage))
        case .revealed:
            return FeedbackCopy(kind: .info, title: String(localized: "Here’s the answer", bundle: .appLanguage),
                                message: answer ?? attempt.allPairsText ?? "")
        case .exhausted:
            // The exercise keeps the learner's work; this panel is the only place the answer appears.
            return FeedbackCopy(kind: .info, title: String(localized: "The correct answer", bundle: .appLanguage),
                                message: answer ?? attempt.missedPairsText ?? "")
        }
    }
}

/// Check while answering, Try again after a miss, Continue once finished.
struct TaskActionBar: View {
    let attempt: TaskAttempt
    var checkTitle: LocalizedStringKey = "Check"
    var canCheck = false
    /// Status line shown in place of Check when there is none (Match submits pair by pair).
    var requirement: LocalizedStringKey?
    var onCheck: (() -> Void)?
    /// Offers "Show answer" here. Off where `HintControl` already does.
    var showsReveal = true

    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(spacing: Spacing.s) {
            if attempt.isFinished {
                PrimaryButton(title: "Continue", kind: attempt.status == .solved ? .success : .app) {
                    motion.perform(MotionTokens.transition) { store.advance() }
                }
            } else if attempt.status == .wrong {
                revealButton
                PrimaryButton(title: "Try again", kind: .retry) {
                    withAnimation(motion.travel(MotionTokens.returnToOrigin)) { store.tryAgain() }
                }
            } else {
                if showsReveal {
                    revealButton
                }
                if let onCheck {
                    PrimaryButton(title: checkTitle, isEnabled: canCheck, action: onCheck)
                } else if let requirement {
                    Text(requirement)
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                }
            }
        }
    }

    @ViewBuilder
    private var revealButton: some View {
        if attempt.canReveal {
            Button {
                store.reveal()
            } label: {
                Text("Show answer")
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(attempt.status == .wrong ? Color.destructiveInk : Color.mutedInk)
                    .frame(minHeight: Spacing.minTouchTarget)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
