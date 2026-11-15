import SwiftUI

/// A short bottom sheet sized to its content (system `.sheet` + a fixed-height detent).
/// Used instead of `.alert` / popups whenever the buttons should follow the design system.
struct FittedSheet<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var height: CGFloat = 320

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radii.sheet)
            .presentationBackground(Color.canvas)
    }
}

/// Destructive / leave confirmation: icon, title, message, then Cancel and Confirm side by side
/// (or stacked, practice style). Cancel is always visible.
struct ConfirmSheet: View {
    enum Style {
        /// Coral trash icon, Cancel + Delete side by side (flat).
        case destructive(systemImage: String)
        /// Syllie on top, stacked Ink "keep going" + outline "leave" (practice).
        case leavePractice
    }

    let style: Style
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let cancelTitle: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    var isWorking = false
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FittedSheet {
            switch style {
            case .destructive(let systemImage):
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.coral600)
                        .frame(width: 48, height: 48)
                        .background(Color.coral50, in: Circle())
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Typography.screenTitle.weight(.heavy))
                        .tracking(Typography.tightTracking)
                        .foregroundStyle(Color.ink)
                        .padding(.top, Spacing.m)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.bodyInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xs)
                    HStack(spacing: Spacing.s) {
                        SecondaryButton(title: cancelTitle, kind: .outline) { dismiss() }
                        DestructiveButton(title: confirmTitle, isLoading: isWorking, action: onConfirm)
                    }
                    .padding(.top, Spacing.l)
                }
                .padding(.horizontal, Spacing.practiceGutter)
                .padding(.top, Spacing.l + Spacing.xs)
                .padding(.bottom, Spacing.m)
            case .leavePractice:
                VStack(spacing: 0) {
                    SyllieView(mood: .oops)
                        .frame(width: 96, height: 80)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Typography.screenTitle.weight(.heavy))
                        .tracking(Typography.tightTracking)
                        .foregroundStyle(Color.ink)
                        .padding(.top, Spacing.s)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.bodyInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xs)
                    VStack(spacing: Spacing.s) {
                        PrimaryButton(title: cancelTitle, kind: .app) { dismiss() }
                        Button(action: onConfirm) {
                            ActionButtonLabel(title: confirmTitle)
                        }
                        .buttonStyle(ActionButtonStyle(kind: .outline3D, foregroundOverride: .destructiveInk))
                    }
                    .padding(.top, Spacing.l)
                }
                .padding(.horizontal, Spacing.practiceGutter)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}
