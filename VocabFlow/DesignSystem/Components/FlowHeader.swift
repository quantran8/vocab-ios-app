import SwiftUI

/// A bare ✕ (no circle) plus progress. `.segmented` shows one segment per step and a "1 / 5" count (word intro);
/// `.continuous` is a single bar (exercises).
struct FlowHeader: View {
    enum Style { case segmented, continuous }

    var style: Style = .continuous
    /// Accessibility name of the progress (e.g. "Learn", "Build").
    let stage: LocalizedStringKey
    let stageCurrent: Int
    let stageTotal: Int
    let step: Int
    let totalSteps: Int
    var closeLabel: LocalizedStringKey = "Exit flow"
    let onClose: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ink400)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(Text(closeLabel))
            // Laid out in a 24 pt slot (the icon's), keeping the 44 pt target overhanging both sides.
            .padding(.horizontal, -(Spacing.minTouchTarget - Self.sideSlot) / 2)

            Group {
                switch style {
                case .segmented: segmentedBar
                case .continuous: continuousBar
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(stage))
            .accessibilityValue(Text("Question \(stageCurrent) of \(stageTotal)"))

            // As wide as the ✕ slot, so the bar sits centred on the screen.
            if style == .segmented {
                Text(verbatim: "\(step) / \(totalSteps)")
                    .font(Typography.micro.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize()
                    .frame(minWidth: Self.sideSlot, alignment: .trailing)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: Self.sideSlot, height: 0)
            }
        }
    }

    /// The ✕ icon's width; the bar keeps this much room on each side.
    private static let sideSlot: CGFloat = 24

    private var segmentedBar: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<max(totalSteps, 1), id: \.self) { index in
                Capsule()
                    .fill(index < step ? Color.interactive : Color.track)
                    .frame(height: 10)
            }
        }
        .animation(motion.animation(MotionTokens.progress), value: step)
    }

    private var continuousBar: some View {
        ProgressTrack(fraction: fraction, height: 10)
    }

    private var fraction: CGFloat {
        totalSteps > 0 ? CGFloat(step) / CGFloat(totalSteps) : 0
    }
}
