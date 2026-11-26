import SwiftUI

/// Pushed from My Words' Random Practice tile: pick the words to practise from, right on the screen. Nothing is
/// planned until Start.
struct RandomPracticeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @State private var source: WordSource = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Random Practice")

                SectionTitle("Word source")
                    .padding(.top, Spacing.xl)
                WordSourceList(collections: sourceCollections, source: $source)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xxs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Start", requirement: startRequirement, isEnabled: startRequirement == nil, action: start)
            }
        }
    }

    /// Collections the learner has learned from.
    private var sourceCollections: [VocabCollection] {
        TopicCatalog.collections.filter { ($0.learned ?? 0) > 0 }
    }

    /// Why Start is off, or nil when it can start.
    private var startRequirement: LocalizedStringKey? {
        if case .collection(_, let topics) = source, topics.isEmpty { return "Choose at least one topic" }
        return nil
    }

    private func start() {
        guard startRequirement == nil else { return }
        let filter = source.filter(in: sourceCollections)
        Task { await practice.startPractice(filter: filter) }
    }
}

/// The learner's word source. A collection keeps the topics picked inside it; all of its learned
/// topics is the whole collection.
enum WordSource: Equatable {
    case all
    case collection(id: String, topics: Set<String>)
    case custom

    func filter(in collections: [VocabCollection]) -> PracticeFilter? {
        switch self {
        case .all:
            return nil
        case .custom:
            return .customWords
        case .collection(let id, let topics):
            guard let collection = collections.first(where: { $0.id == id }) else { return .collection(id) }
            let learned = collection.learnedTopics.map(\.id)
            if Set(learned).isSubset(of: topics) { return .collection(id) }
            // Catalog order, so the same choice always sends the same request.
            return .topics(learned.filter(topics.contains))
        }
    }
}

extension VocabCollection {
    /// Topics with at least one learned word: the only ones practice can draw from.
    var learnedTopics: [Topic] { topics.filter { ($0.learned ?? 0) > 0 } }
}

private struct WordSourceEntry: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let systemImage: String
    let collection: VocabCollection?
    /// The collection's mark colour, shown as a dot instead of the icon.
    var mark: Color?

    static let all = WordSourceEntry(id: "all", title: "All learned words", detail: nil,
                                     systemImage: "square.stack", collection: nil)
    static let custom = WordSourceEntry(id: "custom", title: "Words you added", detail: nil,
                                        systemImage: "plus.bubble", collection: nil, mark: CollectionMarkColor.custom)

    static func list(_ collections: [VocabCollection]) -> [WordSourceEntry] {
        [.all] + collections.map(collection) + [.custom]
    }

    static func collection(_ collection: VocabCollection) -> WordSourceEntry {
        WordSourceEntry(id: "collection-\(collection.id)", title: LocalizedStringKey(collection.name),
                        detail: "\(collection.learned ?? 0) words learned",
                        systemImage: collection.systemImage, collection: collection,
                        mark: CollectionMarkColor.color(for: collection))
    }

    func matches(_ source: WordSource) -> Bool {
        switch source {
        case .all: id == Self.all.id
        case .custom: id == Self.custom.id
        case .collection(let chosen, _): collection?.id == chosen
        }
    }
}

/// Every word source in one card. Picking a collection unfolds its topics right under that row, inside the
/// same card.
private struct WordSourceList: View {
    let collections: [VocabCollection]
    @Binding var source: WordSource
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion

    var body: some View {
        let entries = WordSourceEntry.list(collections)
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { CardDivider() }
                SourceOptionRow(entry: entry, isSelected: entry.matches(source)) { pick(entry) }
                if case .collection(let id, let topics) = source,
                   let collection = entry.collection, collection.id == id {
                    topicSection(collection, picked: topics)
                        .transition(.opacity)
                }
            }
        }
        .cardSurface()
    }

    private func topicSection(_ collection: VocabCollection, picked: Set<String>) -> some View {
        let topics = collection.learnedTopics
        let allPicked = topics.allSatisfy { picked.contains($0.id) }
        let pickedCount = topics.filter { picked.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Topics · \(pickedCount)/\(topics.count)")
                Spacer(minLength: Spacing.s)
                SelectAllButton(allSelected: allPicked) {
                    setTopics(collection, allPicked ? [] : Set(topics.map(\.id)))
                }
            }
            .staticLabelRow()
            .padding(.top, Spacing.xxs)
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(topics) { topic in
                    TopicChip(
                        title: topic.name,
                        systemImage: topic.systemImage,
                        isSelected: picked.contains(topic.id),
                        selectedFill: .surface
                    ) {
                        var next = picked
                        if next.contains(topic.id) { next.remove(topic.id) } else { next.insert(topic.id) }
                        setTopics(collection, next)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.m)
        .background(Color.blue50.opacity(0.6))
    }

    private func pick(_ entry: WordSourceEntry) {
        settings.feedback.selectionChanged()
        if let collection = entry.collection {
            // A new collection starts with every topic; tapping the chosen one keeps its topics.
            guard !entry.matches(source) else { return }
            motion.perform(MotionTokens.snap) {
                source = .collection(id: collection.id, topics: Set(collection.learnedTopics.map(\.id)))
            }
        } else {
            motion.perform(MotionTokens.snap) {
                source = entry.id == WordSourceEntry.custom.id ? .custom : .all
            }
        }
    }

    private func setTopics(_ collection: VocabCollection, _ topics: Set<String>) {
        motion.perform(MotionTokens.snap) { source = .collection(id: collection.id, topics: topics) }
        settings.feedback.selectionChanged()
    }
}

/// "Select all" / "Deselect all", for a collection's topics.
private struct SelectAllButton: View {
    let allSelected: Bool
    let action: () -> Void

    var body: some View {
        TextLink(title: allSelected ? "Deselect all" : "Select all", action: action)
    }
}

/// One row of the source card: the collection's mark dot (or the stack icon for every word), then a round check.
private struct SourceOptionRow: View {
    let entry: WordSourceEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Group {
                    if let mark = entry.mark {
                        CollectionMarkDot(color: mark)
                    } else {
                        Image(systemName: entry.systemImage)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.ink700)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: Spacing.screenGutter)
                SourceText(title: entry.title, detail: entry.detail)
                Spacer(minLength: 0)
                SelectionMark(isOn: isSelected)
            }
            .padding(Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SourceText: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
            Text(title)
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            if let detail {
                Text(detail)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
