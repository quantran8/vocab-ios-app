import SwiftUI

/// Sheet editing the collection and its topics; the routine is untouched. Dismissing discards the draft.
struct EditFocusView: View {
    let onSave: (LearningPreferences) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @Environment(LearnerStore.self) private var learner
    @State private var draft: LearningPreferences
    @State private var paywallReason: PaywallReason?
    private let initial: LearningPreferences

    init(initial: LearningPreferences, onSave: @escaping (LearningPreferences) -> Void) {
        self.onSave = onSave
        self.initial = initial
        _draft = State(initialValue: initial)
    }

    /// Topics the draft drops that the learner has learned from: their words stay in review.
    private var droppedLearnedTopics: [Topic] {
        TopicCatalog.topics(ids: initial.topicIDs.subtracting(draft.topicIDs)).filter { ($0.learned ?? 0) > 0 }
    }

    /// Names at most `namedDropLimit` dropped topics; beyond that the list would swamp the pinned bar.
    private static let namedDropLimit = 2

    @ViewBuilder
    private var droppedTopicsNote: some View {
        let dropped = droppedLearnedTopics
        if !dropped.isEmpty {
            Group {
                if dropped.count <= Self.namedDropLimit {
                    let names = dropped.map(\.name).formatted(.list(type: .and).locale(AppLanguage.active.locale))
                    Text("Words you learned in \(names) will still come back for review so you don’t forget them. They’ll show up less often as you remember them better.")
                } else {
                    Text("Words you learned in the topics you removed will still come back for review so you don’t forget them. They’ll show up less often as you remember them better.")
                }
            }
            .font(Typography.micro)
            .foregroundStyle(Color.mutedInk)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                SheetTitle("Your focus")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        PlanSectionTitle(text: "Collection")
                        collectionChips
                    }
                    if let collection = draft.collection {
                        TopicPicker(
                            collection: collection,
                            selectedIDs: draft.topicIDs,
                            onToggleTopic: { id in
                                if draft.toggleTopic(id, limit: learner.maxTopics) {
                                    settings.feedback.selectionChanged()
                                } else if let max = learner.maxTopics {
                                    paywallReason = .topics(max: max)
                                }
                            },
                            onToggleAll: {
                                draft.toggleAllTopics(limit: learner.maxTopics)
                                settings.feedback.selectionChanged()
                            },
                            maxTopics: learner.maxTopics
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                VStack(spacing: Spacing.s) {
                    droppedTopicsNote
                    if let max = learner.maxTopics, draft.topicIDs.count > max {
                        // A scope kept from Premium: it can stay, but saving needs it within the free limit.
                        Text("The free plan includes \(max) topics. Remove some to save, or upgrade to keep them all.")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.errorInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        TextLink(title: "Get Premium", color: .grape600, systemImage: "crown") { paywallReason = .topics(max: max) }
                            .padding(.vertical, -Spacing.s)
                    } else if !draft.topicIDs.isEmpty {
                        Text("\(draft.topicIDs.count) topics selected")
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(Color.mutedInk)
                            .contentTransition(.numericText())
                    }
                    PrimaryButton(
                        title: "Save changes",
                        requirement: "Choose at least one topic",
                        isEnabled: draft.isComplete && withinTopicLimit
                    ) {
                        settings.feedback.success()
                        onSave(draft)
                    }
                }
            }
        }
        .sheet(item: $paywallReason) { reason in
            PaywallView(reason: reason)
        }
    }

    private var withinTopicLimit: Bool {
        learner.maxTopics.map { draft.topicIDs.count <= $0 } ?? true
    }

    /// Switching collection clears the topics, since each collection has its own.
    /// A free learner stays on the saved collection: the others are dimmed and offer Premium.
    private var collectionChips: some View {
        let locked = learner.lockedCollectionID(saved: initial.collectionID)
        return FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
            ForEach(TopicCatalog.collections) { collection in
                let isLocked = locked.map { $0 != collection.id } ?? false
                TopicChip(
                    title: collection.name,
                    isSelected: collection.id == draft.collectionID,
                    mark: CollectionMarkColor.color(for: collection),
                    isLocked: isLocked
                ) {
                    guard !isLocked else {
                        paywallReason = .collection
                        return
                    }
                    guard collection.id != draft.collectionID else { return }
                    draft.selectCollection(collection.id)
                    settings.feedback.selectionChanged()
                }
            }
        }
    }
}
