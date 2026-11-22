import SwiftUI

/// Beat 2 of the end of a session (docs/app-redesign-v1.html, 1.12b / 1.12c), after `SessionCelebrationView`:
/// the "Summary" title, the result tiles that have something to show, the LP card and the scope card.
/// Takes plain data so the Practice Lab can show it from fixtures.
struct PracticeResultsView: View {
    let result: PracticeResult
    var effort: SessionEffort?
    var scopeEvents: ScopeEvents?
    var onChooseTopics: (() -> Void)?

    /// Only a finished collection gets the card; a finished topic is not called out.
    private var hasCompletion: Bool { scopeEvents?.collectionCompleted == true }
    /// Only for the fallback grid of a session saved before the result groups existed.
    var firstTryCount = 0
    /// Random and Weak: plan the same practice again.
    var onPracticeAgain: (() -> Void)?
    let onDone: () -> Void

    @Environment(\.motion) private var motion
    @State private var hasAppeared = false
    @State private var sheetSection: ResultSection?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Summary")
                    .font(Typography.display)
                    .tracking(Typography.displayTracking)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                if let tiles = result.tiles {
                    if !tiles.isEmpty {
                        tileRow(tiles)
                            .padding(.top, Spacing.l + Spacing.xxs)
                        detailsLink(opening: tiles[0].section)
                            .padding(.top, Spacing.xs)
                    }
                } else {
                    LegacyResultGrid(summary: result.summary, firstTryCount: firstTryCount, hasAppeared: hasAppeared)
                        .padding(.top, Spacing.l + Spacing.xxs)
                }

                if let effort {
                    ResultEffortCard(effort: effort)
                        .padding(.top, result.tiles?.isEmpty == false ? Spacing.xxs : Spacing.s)
                }

                if hasCompletion, let scopeEvents {
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
                        PrimaryButton(title: "Choose another collection", action: onChooseTopics)
                        SecondaryButton(title: "Later", kind: .outline, action: onDone)
                    } else {
                        PrimaryButton(title: "Done", action: onDone)
                    }
                    if !hasCompletion, let onPracticeAgain {
                        SecondaryButton(title: "Practice again", action: onPracticeAgain)
                    }
                }
            }
        }
        .sheet(item: $sheetSection) { section in
            SessionResultDetailSheet(result: result, focus: section)
        }
        .onAppear {
            // Numbers count up and bars grow once; with reduced motion they are simply there.
            motion.perform(MotionTokens.progress.delay(MotionTokens.celebrationStatsDelay)) { hasAppeared = true }
        }
    }

    /// The one way in to the detail sheet shown as a link; it opens at the top (the first tile's block).
    private func detailsLink(opening section: ResultSection) -> some View {
        Button { sheetSection = section } label: {
            HStack(spacing: Spacing.xxs) {
                Text("See session details")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(Typography.secondary.weight(.semibold))
            .foregroundStyle(Color.link)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .opacity(hasAppeared || motion.reduceMotion ? 1 : 0)
        .animation(motion.travel(MotionTokens.entrance.delay(MotionTokens.celebrationStatsDelay)), value: hasAppeared)
    }

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
