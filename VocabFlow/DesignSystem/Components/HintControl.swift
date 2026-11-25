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

            // One row that fills in: each hint opens the next letter of the same row.
            if let hint = hints.last {
                Text(verbatim: hint)
                    .font(.system(.callout, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.blue700)
                    .contentTransition(.numericText())
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: 32)
                    .background(Color.blue50, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text("Hint: \(hint.replacingOccurrences(of: "_", with: "blank"))"))
                    .transition(motion.popTransition)
            }
        }
        // Keeps the hint row clear of the Check button below.
        .padding(.bottom, hints.isEmpty ? 0 : Spacing.m)
        .animation(motion.animation(MotionTokens.feedback), value: hints)
    }
}
