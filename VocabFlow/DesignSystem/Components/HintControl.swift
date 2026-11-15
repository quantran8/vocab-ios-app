import SwiftUI

struct HintControl: View {
    let hintsUsed: Int
    let maxHints: Int
    let hints: [String]
    let isEnabled: Bool
    /// Off where the answer can't be shown yet, while hints stay available.
    var canReveal = true
    let onHint: () -> Void
    let onReveal: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Button(action: onHint) {
                    Text("Reveal hint \(hintsUsed)/\(maxHints)")
                        .font(Typography.secondary.weight(.heavy))
                        .frame(minHeight: Spacing.minTouchTarget)
                }
                .foregroundStyle(Color.blue700)
                .disabled(!isEnabled || hintsUsed >= maxHints)
                .opacity(isEnabled && hintsUsed < maxHints ? 1 : 0.4)

                Spacer()

                Button(action: onReveal) {
                    Text("Show answer")
                        .font(Typography.secondary.weight(.bold))
                        .frame(minHeight: Spacing.minTouchTarget)
                }
                .foregroundStyle(Color.mutedInk)
                .disabled(!isEnabled || !canReveal)
                .opacity(isEnabled && canReveal ? 1 : 0.4)
            }

            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                Text(verbatim: hint)
                    .font(.system(.callout, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.blue700)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: 32)
                    .background(Color.blue50, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text("Hint: \(hint.replacingOccurrences(of: "_", with: "blank"))"))
                    .transition(motion.popTransition)
            }
        }
        .animation(motion.animation(MotionTokens.feedback), value: hints)
    }
}
