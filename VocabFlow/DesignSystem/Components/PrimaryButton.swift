import SwiftUI
import UIKit

/// Where a button sits. The primary button is Ink with a depth edge everywhere (Check, Continue, Save…);
/// Blue `.practice` is only for actions that start practice (Home "Continue", "Practise now"), passed explicitly.
/// The context picks the secondary button: white `.outline3D` with a depth edge in practice, flat `.outline` elsewhere.
enum ActionContext {
    case practice, app
}

extension EnvironmentValues {
    @Entry var actionContext: ActionContext = .app
}

extension View {
    /// Buttons below take their default kind from this context (`PrimaryButton`, `SecondaryButton`).
    func actionContext(_ context: ActionContext) -> some View {
        environment(\.actionContext, context)
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var requirement: LocalizedStringKey?
    var isEnabled = true
    var shimmers = false
    /// Nil is `.app` (Ink). Pass `.practice` (Blue) for an action that starts practice.
    var kind: ActionButtonStyle.Kind?
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if !isEnabled, let requirement {
                Text(requirement)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
            }
            Button(action: action) {
                ActionButtonLabel(title: title, systemImage: systemImage)
            }
            .buttonStyle(ActionButtonStyle(kind: kind ?? .app, shimmers: shimmers))
            .disabled(!isEnabled)
        }
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    /// Nil follows `actionContext`: `.outline3D` in practice, flat `.outline` elsewhere.
    var kind: ActionButtonStyle.Kind?
    let action: () -> Void
    @Environment(\.actionContext) private var context

    var body: some View {
        Button(action: action) {
            ActionButtonLabel(title: title, systemImage: systemImage, iconLeading: true)
        }
        .buttonStyle(ActionButtonStyle(kind: kind ?? (context == .practice ? .outline3D : .outline)))
    }
}

/// Flat Coral 600 with white text; a confirmation sheet's final action.
struct DestructiveButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(Typography.action)
            .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
        }
        .buttonStyle(ActionButtonStyle(kind: .danger))
    }
}

/// The small inline button ("+ Thêm từ", "Luyện ngay"): 36 pt, hugs its label.
struct SmallButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var kind: ActionButtonStyle.Kind = .outline
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs - 2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .minimumScaleFactor(fillsWidth ? 0.8 : 1)
            }
            .font(Typography.actionSmall)
            .lineLimit(1)
            .fixedSize(horizontal: !fillsWidth, vertical: true)
            .padding(.horizontal, fillsWidth ? Spacing.s : Spacing.m)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: Spacing.buttonSmallHeight)
        }
        // Never squeezed into "…" by a row: the row's text wraps instead.
        .layoutPriority(1)
        .buttonStyle(ActionButtonStyle(kind: kind, size: .small))
    }
}

struct ActionButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var iconLeading = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if iconLeading, let systemImage { icon(systemImage) }
            Text(title)
            if !iconLeading, let systemImage { icon(systemImage) }
        }
        .font(Typography.action)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.screenGutter)
        .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.bold))
            .accessibilityHidden(true)
    }
}

/// Fully rounded buttons. Depth kinds have a thick edge the face sinks into when pressed;
/// flat kinds (`outline`, `danger`) shrink to 97%. Disabled is a flat Ink 100 face.
struct ActionButtonStyle: ButtonStyle {
    enum Kind {
        /// Blue 500 on Blue 700: actions that start practice.
        case practice
        /// Green 600 on Green 800: Continue in a correct-answer panel.
        case success
        /// Coral 600 on Coral 800: Try again in a wrong-answer panel.
        case retry
        /// Ink 800 on Ink 950: the primary action everywhere, practice included.
        case app
        /// White, Ink 200 border and 3 pt Ink 200 edge: secondary practice action.
        case outline3D
        /// White, Ink 200 border, flat.
        case outline
        /// Coral 600, white text, flat.
        case danger
        /// Ink text only: no fill, border or edge.
        case plain
    }

    enum Size { case regular, small }

    var kind: Kind = .app
    var size: Size = .regular
    var shimmers = false
    /// Overrides the label colour (e.g. Coral text on an outline button).
    var foregroundOverride: Color?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule(style: .continuous)
        let pressed = configuration.isPressed && isEnabled
        let depth = isEnabled ? self.depth : 0
        configuration.label
            .foregroundStyle(foreground)
            .background(face, in: shape)
            .overlay {
                if shimmers && isEnabled && !motion.reduceMotion {
                    ShimmerSweep().clipShape(shape)
                }
            }
            .overlay {
                if hasBorder && isEnabled { shape.strokeBorder(Color.stroke, lineWidth: Borders.card) }
            }
            .offset(y: pressed && depth > 0 ? depth : 0)
            .background(shape.fill(depth > 0 ? depthColor : .clear).offset(y: depth))
            .scaleEffect(pressed && self.depth == 0 ? motion.pressedScale : 1)
            .padding(.bottom, self.depth)
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: pressed)
    }

    private var hasBorder: Bool { kind == .outline || kind == .outline3D }

    private var depth: CGFloat {
        switch kind {
        case .practice, .success, .retry, .app: Spacing.buttonDepth
        case .outline3D: Spacing.tileDepth
        case .outline, .danger, .plain: 0
        }
    }

    private var foreground: Color {
        guard isEnabled else { return .disabledInk }
        if let foregroundOverride { return foregroundOverride }
        switch kind {
        case .practice, .success, .retry, .app, .danger: return .white
        case .outline, .outline3D, .plain: return .ink
        }
    }

    private var face: Color {
        if kind == .plain { return .clear }
        guard isEnabled else { return .disabledSurface }
        switch kind {
        case .practice: return .blue500
        case .success: return .green600
        case .retry, .danger: return .coral600
        case .app: return .primaryAction
        case .outline, .outline3D: return .surface
        case .plain: return .clear
        }
    }

    private var depthColor: Color {
        switch kind {
        case .practice: return .interactiveDepth
        case .success: return .successActionDepth
        case .retry: return .errorActionDepth
        case .app: return .primaryDepth
        case .outline3D: return .tileDepth
        case .outline, .danger, .plain: return .clear
        }
    }
}

/// A slanted band of light crossing the button, then a pause. Decorative only.
private struct ShimmerSweep: View {
    /// Horizontal unit-point range that starts and ends with the band fully off the button.
    private static let travel: ClosedRange<Double> = -0.6...1.3
    private static let bandWidth: Double = 0.3

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: MotionTokens.shimmerCycle)
            let progress = min(elapsed / MotionTokens.shimmerSweep, 1)
            let x = Self.travel.lowerBound + progress * (Self.travel.upperBound - Self.travel.lowerBound)
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                startPoint: UnitPoint(x: x, y: 0),
                endPoint: UnitPoint(x: x + Self.bandWidth, y: 1)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PinnedActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, PinnedBarInset.bottom)
            .background(Color.canvas)
    }
}

/// Space under a pinned bottom bar (`PinnedActionBar`, `FeedbackActionPanel`). The home indicator's safe area
/// already leaves room, so only a little is added (the button ends about 38 pt above the screen edge, the
/// design's pb-10); a phone without one (iPhone SE) gets more, or the button would sit on the edge.
@MainActor
enum PinnedBarInset {
    static var bottom: CGFloat {
        let windowInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
        return windowInset > 0 ? Spacing.xxs : Spacing.m
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        PrimaryButton(title: "Check", kind: .practice) {}
        SecondaryButton(title: "I know this word", kind: .outline3D) {}
        PrimaryButton(title: "Continue", kind: .success) {}
        PrimaryButton(title: "Try again", kind: .retry) {}
        PrimaryButton(title: "Save", kind: .app) {}
        SecondaryButton(title: "Log out", kind: .outline) {}
        DestructiveButton(title: "Delete account") {}
        PrimaryButton(title: "Check", isEnabled: false) {}
        SmallButton(title: "Add word", systemImage: "plus") {}
    }
    .padding()
}
