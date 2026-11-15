import SwiftUI

/// A learner's chosen avatar from the server allowlist. Stand-in art until the Syllie set is drawn.
/// Without a key it shows `initial` (Blue 100 / Blue 700), as the redesign draws avatars.
struct AvatarView: View {
    let key: String
    var size: CGFloat = Spacing.iconBadge
    /// Nil draws a circle.
    var cornerRadius: CGFloat? = nil
    /// Shown when there is no avatar key yet.
    var initial: String? = nil

    var body: some View {
        let shape = cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) } ?? AnyShape(Circle())
        Group {
            if key.isEmpty, let initial, !initial.isEmpty {
                shape
                    .fill(Color.blue100)
                    .overlay(
                        Text(verbatim: initial.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .heavy))
                            .foregroundStyle(Color.blue700)
                    )
            } else {
                shape
                    .fill(AvatarStyle.background(key))
                    .overlay(
                        Image(systemName: AvatarStyle.symbol(key))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundStyle(Color.ink)
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Profile's Tier card: current Tier, LP toward the next one and a Sun progress bar.
/// Learning days stay on the detail screen.
struct ProfileTierCard: View {
    let summary: TierSummary
    var next: NextTier?

    private var key: TierKey? { summary.level > 0 ? summary.key : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                IconBadge(systemImage: key?.systemImage ?? "trophy", tone: key == nil ? .neutral : .reward)
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if let key { Text(key.name) } else { Text("No Tier yet") }
                    }
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                    Group {
                        if let next {
                            Text("Progress to \((next.key ?? .unknown).localizedName)")
                        } else {
                            Text("Current Tier")
                        }
                    }
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                }
                Spacer(minLength: Spacing.xs)
                if let next {
                    Text("\(summary.lifetimeLP) / \(next.minLifetimeLP) LP")
                        .font(Typography.secondary.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if let next {
                ProgressBar(
                    fraction: next.minLifetimeLP > 0
                        ? CGFloat(min(Double(summary.lifetimeLP) / Double(next.minLifetimeLP), 1)) : 1,
                    color: .reward,
                    height: Spacing.s - 2
                )
            } else if key != nil {
                Text("You’ve reached the highest Tier. Your LP keeps adding up.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

/// Small lifetime-Tier marker for a leaderboard row. Level 0 shows nothing: there is no "Tier 0".
struct TierBadgeLabel: View {
    let badge: TierBadge

    var body: some View {
        if let key = badge.key, badge.level > 0 {
            Label {
                Text(key.name)
            } icon: {
                Image(systemName: key.systemImage)
            }
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(Color.mutedInk)
            .labelStyle(.titleAndIcon)
        }
    }
}
