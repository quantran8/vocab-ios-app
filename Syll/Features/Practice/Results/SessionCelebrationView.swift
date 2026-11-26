import RiveRuntime
import SwiftUI

/// Beat 1 of the end of a session (docs/app-redesign-v1.html, 1.12 / 1.12a): Syllie celebrates finishing the session on the
/// `CelebrateV2` artboard of `syllie.riv`, then the title, one line of counts, the LP pill and "Continue" pop in as he lands.
/// The numbers live on the next screen (`PracticeResultsView`). The celebration never depends on the words or the answers,
/// except for the extra beat of a perfect session (crown) or a finished collection (trophy and rays).
struct SessionCelebrationView: View {
    let celebration: SessionCelebration
    /// Settings' Syllie preview plays one variant; a session picks at random.
    var fixedVariant: CelebrationVariant? = nil
    let onContinue: () -> Void

    @Environment(\.motion) private var motion
    @Environment(\.soundEffects) private var sounds
    @State private var variant: CelebrationVariant?
    @State private var showsCopy = false
    /// Set once the artboard is playing; the sound cues count from then.
    @State private var animationStarted = false

    var body: some View {
        GeometryReader { proxy in
            // The artboard is a 390×844 screen: Syllie's stage is centred 230 pt down, about 220 pt tall.
            let width = proxy.size.width
            let scale = width / Self.artboardSize.width
            ZStack(alignment: .top) {
                if motion.reduceMotion {
                    CelebrationBadge()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Self.copyTop * scale - Self.badgeLift)
                } else if let variant {
                    CelebrateV2View(variant: variant, kind: celebration.kind, perfect: celebration.perfect) {
                        animationStarted = true
                    }
                    .frame(width: width, height: Self.artboardSize.height * scale)
                }
                copy
                    .padding(.horizontal, Spacing.practiceGutter)
                    .padding(.top, Self.copyTop * scale)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
        }
        // The artboard is drawn from the top of the screen, status bar included, like the design frame.
        .ignoresSafeArea(edges: .top)
        .contentShape(Rectangle())
        // Tapping before he lands skips to the end.
        .onTapGesture { reveal() }
        .safeAreaInset(edge: .bottom) {
            PracticeActionBar {
                PrimaryButton(title: "Continue", action: onContinue)
            }
            .opacity(showsCopy ? 1 : 0)
            .allowsHitTesting(showsCopy)
        }
        .task {
            let variant = fixedVariant ?? CelebrationVariant.next()
            sounds.prepareCues(variant.soundCues.map(\.name))
            self.variant = variant
            if !motion.reduceMotion {
                try? await Task.sleep(for: variant.landing)
            }
            reveal()
        }
        // Cancelled with the view, so leaving early stops the remaining cues.
        .task(id: animationStarted) {
            guard animationStarted, let variant else { return }
            await playSoundCues(variant.soundCues)
        }
    }

    /// Each cue starts at its offset from the start of the animation.
    private func playSoundCues(_ cues: [CelebrationVariant.SoundCue]) async {
        let clock = ContinuousClock()
        let start = clock.now
        for cue in cues.sorted(by: { $0.at < $1.at }) {
            do {
                try await clock.sleep(until: start + cue.at)
            } catch {
                return
            }
            sounds.playCue(cue.name)
        }
    }

    private var copy: some View {
        VStack(spacing: 0) {
            Text(celebration.title)
                .font(Typography.display)
                .tracking(Typography.displayTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .popIn(showsCopy, delay: 0)
            if let line = celebration.line {
                line
                    .font(Typography.ipaCard)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .popIn(showsCopy, delay: Self.stagger)
            }
            if let lp = celebration.earnedLP {
                LPPill(lp: lp)
                    .padding(.top, Spacing.l + Spacing.xxs)
                    .popIn(showsCopy, delay: Self.stagger * 2)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func reveal() {
        guard !showsCopy else { return }
        motion.perform(MotionTokens.entrance) { showsCopy = true }
    }

    private static let artboardSize = CGSize(width: 390, height: 844)
    /// Where the title starts, in artboard points: just under Syllie's stage.
    private static let copyTop: CGFloat = 364
    private static let stagger: Double = 0.15
    /// With reduced motion the badge stands where Syllie would be, just above the title.
    private static let badgeLift: CGFloat = 140
}

/// What the celebration says, decided from the commit so it can be tested and previewed without a session.
struct SessionCelebration {
    var kind: CelebrationKind
    var perfect: Bool
    var title: LocalizedStringKey
    var line: Text?
    var earnedLP: Int?

    init(kind: CelebrationKind, perfect: Bool, title: LocalizedStringKey, line: Text? = nil, earnedLP: Int? = nil) {
        self.kind = kind
        self.perfect = perfect
        self.title = title
        self.line = line
        self.earnedLP = earnedLP
    }

    /// - Parameter finishedScopeName: the collection this session finished; nil otherwise.
    init(result: PracticeResult, effort: SessionEffort?, scopeEvents: ScopeEvents?, finishedScopeName: String?) {
        let counts = CelebrationCounts(summary: result.summary)
        let finishedCollection = scopeEvents?.collectionCompleted == true
        kind = finishedCollection ? .collection : .session
        perfect = counts.perfect
        earnedLP = effort?.earned

        if let finishedScopeName, finishedCollection {
            title = "You’ve learned every word in \(finishedScopeName)"
        } else if counts.perfect {
            title = "Perfect session"
        } else if counts.newWords == 0, counts.reviewed > 0 {
            title = "Review complete"
        } else {
            title = "Nice work"
        }

        // Only counts, new and reviewed words alike: nothing about right or wrong.
        line = switch (counts.newWords, counts.reviewed) {
        case (0, 0): nil
        case (0, let reviewed): Text("You reviewed \(reviewed) words.")
        case (let new, 0): Text("You learned \(new) new words.")
        case (let new, let reviewed): Text("You learned \(new) new words and reviewed \(reviewed) words.")
        }
    }
}

/// The counts on the celebration and whether the session had no wrong answer, read from the server's groups.
struct CelebrationCounts: Equatable {
    var newWords = 0
    var reviewed = 0
    var perfect = false

    init(summary: CommitSummary) {
        if let review = summary.review {
            reviewed += ReviewGroup.allCases.reduce(0) { $0 + review.groups.count($1) }
        }
        if let new = summary.newWords {
            newWords += NewWordGroup.allCases.reduce(0) { $0 + new.groups.count($1) }
        }
        if let practice = summary.practice {
            let meanings = PracticeGroup.allCases.flatMap { practice.groups[$0] }.map(\.meaningId)
            reviewed += Set(meanings).count
        }
        let hasGroups = summary.review != nil || summary.newWords != nil || summary.practice != nil
        if !hasGroups {
            // A checkpoint, or a session an older backend saved.
            reviewed = summary.checkpoint?.reviewedCount ?? summary.reviewedMeanings ?? 0
            newWords = max(0, (summary.newWordGoalSlots ?? 0) - (summary.knownMeanings ?? 0))
            return
        }
        let weaker = (summary.review.map { $0.groups.count(.shaky) + $0.groups.count(.relearn) } ?? 0)
            + (summary.newWords.map { $0.groups.count(.retried) + $0.groups.count(.revealed) } ?? 0)
            + (summary.practice.map { $0.groups.count(.helped) + $0.groups.count(.missed) } ?? 0)
        perfect = weaker == 0 && newWords + reviewed > 0
    }
}

/// `kind` of the `CelebrateV2` view model: a collection adds the trophy and the turning rays.
enum CelebrationKind: String {
    case session, collection
}

/// `variant` of the `CelebrateV2` view model, with when Syllie lands (the copy appears then).
enum CelebrationVariant: String, CaseIterable {
    case puff, fireworks, flip, loop, bounce

    var landing: Duration {
        switch self {
        case .puff: .seconds(2.8)
        case .fireworks: .seconds(3.0)
        case .flip: .seconds(2.3)
        case .loop: .seconds(2.6)
        case .bounce: .seconds(2.8)
        }
    }

    /// A sound in `Resources/Sounds` (`<name>.wav`) and when it starts, counted from the start of the animation.
    struct SoundCue: Equatable {
        let name: String
        let at: Duration
    }

    /// Matched to the variant's timeline in `syllie.riv` (60 fps): keep in sync when the timing changes there.
    var soundCues: [SoundCue] {
        switch self {
        case .puff: [ // inhale f20–58, pop f58, land f118
            SoundCue(name: "celebrate_puff_inhale", at: .seconds(0.30)),
            SoundCue(name: "celebrate_puff_pop", at: .seconds(0.95)),
            SoundCue(name: "celebrate_puff_land", at: .seconds(1.95)),
        ]
        case .fireworks: [ // rise f0–120 with bursts behind, finale f126
            SoundCue(name: "celebrate_fireworks_rise", at: .zero),
            SoundCue(name: "celebrate_fireworks_finale", at: .seconds(2.08)),
        ]
        case .flip: [ // launch f38, double flip f48–120, land f130
            SoundCue(name: "celebrate_flip_jump", at: .seconds(0.60)),
            SoundCue(name: "celebrate_flip_spin", at: .seconds(0.85)),
            SoundCue(name: "celebrate_flip_land", at: .seconds(2.15)),
        ]
        case .loop: [ // two loops f24–108, sparkle burst f150
            SoundCue(name: "celebrate_loop_swoosh", at: .seconds(0.35)),
            SoundCue(name: "celebrate_loop_sparkle", at: .seconds(2.45)),
        ]
        case .bounce: [ // hops land f48 and f84, launch f94, final landing f150
            SoundCue(name: "celebrate_bounce_boing", at: .seconds(0.78)),
            SoundCue(name: "celebrate_bounce_boing", at: .seconds(1.38)),
            SoundCue(name: "celebrate_bounce_launch", at: .seconds(1.55)),
            SoundCue(name: "celebrate_bounce_land", at: .seconds(2.48)),
        ]
        }
    }

    private static let lastKey = "celebration.lastVariant"

    /// A random variant, never the one shown last time.
    static func next(defaults: UserDefaults? = .standard) -> CelebrationVariant {
        let last = defaults?.string(forKey: lastKey).flatMap(CelebrationVariant.init(rawValue:))
        let pick = pick(after: last)
        defaults?.set(pick.rawValue, forKey: lastKey)
        return pick
    }

    static func pick<G: RandomNumberGenerator>(after last: CelebrationVariant?, using generator: inout G) -> CelebrationVariant {
        allCases.filter { $0 != last }.randomElement(using: &generator) ?? .puff
    }

    static func pick(after last: CelebrationVariant?) -> CelebrationVariant {
        var generator = SystemRandomNumberGenerator()
        return pick(after: last, using: &generator)
    }
}

/// "+45 LP" on Sun 50 (h-11 pill).
private struct LPPill: View {
    let lp: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.reward)
                .accessibilityHidden(true)
            Text("+\(lp) LP")
                .monospacedDigit()
        }
        .font(Typography.screenTitle.weight(.heavy))
        .tracking(Typography.tightTracking)
        .foregroundStyle(Color.sun800)
        .padding(.horizontal, Spacing.m)
        .frame(height: Spacing.minTouchTarget)
        .background(Color.sun50, in: Capsule())
    }
}

private extension View {
    /// The copy pops in from slightly below, one line after the other.
    func popIn(_ shown: Bool, delay: Double) -> some View {
        modifier(PopIn(shown: shown, delay: delay))
    }
}

private struct PopIn: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || motion.reduceMotion ? 1 : 0.85)
            .offset(y: shown || motion.reduceMotion ? 0 : MotionTokens.enterOffset)
            .animation(motion.travel(MotionTokens.entrance.delay(delay)), value: shown)
    }
}

/// The `CelebrateV2` artboard with its view model set before the state machine starts, since the entry transitions read it.
/// Decorative only.
private struct CelebrateV2View: View {
    let variant: CelebrationVariant
    let kind: CelebrationKind
    let perfect: Bool
    /// Called once the state machine is running.
    var onStart: () -> Void = {}

    @StateObject private var player = CelebrateV2Player()

    var body: some View {
        Group {
            if let rive = player.rive {
                RiveUIViewRepresentable(rive: rive)
            } else {
                SwiftUI.Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await player.load(variant: variant, kind: kind, perfect: perfect)
            if player.rive != nil { onStart() }
        }
    }
}

@MainActor
private final class CelebrateV2Player: ObservableObject {
    @Published private(set) var rive: Rive?

    func load(variant: CelebrationVariant, kind: CelebrationKind, perfect: Bool) async {
        guard rive == nil else { return }
        do {
            let file = try await SyllieFile.shared()
            let artboard = try await file.createArtboard("CelebrateV2")
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            instance.setValue(of: EnumProperty(path: "variant"), to: variant.rawValue)
            instance.setValue(of: EnumProperty(path: "kind"), to: kind.rawValue)
            instance.setValue(of: BoolProperty(path: "perfect"), to: perfect)
            let stateMachine = try await artboard.createStateMachine("CelebrateV2", binding: instance)
            rive = try await Rive(file: file, artboard: artboard, stateMachine: stateMachine, fit: .contain(alignment: .topCenter))
        } catch {
            // Decorative: without the file the copy still shows.
        }
    }
}
