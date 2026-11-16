import SwiftUI

// SF Symbol motion rules (which icons move, and when) — see memory sf-symbol-motion.
extension View {
    /// Replace transition when `value` swaps the glyph; an instant swap with reduced motion.
    func symbolReplace<Value: Equatable>(value: Value) -> some View {
        modifier(SymbolReplaceModifier(value: value))
    }

    /// One bounce of the symbols inside, `delay` after this view appears or `isEnabled` turns on.
    func symbolBounceOnce(after delay: Double = 0, when isEnabled: Bool = true) -> some View {
        modifier(SymbolBounceOnceModifier(delay: delay, isEnabled: isEnabled))
    }
}

private struct SymbolReplaceModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        if motion.reduceMotion {
            content
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .animation(MotionTokens.symbolSwap, value: value)
        }
    }
}

private struct SymbolBounceOnceModifier: ViewModifier {
    let delay: Double
    let isEnabled: Bool
    @Environment(\.motion) private var motion
    @State private var bounces = 0

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, value: bounces)
            .task(id: isEnabled) {
                guard isEnabled, !motion.reduceMotion else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                bounces += 1
            }
    }
}
