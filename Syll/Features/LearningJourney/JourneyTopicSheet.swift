import SwiftUI

/// One topic's new words in the period (docs/app-redesign-v1.html, 7.3), opened from a topic row of the journey.
/// A glossary: a fixed word column and the meanings learned in the period as running text, at most two lines, so a
/// word with five meanings keeps the row's shape. A tap opens the word. Pages of `LearningJourneyStore.wordPage`,
/// the next one asked for near the end; a failed page keeps the loaded rows.
struct JourneyTopicSheet: View {
    let period: JourneyPeriod
    let topic: TopicNewWords
    @Environment(LearningJourneyStore.self) private var journey
    @State private var openWord: JourneyWord?

    /// Rows from the end at which the next page is asked for.
    private static let prefetchDistance = 5

    private var key: LearningJourneyStore.TopicWordsKey { .init(period: period, topic: topic.key) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                list
                    .padding(.top, Spacing.s)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        // A session committed since the last open may have added words.
        .task { await journey.loadTopicWords(period, topic: topic.key, force: true) }
        .sheet(item: $openWord) { word in
            WordDetailSheet(wordID: word.wordId, lemma: word.lemma, ipa: nil, playAudio: nil)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            TopicIconTile(topic: topic, size: Spacing.iconBadge)
            VStack(alignment: .leading, spacing: 2) {
                JourneyTopicStyle.name(topic)
                    .font(Typography.screenTitle.weight(.heavy))
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                subtitle
                    .font(Typography.secondary.monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SheetCloseButton()
        }
    }

    private var subtitle: Text {
        switch period {
        case .week: Text("+\(topic.count) new words this week")
        case .month: Text("+\(topic.count) new words this month")
        case .all: Text("+\(topic.count) new words since you started")
        }
    }

    @ViewBuilder
    private var list: some View {
        let words = journey.topicWords[key] ?? []
        let total = journey.topicWordTotals[key] ?? words.count
        let load = journey.topicWordLoads[key]
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                row(word, isFirst: index == 0)
                    .onAppear {
                        guard index >= words.count - Self.prefetchDistance, words.count < total, load != .loading else { return }
                        if case .failed = load { return }
                        Task { await journey.loadTopicWords(period, topic: topic.key, more: true) }
                    }
            }
            switch load {
            case .failed?:
                failedRow(retryMore: !words.isEmpty && words.count < total)
            case .loaded? where words.isEmpty:
                Text("No new words in this period.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.s)
            case .loading?, .idle?, nil:
                if words.isEmpty || words.count < total {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: words.isEmpty ? 120 : Spacing.minTouchTarget)
                }
            default:
                EmptyView()
            }
        }
    }

    private func row(_ word: JourneyWord, isFirst: Bool) -> some View {
        Button { openWord = word } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(verbatim: word.lemma)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 96, alignment: .leading)
                Text(Self.meanings(word))
                    .font(Typography.secondary)
                    .foregroundStyle(Color.ink600)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .multilineTextAlignment(.leading)
            .padding(.vertical, Spacing.s)
            .overlay(alignment: .top) {
                if !isFirst {
                    Rectangle().fill(Color.ink100).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        // VoiceOver reads every meaning, never the clamped text.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: word.meaningTexts.isEmpty ? word.lemma : "\(word.lemma), \(word.glossary)"))
    }

    /// The meanings as one run of text, joined by an Ink 300 " · ".
    private static func meanings(_ word: JourneyWord) -> AttributedString {
        var text = AttributedString()
        for (index, meaning) in word.meaningTexts.enumerated() {
            if index > 0 {
                var separator = AttributedString(JourneyWord.meaningSeparator)
                separator.foregroundColor = Color.ink300
                separator.font = Typography.secondary.weight(.bold)
                text += separator
            }
            text += AttributedString(meaning)
        }
        return text
    }

    private func failedRow(retryMore: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text("Couldn’t load")
                .foregroundStyle(Color.mutedInk)
            Text(verbatim: "·")
                .foregroundStyle(Color.ink300)
                .accessibilityHidden(true)
            TextLink(title: "Try again") {
                Task { await journey.loadTopicWords(period, topic: topic.key, more: retryMore, force: !retryMore) }
            }
        }
        .font(Typography.secondary)
        .padding(.vertical, Spacing.xxs)
    }
}
