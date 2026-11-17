import SwiftUI

/// Settings test tool: plays Syllie's moods, the loading flight, the Challenge celebration and the end-of-session
/// celebration (`CelebrateV2`, each variant, perfect, collection) from `syllie.riv` so they can be checked on a device.
/// Mood and variant names are the Rive enum keys, so they're shown as data.
struct SylliePreviewView: View {
    private enum Mode: Hashable {
        case moods, loading, celebrate, results
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mood = SyllieMood.idle
    @State private var replays = 0
    @State private var mode = Mode.moods
    @State private var showsConfetti = false
    @State private var variant = CelebrationVariant.puff
    @State private var perfect = false
    @State private var finishedCollection = false
    @State private var showsResultCelebration = false

    var body: some View {
        // The mood grid and the results controls are taller than the sheet: they scroll, the buttons stay pinned.
        ScrollView {
            VStack(spacing: Spacing.m) {
                SheetTitle("Syllie animations")
                    .frame(maxWidth: .infinity, alignment: .leading)

                SegmentedControl(
                    options: [(value: Mode.moods, title: "Moods"), (value: Mode.loading, title: "Loading"), (value: Mode.celebrate, title: "Celebrate"), (value: Mode.results, title: "Results")],
                    selection: $mode
                )

                // The celebration covers the whole screen (as on the results screen), so it has no card.
                if mode != .celebrate, mode != .results {
                    Group {
                        if mode == .loading {
                            SyllieLoadingView()
                                .id(replays)
                        } else {
                            SyllieView(mood: mood, replayToken: replays) { mood = .idle }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .cardSurface()
                }

                if mode == .moods {
                    moodButtons
                }

                if mode == .results {
                    resultControls
                }
            }
            .padding(Spacing.screenGutter)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.s) {
                SecondaryButton(title: "Replay") {
                    if mode == .results {
                        showsResultCelebration = true
                    } else {
                        replays += 1
                    }
                }
                PrimaryButton(title: "Done") { dismiss() }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xs)
            .background(Color.canvas)
        }
        .background(Color.canvas)
        .overlay {
            if mode == .celebrate {
                SyllieCelebrationView()
                    .id(replays)
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if mode == .celebrate, showsConfetti {
                ConfettiBurst()
                    .id(replays)
            }
        }
        // The real results celebration, full screen as after a session; "Continue" comes back here.
        .fullScreenCover(isPresented: $showsResultCelebration) {
            SessionCelebrationView(celebration: sampleCelebration, fixedVariant: variant) {
                showsResultCelebration = false
            }
            .background(Color.canvas)
        }
        .task(id: CelebrationRun(mode: mode, replays: replays)) {
            // Same timing as the results screen: confetti as Syllie nears the top of his loop.
            showsConfetti = false
            guard mode == .celebrate else { return }
            do {
                try await Task.sleep(for: SyllieCelebrationView.confettiCue)
            } catch {
                return
            }
            showsConfetti = true
        }
    }

    private struct CelebrationRun: Equatable {
        let mode: Mode
        let replays: Int
    }

    /// Sample copy as after a daily session with new words and reviews.
    private var sampleCelebration: SessionCelebration {
        let title: LocalizedStringKey = finishedCollection
            ? "You’ve learned every word in \("Everyday")"
            : perfect ? "Perfect session" : "Nice work"
        return SessionCelebration(
            kind: finishedCollection ? .collection : .session,
            perfect: perfect,
            title: title,
            line: Text("You learned \(4) new words and reviewed \(9) words."),
            earnedLP: 45
        )
    }

    /// The results celebration: one chip per `CelebrateV2` variant, plus the perfect crown and the collection trophy.
    private var resultControls: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.xs)], spacing: Spacing.xs) {
                ForEach(CelebrationVariant.allCases, id: \.self) { item in
                    Button {
                        variant = item
                    } label: {
                        Text(verbatim: item.rawValue)
                            .font(Typography.secondary.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .chipSurface(isSelected: item == variant)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(item == variant ? .isSelected : [])
                }
            }
            VStack(spacing: 0) {
                Toggle("Perfect session", isOn: $perfect)
                    .padding(Spacing.m)
                CardDivider()
                Toggle("Collection finished", isOn: $finishedCollection)
                    .padding(Spacing.m)
            }
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(Color.ink)
            .cardSurface()
            Text("Tap Replay to play it full screen, as after a session.")
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
        }
    }

    private var moodButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.xs)], spacing: Spacing.xs) {
            ForEach(SyllieMood.allCases) { item in
                Button {
                    mood = item
                } label: {
                    Text(verbatim: item.rawValue)
                        .font(Typography.secondary.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .chipSurface(isSelected: item == mood)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(item == mood ? .isSelected : [])
            }
        }
    }
}
