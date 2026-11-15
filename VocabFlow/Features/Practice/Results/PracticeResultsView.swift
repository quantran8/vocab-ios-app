import SwiftUI

/// The end of a session (docs/app-redesign-v1.html, 1.12): Syllie celebrating at the top, the "Session complete" pill and
/// title, the result tiles that have something to show, the LP card, the scope card, and confetti.
/// Takes plain data so the Practice Lab can show it from fixtures.
struct PracticeResultsView: View {
    let result: PracticeResult
    var effort: SessionEffort?
    var scopeEvents: ScopeEvents?
    var onChooseTopics: (() -> Void)?

    private var hasCompletion: Bool { scopeEvents.map { !$0.isEmpty } ?? false }
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
        ScrollView {
            VStack(spacing: 0) {
                // Without motion there is no animated Syllie, so the badge stands in for him.
                if motion.reduceMotion {
                    CelebrationBadge()
                } else {
                    // The `Syllie` artboard (520×430) has room around him for his gestures; at this frame his body
                    // is about 112 pt wide, and the negative padding trims the empty margin above and below.
                    SyllieArtboardView(artboard: "Syllie", stateMachine: "Celebrate")
                        .frame(width: (hasCompletion ? 133 : Self.mascotWidth), height: (hasCompletion ? 133 : Self.mascotWidth) * 430 / 520)
                        .padding(.vertical, -Spacing.m)
                }

                Text(chipText)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(Color.sun800)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: Self.chipHeight)
                    .background(Color.sun100, in: Capsule())
                    .padding(.top, Spacing.m)

                Text("Nice work")
                    .font(Typography.display)
                    .tracking(Typography.displayTracking)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)

                if let tiles = result.tiles {
                    if !tiles.isEmpty {
                        tileRow(tiles)
                            .padding(.top, Spacing.l + Spacing.xxs)
                    }
                } else {
                    LegacyResultGrid(summary: result.summary, firstTryCount: firstTryCount, hasAppeared: hasAppeared)
                        .padding(.top, Spacing.l + Spacing.xxs)
                }

                if let effort {
                    ResultEffortCard(effort: effort)
                        .padding(.top, Spacing.s)
                }

                if let scopeEvents, !scopeEvents.isEmpty {
                    ScopeCompletionCard(events: scopeEvents)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            PracticeActionBar {
                VStack(spacing: Spacing.s) {
                    if hasCompletion, let onChooseTopics {
                        PrimaryButton(title: scopeEvents?.collectionCompleted == true ? "Choose another collection" : "Choose more topics", action: onChooseTopics)
                        SecondaryButton(title: "Later", action: onDone)
                    } else {
                        PrimaryButton(title: "Done", action: onDone)
                    }
                    if !hasCompletion, let onPracticeAgain {
                        SecondaryButton(title: "Practice again", action: onPracticeAgain)
                    }
                }
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
            // The confetti bursts once Syllie has started celebrating.
            if !motion.reduceMotion {
                try? await Task.sleep(for: SyllieCelebrationView.confettiCue)
            }
            showsConfetti = true
        }
    }

    private var chipText: LocalizedStringKey {
        switch result.kind {
        case .daily: "Session complete"
        case .randomPractice, .weakPractice: "Practice complete"
        case .checkpoint: "Review complete"
        }
    }

    /// Frame of the `Syllie` artboard that shows his body about 112 pt wide (w-28).
    private static let mascotWidth: CGFloat = 186

    /// The "Session complete" pill (h-7).
    private static let chipHeight: CGFloat = 28

    /// Tiles of equal height and width; a part with nothing to report has no tile.
    private func tileRow(_ tiles: [ResultTile]) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
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
                .font(Typography.stat.monospacedDigit())
                .foregroundStyle(Color.ink)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .opacity(hasAppeared || motion.reduceMotion ? 1 : 0)
        .offset(y: hasAppeared || motion.reduceMotion ? 0 : MotionTokens.enterOffset)
        .animation(
            motion.travel(MotionTokens.entrance.delay(MotionTokens.celebrationStatsDelay + Double(index) * MotionTokens.celebrationStagger)),
            value: hasAppeared
        )
    }
}
