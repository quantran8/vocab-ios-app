import SwiftUI

/// Pushed from My Words' Random Practice tile. Nothing is planned until Start.
struct RandomPracticeView: View {
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    /// All four is the mixed practice. Empty can't start.
    @State private var skills = Set(PracticeSkill.allCases)
    @State private var source: WordSource = .all
    @State private var showsSourceSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PunctuatedTitle(text: "Choose skills")

                sectionHeader("Skills") {
                    SelectAllButton(allSelected: skills.count == PracticeSkill.allCases.count, action: toggleAllSkills)
                }
                .padding(.top, Spacing.l)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)],
                          spacing: Spacing.s) {
                    ForEach(PracticeSkill.allCases) { skill in
                        SkillCard(skill: skill, isSelected: skills.contains(skill)) { toggle(skill) }
                    }
                }

                sectionHeader("Word source") { EmptyView() }
                    .padding(.top, Spacing.xl)
                SourceButton(entry: WordSourceEntry.entry(for: source, in: sourceCollections), detail: sourceDetail) {
                    showsSourceSheet = true
                    settings.feedback.selectionChanged()
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(title: "Start", requirement: startRequirement, isEnabled: startRequirement == nil, action: start)
            }
        }
        .sheet(isPresented: $showsSourceSheet) {
            WordSourceSheet(collections: sourceCollections, source: $source)
        }
    }

    private func sectionHeader<Trailing: View>(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            PlanSectionTitle(text: title)
            Spacer(minLength: Spacing.xs)
            trailing()
        }
        .frame(minHeight: Spacing.minTouchTarget)
        .padding(.bottom, Spacing.xs)
    }

    /// Collections the learner has learned from.
    private var sourceCollections: [VocabCollection] {
        TopicCatalog.collections.filter { ($0.learned ?? 0) > 0 }
    }

    /// Under the source name: the collection's word count, or how many topics are picked once the
    /// learner narrowed it.
    private var sourceDetail: LocalizedStringKey? {
        guard case .collection(let id, let topics) = source,
              let collection = sourceCollections.first(where: { $0.id == id }) else { return nil }
        if topics.count < collection.learnedTopics.count { return "\(topics.count) topics selected" }
        return "\(collection.learned ?? 0) words learned"
    }

    /// Why Start is off, or nil when it can start.
    private var startRequirement: LocalizedStringKey? {
        if skills.isEmpty { return "Choose at least one skill" }
        if case .collection(_, let topics) = source, topics.isEmpty { return "Choose at least one topic" }
        return nil
    }

    private func toggle(_ skill: PracticeSkill) {
        motion.perform(MotionTokens.snap) {
            if skills.contains(skill) { skills.remove(skill) } else { skills.insert(skill) }
        }
        settings.feedback.selectionChanged()
    }

    private func toggleAllSkills() {
        motion.perform(MotionTokens.snap) {
            skills = skills.count == PracticeSkill.allCases.count ? [] : Set(PracticeSkill.allCases)
        }
        settings.feedback.selectionChanged()
    }

    private func start() {
        guard startRequirement == nil else { return }
        // Every skill is the mixed practice, which the backend plans when no skills are sent.
        // Wire order follows the enum so the same choice always sends the same request.
        let chosen = skills.count == PracticeSkill.allCases.count ? [] : PracticeSkill.allCases.filter(skills.contains)
        let filter = source.filter(in: sourceCollections)
        Task { await practice.startPractice(chosen, filter: filter) }
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

    static let all = WordSourceEntry(id: "all", title: "All learned words", detail: nil,
                                     systemImage: "square.stack.3d.up", collection: nil)
    static let custom = WordSourceEntry(id: "custom", title: "Words you added", detail: nil,
                                        systemImage: "plus.bubble", collection: nil)

    static func list(_ collections: [VocabCollection]) -> [WordSourceEntry] {
        [.all] + collections.map(collection) + [.custom]
    }

    static func collection(_ collection: VocabCollection) -> WordSourceEntry {
        WordSourceEntry(id: "collection-\(collection.id)", title: LocalizedStringKey(collection.name),
                        detail: "\(collection.learned ?? 0) words learned",
                        systemImage: collection.systemImage, collection: collection)
    }

    static func entry(for source: WordSource, in collections: [VocabCollection]) -> WordSourceEntry {
        switch source {
        case .all: .all
        case .custom: .custom
        case .collection(let id, _): collections.first { $0.id == id }.map(collection) ?? .all
        }
    }

    func matches(_ source: WordSource) -> Bool {
        switch source {
        case .all: id == Self.all.id
        case .custom: id == Self.custom.id
        case .collection(let chosen, _): collection?.id == chosen
        }
    }
}

/// Bottom sheet listing every word source. Picking a collection keeps it open to narrow its topics;
/// any other source closes it.
private struct WordSourceSheet: View {
    let collections: [VocabCollection]
    @Binding var source: WordSource
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.motion) private var motion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    PunctuatedTitle(text: "Word source", font: Typography.screenTitle)
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }

                VStack(spacing: Spacing.s) {
                    ForEach(WordSourceEntry.list(collections)) { entry in
                        let selected = entry.matches(source)
                        SourceOptionRow(entry: entry, isSelected: selected) { pick(entry) }
                        if selected, let collection = entry.collection, case .collection(_, let topics) = source {
                            topicSection(collection, picked: topics)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    private func topicSection(_ collection: VocabCollection, picked: Set<String>) -> some View {
        let topics = collection.learnedTopics
        let allPicked = topics.allSatisfy { picked.contains($0.id) }
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Topics")
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.xs)
                SelectAllButton(allSelected: allPicked) {
                    setTopics(collection, allPicked ? [] : Set(topics.map(\.id)))
                }
            }
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(topics) { topic in
                    TopicChip(
                        title: topic.name,
                        systemImage: topic.systemImage,
                        isSelected: picked.contains(topic.id),
                        progress: (learned: topic.learned ?? 0, total: topic.total ?? 0)
                    ) {
                        var next = picked
                        if next.contains(topic.id) { next.remove(topic.id) } else { next.insert(topic.id) }
                        setTopics(collection, next)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.bottom, Spacing.xs)
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
            source = entry.id == WordSourceEntry.custom.id ? .custom : .all
            dismiss()
        }
    }

    private func setTopics(_ collection: VocabCollection, _ topics: Set<String>) {
        motion.perform(MotionTokens.snap) { source = .collection(id: collection.id, topics: topics) }
        settings.feedback.selectionChanged()
    }
}

/// "Select all" / "Deselect all", for the skills grid and a collection's topics.
private struct SelectAllButton: View {
    let allSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(allSelected ? "Deselect all" : "Select all")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.selectedInk)
                .padding(.horizontal, Spacing.xs)
                .frame(minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct SkillCard: View {
    let skill: PracticeSkill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.ink)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? Color.interactive : Color.neutralSurface,
                        in: RoundedRectangle(cornerRadius: Radii.tile - 3, style: .continuous)
                    )
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.emphasis)
                    .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                SelectionTick(isSelected: isSelected, size: 19)
            }
            .padding(.horizontal, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var title: LocalizedStringKey {
        switch skill {
        case .reading: "Reading"
        case .writing: "Writing"
        case .listening: "Listening"
        case .speaking: "Speaking"
        }
    }

    private var systemImage: String {
        switch skill {
        case .reading: "book"
        case .writing: "pencil"
        case .listening: "headphones"
        case .speaking: "mic"
        }
    }
}

/// The chosen word source on the main screen; opens the sheet.
private struct SourceButton: View {
    let entry: WordSourceEntry
    let detail: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                SourceIcon(systemImage: entry.systemImage, isSelected: false)
                SourceText(title: entry.title, detail: detail, isSelected: false)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.interactive)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.s)
            .background(Color.surface, in: shape)
            .overlay(shape.strokeBorder(Color.stroke, lineWidth: Borders.card))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows the other word sources"))
    }
}

private struct SourceOptionRow: View {
    let entry: WordSourceEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card - 2, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                SourceIcon(systemImage: entry.systemImage, isSelected: isSelected)
                SourceText(title: entry.title, detail: entry.detail, isSelected: isSelected)
                Spacer(minLength: 0)
                SelectionTick(isSelected: isSelected, size: 22)
            }
            .padding(Spacing.s)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SourceIcon: View {
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Color.ink)
            .frame(width: 46, height: 46)
            .background(
                isSelected ? Color.interactive : Color.neutralSurface,
                in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

private struct SourceText: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs - 2) {
            Text(title)
                .font(Typography.emphasis)
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
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

/// Filled blue circle with a check when selected, an empty ring otherwise.
private struct SelectionTick: View {
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(isSelected ? Color.interactive : Color.stroke)
            .accessibilityHidden(true)
    }
}
