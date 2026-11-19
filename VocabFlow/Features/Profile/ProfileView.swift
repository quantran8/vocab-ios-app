import SwiftUI

struct ProfileView: View {
    let onEditLevel: () -> Void
    let onEditFocus: () -> Void
    let onEditRoutine: () -> Void
    let onOpenSettings: () -> Void
    @Environment(LearningPlanStore.self) private var plan
    @Environment(LearnerStore.self) private var learner
    @Environment(RankingStore.self) private var ranking
    @State private var saveError: String?
    @State private var isEditingPublicProfile = false

    var body: some View {
        let preferences = plan.current

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    ScreenTitle("Profile")
                    Spacer(minLength: Spacing.s)
                    Button(action: onOpenSettings) {
                        SystemBarButtonLabel(systemImage: "gearshape")
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(Text("Settings"))
                }

                identity
                    .padding(.top, Spacing.l)

                if let card = tierCard {
                    ProfileTierCard(summary: card.summary, next: card.next)
                        .padding(.top, Spacing.screenGutter)
                }

                levelSection
                    .padding(.top, Spacing.xl + Spacing.xxs)

                focusSection(preferences)
                    .padding(.top, Spacing.xl)

                routineSection(preferences)
                    .padding(.top, Spacing.xl)

                reviewSection(preferences)
                    .padding(.top, Spacing.xl)

                if let saveError {
                    Text(verbatim: saveError)
                        .font(Typography.micro)
                        .foregroundStyle(Color.errorInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        // `GET /me` reloads after every session; the next Tier comes from `GET /me/tier`, so it reloads with it.
        .task(id: learner.profile?.tierSummary) {
            guard learner.profile?.tierSummary != nil else { return }
            await ranking.refreshTier()
        }
        .sheet(isPresented: $isEditingPublicProfile) {
            EditPublicProfileSheet()
        }
    }

    /// LP and the next Tier from one answer. LP never goes down, so whichever answer has more is the newer one.
    /// Until `refreshTier` catches up, the older answer's next Tier is kept only if it is still ahead.
    private var tierCard: (summary: TierSummary, next: NextTier?)? {
        let profileSummary = learner.profile?.tierSummary
        if let detail = ranking.tier, detail.lifetimeLP >= (profileSummary?.lifetimeLP ?? 0) {
            return (detail.summary, detail.nextTier)
        }
        guard let profileSummary else { return nil }
        let next = ranking.tier?.nextTier.flatMap { next in
            next.level > profileSummary.level ? next : nil
        }
        return (profileSummary, next)
    }

    @ViewBuilder
    private var identity: some View {
        if let username = learner.profile?.username {
            HStack(spacing: Spacing.m) {
                AvatarView(key: learner.profile?.avatarKey ?? "", size: Self.avatarSize, cornerRadius: Radii.card, initial: username)
                nameText(Text(verbatim: username))
                Spacer(minLength: Spacing.s)
                editLink("Edit name and avatar") { isEditingPublicProfile = true }
            }
        } else {
            placeholderIdentity
        }
    }

    /// 64 pt avatar (w-16).
    private static let avatarSize = Spacing.xl * 2

    private var placeholderIdentity: some View {
        let name = String(localized: "Learner", bundle: .appLanguage)
        return HStack(spacing: Spacing.m) {
            AvatarView(key: "", size: Self.avatarSize, cornerRadius: Radii.card, initial: name)
            nameText(Text(verbatim: name))
        }
    }

    private func nameText(_ text: Text) -> some View {
        text
            .font(.system(.title3, weight: .heavy))
            .tracking(Typography.tightTracking)
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your level") { editLink("Edit level", action: onEditLevel) }
            card {
                dataRow("English level", value: learner.profile?.proficiencyLevel.map { Text(verbatim: $0.rawValue) } ?? Text("Not set"))
            }
        }
    }

    /// Topics shown before collapsing the rest into "+N more".
    private static let visibleTopicLimit = 3

    private func focusSection(_ preferences: LearningPreferences) -> some View {
        let topics = TopicCatalog.topics(ids: preferences.topicIDs)
        let hidden = max(0, topics.count - Self.visibleTopicLimit)
        return VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your focus") { editLink("Edit focus", action: onEditFocus) }
            if let collection = preferences.collection {
                HStack(spacing: Spacing.xs) {
                    CollectionMarkDot(color: CollectionMarkColor.color(for: collection), size: Spacing.xs)
                    Text(verbatim: collection.name)
                        .font(Typography.secondary.weight(.semibold))
                        .foregroundStyle(Color.bodyInk)
                }
                .padding(.bottom, Spacing.s)
            }
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(topics.prefix(Self.visibleTopicLimit)) { topic in
                    HStack(spacing: Spacing.xs - 2) {
                        Image(systemName: topic.systemImage)
                            .font(Typography.micro.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(verbatim: topic.name)
                            .font(Typography.secondary.weight(.semibold))
                            .lineLimit(1)
                    }
                    .chipSurface(isSelected: false)
                }
                if hidden > 0 {
                    Button(action: onEditFocus) {
                        Text("+\(hidden) more")
                            .font(Typography.secondary.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, Spacing.s + 2)
                            .frame(minHeight: Spacing.buttonSmallHeight)
                            .background(Color.neutralSurface, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityHint(Text("Shows all topics"))
                }
            }
        }
    }

    private func routineSection(_ preferences: LearningPreferences) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your routine") { editLink("Edit routine", action: onEditRoutine) }
            card {
                dataRow("New words / day", value: Text("\(preferences.wordsPerDay) words"))
                CardDivider()
                dataRow("Reviews / session", value: Text("\(preferences.effectiveReviewsPerSession) words"))
                CardDivider()
                dataRow("Learning days", value: Text(verbatim: daysSummary(preferences)))
                CardDivider()
                dataRow("Reminder", value: preferences.reminderEnabled
                    ? Text(preferences.reminderDate, format: .dateTime.hour().minute())
                    : Text("Off"))
                CardDivider()
                toggleRow(label: "Speaking practice",
                          info: "Read words aloud in your lessons. Right or wrong, it never changes your progress.",
                          infoLabel: "About speaking practice",
                          isOn: preferences.dailySpeaking) { enabled in
                    try await learner.setDailySpeaking(enabled)
                }
                CardDivider()
                toggleRow(label: "Balance reviews and new words",
                          info: "Fewer new words while many words wait for review",
                          infoLabel: "About balancing reviews and new words",
                          isOn: learner.home?.reviewLoad?.autoBalance ?? learner.profile?.settings.autoBalanceNewWords ?? false) { enabled in
                    try await learner.setAutoBalance(enabled)
                }
                if let override = learner.home?.reviewLoad?.override {
                    CardDivider()
                    overrideRow(override)
                }
            }
        }
    }

    /// Collections the learner has learned from. The active one is always reviewed.
    private func reviewSection(_ preferences: LearningPreferences) -> some View {
        let collections = TopicCatalog.collections.filter { ($0.learned ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Review")
            if collections.isEmpty {
                Text("Collections you learn from will show up here.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
            } else {
                card {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        if index > 0 { CardDivider() }
                        reviewRow(collection, isActive: collection.id == preferences.collectionID)
                    }
                }
            }
        }
    }

    private func reviewRow(_ collection: VocabCollection, isActive: Bool) -> some View {
        let isReviewed = isActive || !learner.isReviewPaused(collectionID: collection.id)
        return Toggle(isOn: Binding(
            get: { isReviewed },
            set: { reviewed in save { try await learner.setReviewPaused(!reviewed, collectionID: collection.id) } }
        )) {
            HStack(spacing: Spacing.s) {
                CollectionMarkDot(color: CollectionMarkColor.color(for: collection), size: Spacing.s - 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: collection.name)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(isActive
                         ? "\(collection.learned ?? 0) words · Your current collection is always reviewed"
                         : "\(collection.learned ?? 0) words learned")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .disabled(isActive)
        .accessibilityHint(Text("Review this collection’s words"))
        .modifier(RowPadding())
    }

    /// Label and ⓘ (the explanation is in its popover, not a subtitle), then the system switch, saved at once.
    /// The switch keeps the label for VoiceOver; ⓘ is its own element.
    private func toggleRow(label: LocalizedStringKey, info: LocalizedStringKey, infoLabel: LocalizedStringKey, isOn: Bool,
                           onChange: @escaping (Bool) async throws -> Void) -> some View {
        HStack(spacing: Spacing.xxs) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            InfoPopoverButton(text: info, accessibilityLabel: infoLabel)
            Spacer(minLength: Spacing.s)
            Toggle(isOn: Binding(get: { isOn }, set: { value in save { try await onChange(value) } })) {
                Text(label)
            }
            .labelsHidden()
        }
        .modifier(RowPadding())
    }

    private func overrideRow(_ override: NewWordOverride) -> some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lowered to \(override.value) new words")
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
                Group {
                    if override.mode == .untilDate, let until = override.until {
                        Text("Until \(until.formatted(.dateTime.weekday(.wide).hour().minute().locale(AppLanguage.active.locale)))")
                    } else {
                        Text("Until 10 or fewer words are waiting")
                    }
                }
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.s)
            TextLink(title: "Cancel") {
                save { try await learner.clearNewWordOverride() }
            }
            .accessibilityLabel(Text("Cancel lowered new words"))
        }
        .modifier(RowPadding())
    }

    private func save(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
                saveError = nil
            } catch {
                saveError = error.asAPIError.userMessage
            }
        }
    }

    /// "Edit" text link beside a section title; the VoiceOver label names what it edits.
    private func editLink(_ accessibilityName: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        TextLink(title: "Edit", action: action)
            .accessibilityLabel(Text(accessibilityName))
            // Keeps the 44 pt target without pushing the section title away from its card.
            .padding(.vertical, -Spacing.s)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .cardSurface()
    }

    /// A data row: label, then the value in bold. No icon (redesign 4.1).
    private func dataRow(_ label: LocalizedStringKey, value: Text) -> some View {
        CardRow {
            Text(label)
            Spacer(minLength: Spacing.s)
            value
                .fontWeight(.bold)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func daysSummary(_ preferences: LearningPreferences) -> String {
        if preferences.isEveryDay { return String(localized: "Every day", bundle: .appLanguage) }
        return Weekday.ordered
            .filter { preferences.learningDays.contains($0.id) }
            .map(\.short)
            .formatted(.list(type: .and, width: .narrow).locale(AppLanguage.active.locale))
    }
}

/// A card row's padding: 16 pt sides, 12 pt top and bottom, 56 pt minimum.
private struct RowPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
    }
}
