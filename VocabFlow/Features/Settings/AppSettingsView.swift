import SwiftUI

struct AppSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(TemplateSandboxStore.self) private var sandbox
    @Environment(AuthStore.self) private var auth
    @Environment(LearnerStore.self) private var learner
    @Environment(RankingStore.self) private var ranking
    @Environment(\.motion) private var motion
    @State private var isConfirmingDeletion = false
    @State private var isChoosingLanguage = false
    @State private var pickedLanguage: AppLanguage?
    @State private var isPreviewingSyllie = false
    @State private var isChangingPassword = false
    @State private var leaderboardError: String?

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenTitle("Settings")
                        .padding(.top, Spacing.xs)

                    group("Interaction") {
                        toggleRow(systemImage: "hand.tap", title: "Haptics", isOn: $settings.hapticsEnabled)
                        CardDivider()
                        toggleRow(systemImage: "figure.walk.motion", title: "Reduce motion", isOn: $settings.reduceMotion)
                    }

                    if let visible = learner.profile?.settings.leaderboardVisible {
                        group("Leaderboard") {
                            toggleRow(
                                systemImage: "trophy",
                                title: "Show me on the leaderboard",
                                subtitle: "Your name, avatar, Tier and LP this week become public",
                                isOn: Binding(get: { visible }, set: setLeaderboardVisible)
                            )
                        }
                        if let leaderboardError {
                            Text(verbatim: leaderboardError)
                                .font(Typography.micro)
                                .foregroundStyle(Color.errorInk)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, Spacing.xs)
                        }
                    }

                    group("App") {
                        Button {
                            isChoosingLanguage = true
                        } label: {
                            SettingRow(systemImage: "globe", title: "Language") {
                                chevron(Text(verbatim: settings.language.nativeName))
                            }
                        }
                        .buttonStyle(.plain)
                        CardDivider()
                        Button {
                            motion.perform(MotionTokens.transition) { sandbox.openLab() }
                        } label: {
                            SettingRow(systemImage: "flask", title: "Practice Lab") {
                                chevron(nil)
                            }
                        }
                        .buttonStyle(.plain)
                        CardDivider()
                        // Belongs in the Practice Lab (redesign 4.3); stays here until the Lab hosts it.
                        Button {
                            isPreviewingSyllie = true
                        } label: {
                            SettingRow(systemImage: "play.circle", title: "Syllie animations") {
                                chevron(nil)
                            }
                        }
                        .buttonStyle(.plain)
                        CardDivider()
                        SettingRow(systemImage: "info.circle", title: "About Syll") {
                            Text(verbatim: "v\(appVersion)")
                                .font(Typography.secondary)
                                .foregroundStyle(Color.mutedInk)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    group("Account") {
                        Button {
                            isChangingPassword = true
                        } label: {
                            SettingRow(systemImage: "key", title: "Change password") {
                                chevron(nil)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: Spacing.screenGutter) {
                        SecondaryButton(title: "Log out") {
                            Task { await auth.signOut() }
                        }
                        HStack(spacing: Spacing.xs) {
                            TextLink(title: "Delete account", color: .destructiveInk) {
                                isConfirmingDeletion = true
                            }
                            .accessibilityValue(auth.isDeletingAccount ? Text("Deleting your account") : Text(verbatim: ""))
                            if auth.isDeletingAccount {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, -Spacing.s)
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(auth.isDeletingAccount)
                    .padding(.top, Spacing.xl)

                    if let error = auth.accountDeletionError {
                        Text(verbatim: error)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.errorInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.m)
                    }
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.bottom, Spacing.l)
            }
        }
        .background(Color.canvas)
        .sheet(isPresented: $isChoosingLanguage, onDismiss: applyPickedLanguage) {
            LanguageSheet(selected: settings.language) { language in
                pickedLanguage = language
                isChoosingLanguage = false
            }
        }
        .sheet(isPresented: $isPreviewingSyllie) {
            SylliePreviewView()
        }
        .sheet(isPresented: $isChangingPassword) {
            ChangePasswordSheet()
        }
        .sheet(isPresented: $isConfirmingDeletion) {
            ConfirmSheet(
                style: .destructive(systemImage: "trash"),
                title: "Delete your account?",
                message: "Your progress, words and settings will be permanently deleted. This can’t be undone.",
                cancelTitle: "Cancel",
                confirmTitle: "Delete account",
                isWorking: auth.isDeletingAccount
            ) {
                Task {
                    await auth.deleteAccount()
                    isConfirmingDeletion = false
                }
            }
            .interactiveDismissDisabled(auth.isDeletingAccount)
        }
    }

    /// The task isn't tied to this view: changing the language rebuilds the screen.
    private func applyPickedLanguage() {
        guard let pickedLanguage, pickedLanguage != settings.language else { return }
        settings.chooseLanguage(pickedLanguage)
        Task { await learner.languageDidChange() }
    }

    private func setLeaderboardVisible(_ visible: Bool) {
        Task {
            do {
                try await ranking.setVisible(visible)
                leaderboardError = nil
            } catch {
                leaderboardError = error.asAPIError.userMessage
            }
        }
    }

    /// An eyebrow header above one card of rows.
    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s - 2) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content()
            }
            .cardSurface()
        }
        .padding(.top, Spacing.l + Spacing.xxs)
    }

    private func toggleRow(systemImage: String, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
                           isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            SettingLabel(systemImage: systemImage, title: title, subtitle: subtitle)
        }
        .tint(Color.interactive)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.rowMinHeight)
    }

    /// A value (optional) and a chevron, trailing a row that opens something.
    private func chevron(_ value: Text?) -> some View {
        HStack(spacing: Spacing.xs - 2) {
            if let value {
                value
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            }
            Image(systemName: "chevron.right")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(Color.ink400)
                .accessibilityHidden(true)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

/// Icon, title (and a subtitle only where it adds meaning), trailing control.
private struct SettingLabel: View {
    let systemImage: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Color.ink700)
                .frame(width: Spacing.screenGutter + Spacing.xxs)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SettingRow<Trailing: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.s) {
            SettingLabel(systemImage: systemImage, title: title, subtitle: subtitle)
            Spacer(minLength: Spacing.xs)
            trailing
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}
