import SwiftUI

/// The end of a session: the result tiles that have something to show, the LP card, the scope card, Syllie and confetti.
/// Takes plain data so the Practice Lab can show it from fixtures.
struct PracticeResultsView: View {
    let result: PracticeResult
    var effort: SessionEffort?
    var scopeEvents: ScopeEvents?
    /// Only for the fallback grid of a session saved before the result groups existed.
    var firstTryCount = 0
    /// Random and Weak: plan the same practice again.
    var onPracticeAgain: (() -> Void)?
    let onDone: () -> Void

    @Environment(\.motion) private var motion
    @State private var hasAppeared = false
    @State private var showsConfetti = false
    @State private var sheetSection: ResultSection?

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                // The content sits at the bottom so the top of the screen stays clear for Syllie's celebration.
                VStack(spacing: 0) {
                    BrandBar()

                    Spacer(minLength: Spacing.xl)

                    // Without motion there is no Syllie, so the badge stands in for him.
                    if motion.reduceMotion {
                        CelebrationBadge()
                            .padding(.bottom, Spacing.l)
                    }

                    Chip(text: chipText, fill: .reward)

                    Text("Nice work.")
                        .font(Typography.display)
                        .tracking(-1.4)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.s)

                    if let tiles = result.tiles {
                        if !tiles.isEmpty {
                            tileRow(tiles)
                                .padding(.top, Spacing.xl)
                        }
                    } else {
                        LegacyResultGrid(summary: result.summary, firstTryCount: firstTryCount, hasAppeared: hasAppeared)
                            .padding(.top, Spacing.xl)
                    }

                    if let effort {
                        SessionEffortCard(effort: effort)
                            .padding(.top, Spacing.l)
                    }

                    if let scopeEvents, !scopeEvents.isEmpty {
                        ScopeCompletionCard(events: scopeEvents)
                            .padding(.top, Spacing.l)
                    }
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
                .frame(minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.xs) {
                    PrimaryButton(title: "Done", action: onDone)
                    if let onPracticeAgain {
                        SecondaryButton(title: "Practice again", action: onPracticeAgain)
                    }
                }
            }
        }
        .overlay {
            if !motion.reduceMotion {
                SyllieCelebrationView()
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if showsConfetti {
                ConfettiBurst()
            }
        }
        .sheet(item: $sheetSection) { section in
            SessionResultDetailSheet(result: result, focus: section)
        }
        .onAppear {
            // Numbers count up and bars grow once; with reduced motion they are simply there.
            motion.perform(MotionTokens.progress.delay(MotionTokens.celebrationStatsDelay)) { hasAppeared = true }
        }
        .task {
            // The confetti bursts as Syllie nears the top of his loop.
            if !motion.reduceMotion {
                try? await Task.sleep(for: SyllieCelebrationView.confettiCue)
            }
            showsConfetti = true
        }
    }

    private var chipText: LocalizedStringKey {
        switch result.kind {
        case .daily: "Flow complete"
        case .randomPractice, .weakPractice: "Practice complete"
        case .checkpoint: "Review complete"
        }
    }

    /// Tiles of equal height and width; a part with nothing to report has no tile.
    private func tileRow(_ tiles: [ResultTile]) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                ResultTileView(
                    tile: tile,
                    revealed: hasAppeared || motion.reduceMotion,
                    onTap: { sheetSection = tile.section }
                )
                .opacity(hasAppeared || motion.reduceMotion ? 1 : 0)
                .offset(y: hasAppeared || motion.reduceMotion ? 0 : MotionTokens.enterOffset)
                .animation(
                    motion.travel(MotionTokens.entrance.delay(MotionTokens.celebrationStatsDelay + Double(index) * MotionTokens.celebrationStagger)),
                    value: hasAppeared
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The count grid for a commit without result groups: a checkpoint challenge, or a session an older backend saved.
private struct LegacyResultGrid: View {
    let summary: CommitSummary
    let firstTryCount: Int
    let hasAppeared: Bool
    @Environment(\.motion) private var motion

    private struct Stat {
        let label: LocalizedStringKey
        let value: Int
    }

    /// Only the stats this session actually moved; zeros would just distract.
    /// A review reports recall instead, with no pass mark: forgotten words simply come back sooner.
    private var stats: [Stat] {
        if let review = summary.checkpoint {
            return [
                Stat(label: "Words reviewed", value: review.reviewedCount),
                Stat(label: "Remembered on your own", value: review.unaidedRecalledCount),
                Stat(label: "Coming back for review", value: review.needsReviewCount),
            ]
            .filter { $0.value > 0 }
        }
        let known = summary.knownMeanings ?? 0
        return [
            Stat(label: "Exercises done", value: summary.practiceTasks ?? 0),
            Stat(label: "Right first time", value: firstTryCount),
            Stat(label: "Meanings reviewed", value: summary.reviewedMeanings ?? 0),
            Stat(label: "New words", value: (summary.newWordGoalSlots ?? 0) - known),
            Stat(label: "Words you already knew", value: known),
        ]
        .filter { $0.value > 0 }
    }

    /// Two per row; a stat left on its own takes the full row.
    var body: some View {
        let stats = stats
        return VStack(spacing: Spacing.s) {
            ForEach(Array(stride(from: 0, to: stats.count, by: 2)), id: \.self) { start in
                HStack(spacing: Spacing.s) {
                    ForEach(start..<min(start + 2, stats.count), id: \.self) { index in
                        stat(stats[index].label, value: stats[index].value, index: index)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stat(_ label: LocalizedStringKey, value: Int, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value, format: .number)
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Spacing.l - 4)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
        .opacity(hasAppeared || motion.reduceMotion ? 1 : 0)
        .offset(y: hasAppeared || motion.reduceMotion ? 0 : MotionTokens.enterOffset)
        .animation(
            motion.travel(MotionTokens.entrance.delay(MotionTokens.celebrationStatsDelay + Double(index) * MotionTokens.celebrationStagger)),
            value: hasAppeared
        )
    }
}
