import SwiftUI

/// The LP card under the result tiles: "+N LP" with the lifetime total, one Ink 100 chip per source,
/// and the Tier this session unlocked. Never a rank change (spec §3.5, §10).
struct ResultEffortCard: View {
    let effort: SessionEffort
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            lpSummary
            if let tierUp = effort.celebratedTierUp, let key = tierUp.key {
                CardDivider()
                tierUnlocked(key)
            }
        }
        .padding(Spacing.m)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    private var lpSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .center, spacing: Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Color.reward)
                    .symbolBounceOnce(after: MotionTokens.resultSymbolBounce, when: effort.earned > 0)
                    .accessibilityHidden(true)
                Text("+\(effort.earned) LP")
                    .font(Typography.screenTitle.weight(.heavy).monospacedDigit())
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: Spacing.s)
                Text("\(effort.lifetimeLP) LP in total")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            if effort.earned == 0 {
                Text("Each word earns LP a limited number of times a day, so this session added none.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                    if effort.breakdown.newMeaningLP > 0 { part("New words +\(effort.breakdown.newMeaningLP)") }
                    if effort.breakdown.dueReviewLP > 0 { part("Reviews +\(effort.breakdown.dueReviewLP)") }
                    if effort.breakdown.extraPracticeLP > 0 { part("Extra practice +\(effort.breakdown.extraPracticeLP)") }
                }
            }
        }
    }

    /// A source chip: Ink 100 pill, Ink 700 bold caption.
    private func part(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.caption.weight(.bold))
            .foregroundStyle(Color.ink700)
            .lineLimit(1)
            .padding(.horizontal, Spacing.s - 2)
            .frame(minHeight: Self.chipHeight)
            .background(Color.neutralSurface, in: Capsule())
    }

    /// The `pill` height (h-6).
    private static let chipHeight: CGFloat = 24

    private func tierUnlocked(_ key: TierKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            SyllieReactionView(reaction: motion.reduceMotion ? .idle : key.mood)
                .frame(width: 64, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("You unlocked \(key.localizedName)")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(key.story)
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
