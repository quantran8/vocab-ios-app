import SwiftUI

/// The Premium identity (redesign v1, flow 6): Grape for the Premium blocks, Sun 400 as the spark (crown, Premium button),
/// and one signature gradient, Grape 500 → Coral 400. Only the paywall, Premium entry points and the plan cards use it.
enum PremiumGradient {
    /// "Premium" in headlines and copy: Grape 500 → Coral 400 (the key visual's two outer cards).
    static let accent = LinearGradient(colors: [.grape500, .coral400], startPoint: .leading, endPoint: .trailing)
    /// The paywall's wash and the Profile upgrade card: Grape 100 → Grape 50 → Coral 100, diagonal.
    static let wash = LinearGradient(
        stops: [.init(color: .grape100, location: 0), .init(color: .grape50, location: 0.48), .init(color: .coral100, location: 1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// The wash over the top of the paywall at full strength, fading into white before the table or the plans.
struct PremiumWash: View {
    var height: CGFloat = 460

    var body: some View {
        PremiumGradient.wash
            .frame(height: height)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// "Premium" in the signature gradient with the Home Start button's shimmer running through the letters
/// (`MotionTokens.shimmerSweep` every `shimmerCycle`). Reduce Motion: the gradient stays, no sweep.
/// Takes its font from the environment.
struct PremiumWord: View {
    @Environment(\.motion) private var motion

    var body: some View {
        Text(verbatim: "Premium")
            .foregroundStyle(PremiumGradient.accent)
            .overlay {
                if !motion.reduceMotion {
                    ShimmerSweep().mask(Text(verbatim: "Premium"))
                }
            }
    }
}

/// Crown on a Grape 500 disc: the Premium badge on Profile's plan cards.
struct PremiumBadge: View {
    var size: CGFloat = Spacing.iconBadge

    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Color.sun400)
            .frame(width: size, height: size)
            .background(Color.grape500, in: Circle())
            .accessibilityHidden(true)
    }
}
