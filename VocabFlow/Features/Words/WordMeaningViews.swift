import SwiftUI

struct PartOfSpeechGroup<Item>: Identifiable {
    let partOfSpeech: String
    let items: [Item]

    var id: String { partOfSpeech }

    /// Groups keep the order in which their part of speech first appears.
    static func grouping(_ items: [Item], by partOfSpeech: (Item) -> String) -> [PartOfSpeechGroup<Item>] {
        var order: [String] = []
        var buckets: [String: [Item]] = [:]
        for item in items {
            let key = partOfSpeech(item)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.map { PartOfSpeechGroup(partOfSpeech: $0, items: buckets[$0] ?? []) }
    }
}

/// Definition and first example of one meaning.
struct MeaningFields: View {
    enum Style { case divided, quiet }

    let lemma: String
    let sense: WordMeaning.Sense
    var style = Style.divided

    var body: some View {
        let definition = sense.definition.flatMap { $0.isEmpty ? nil : $0 }
        VStack(alignment: .leading, spacing: 0) {
            if let definition {
                field("Definition") {
                    Text(verbatim: definition)
                }
            }
            if let example = sense.examples?.first {
                if style == .divided && definition != nil {
                    Rectangle().fill(Color.divider).frame(height: Borders.hairline)
                }
                field("In context") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(LearnView.highlight(lemma, in: example.text))
                        if let translation = example.translation, !translation.isEmpty {
                            ExampleTranslation(text: translation)
                        }
                    }
                }
            }
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, style == .divided ? Spacing.s : Spacing.xs)
    }
}

/// A backend part of speech styled as an eyebrow; it is data, so it can't go through `Eyebrow`.
private struct PartOfSpeechEyebrow: View {
    let value: String

    var body: some View {
        Text(verbatim: VocabularyItem.localizedPartOfSpeech(value))
            .font(Typography.eyebrow)
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(Color.mutedInk)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ExpandChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.mutedInk)
            .symbolReplace(value: isExpanded)
            .accessibilityHidden(true)
    }
}

// MARK: - Other meanings (word introduction)

/// Reference sheet from a learn step: the word's other meanings, outside the lesson.
struct OtherMeaningsSheet: View {
    let lemma: String
    let meanings: [WordDetail.Meaning]
    @Environment(\.motion) private var motion
    @State private var expandedIDs: Set<String> = []
    @State private var playingMeaningID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Other meanings of “\(lemma)”")
                            .font(Typography.screenTitle)
                            .tracking(Typography.tightTracking)
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("For reference only · Not part of this lesson")
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    SheetCloseButton()
                }
                .padding(.bottom, Spacing.m)

                ForEach(PartOfSpeechGroup.grouping(meanings) { $0.meaning.partOfSpeech }) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        PartOfSpeechEyebrow(value: group.partOfSpeech)
                            .padding(.top, Spacing.m)
                            .padding(.bottom, Spacing.xxs)
                        ForEach(group.items, id: \.meaningId) { item in
                            row(item, isLast: item.meaningId == group.items.last?.meaningId)
                        }
                    }
                    .padding(.bottom, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .onAppear { expandedIDs = Set(meanings.first.map { [$0.meaningId] } ?? []) }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    private func toggle(_ id: String, isExpanded: Bool) {
        if isExpanded { expandedIDs.remove(id) } else { expandedIDs.insert(id) }
    }

    private func row(_ item: WordDetail.Meaning, isLast: Bool) -> some View {
        let isExpanded = expandedIDs.contains(item.meaningId)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                motion.perform(MotionTokens.snap) { toggle(item.meaningId, isExpanded: isExpanded) }
            } label: {
                HStack(spacing: Spacing.s) {
                    Text(verbatim: item.meaning.text)
                        .font(Typography.tile)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.xs)
                    if item.learnedAt != nil {
                        StatusPill("Learned", tone: .success, systemImage: "checkmark")
                    } else {
                        StatusPill("Not learned")
                    }
                    ExpandChevron(isExpanded: isExpanded)
                }
                .frame(minHeight: Spacing.minTouchTarget + Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if isExpanded {
                MeaningFields(lemma: lemma, sense: item.meaning, style: .quiet)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.s)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.m)
        .cardSurface()
        .padding(.top, Spacing.s)
    }
}

// MARK: - Word hero (word detail, add word)

/// The word, centered, over its IPA and a 44 pt pronunciation button. Plays recorded audio when there is some;
/// otherwise the device speaks the word.
struct WordHeroHeader: View {
    let lemma: String
    let ipa: String?
    var playAudio: (() -> Void)?
    /// Whether `playAudio`'s clip is playing right now. Without `playAudio` the device speech is watched instead.
    var isPlayingAudio = false
    var showsPronunciation = true
    @Environment(SpeechPlayer.self) private var speech

    private var isPlaying: Bool { playAudio == nil ? (speech.isSpeaking && speech.spokenText == lemma && speech.spokenIPA == ipa) : isPlayingAudio }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(verbatim: lemma)
                .font(Typography.wordTitle)
                .tracking(Typography.displayTracking)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if showsPronunciation {
                HStack(spacing: Spacing.s) {
                    if let ipa {
                        Text(verbatim: ipa)
                            .font(Typography.ipaHero)
                            .foregroundStyle(Color.bodyInk)
                            .accessibilityLabel(Text("IPA: \(ipa)"))
                    }
                    Button {
                        if let playAudio {
                            playAudio()
                        } else {
                            _ = speech.speak(lemma, ipa: ipa)
                        }
                    } label: {
                        Group {
                            if playAudio != nil || speech.isAvailable {
                                SpeakerWaveIcon(isPlaying: isPlaying, side: 22)
                            } else {
                                Image(systemName: "speaker.slash")
                                    .font(.title3.weight(.semibold))
                            }
                        }
                        .foregroundStyle((playAudio != nil || speech.isAvailable) ? Color.link : Color.disabledInk)
                        .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                        .background((playAudio != nil || speech.isAvailable) ? Color.selectedSurface : Color.disabledSurface, in: Circle())
                        .contentShape(Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(playAudio == nil && !speech.isAvailable)
                    .accessibilityLabel(Text((playAudio != nil || speech.isAvailable) ? "Play pronunciation" : "Audio unavailable"))
                    .accessibilityValue(isPlaying ? Text("Playing") : Text(verbatim: ""))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Word detail (My Words)

/// Every meaning of a word grouped by part of speech; progress belongs to each meaning, not the word.
/// Each meaning is a card that opens to its definition, example and skills.
struct WordDetailSheet: View {
    private enum Load: Equatable {
        case loading, failed
        case loaded(WordDetail)
    }

    let wordID: String
    let lemma: String
    let ipa: String?
    /// Opens expanded; otherwise the first learned meaning does.
    var focusMeaningID: String?
    /// Plays recorded audio when there is some. Nil falls back to the loaded detail's clip, then to device speech.
    let playAudio: (() -> Void)?
    /// Whether `playAudio`'s clip is playing right now, for the speaker waves.
    var isPlayingAudio = false
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.motion) private var motion
    @State private var load = Load.loading
    @State private var expandedIDs: Set<String> = []
    /// The meaning opened last; the header's audio follows it.
    @State private var focusedID: String?
    @State private var playingMeaningID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                WordHeroHeader(
                    lemma: lemma,
                    ipa: pronunciationsDiffer ? nil : ipa ?? loadedMeaning?.meaning.ipa,
                    playAudio: heroPlayAudio,
                    isPlayingAudio: heroPlayAudio == nil || playAudio == nil || pronunciationsDiffer ? practice.audio.isPlaying : isPlayingAudio,
                    showsPronunciation: !pronunciationsDiffer
                )

                VStack(alignment: .leading, spacing: 0) { meanings }
                    .padding(.top, Spacing.xl)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.l)
        }
        .task { await loadDetail() }
        .onDisappear { speech.stop() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.canvas)
    }

    /// Senses of one spelling can sound different (read /riːd/, /rɛd/). Then each meaning shows its own IPA and audio,
    /// and the hero plays the open meaning's instead of one IPA for the word.
    private var pronunciationsDiffer: Bool {
        guard case .loaded(let detail) = load else { return false }
        return Set(detail.meanings.map { $0.meaning.ipa ?? "" }).count > 1
    }

    private var heroPlayAudio: (() -> Void)? {
        let clip = detailClip.map { clip in { practice.playClip(clip) } }
        return pronunciationsDiffer ? clip : playAudio ?? clip
    }

    /// The open meaning, else the first one; nil until the detail loads.
    private var loadedMeaning: WordDetail.Meaning? {
        guard case .loaded(let detail) = load else { return nil }
        return detail.meanings.first { $0.meaningId == focusedID } ?? detail.meanings.first
    }

    /// The server's recorded clip for the word. Nil (still loading, or no audio yet) leaves device speech.
    private var detailClip: AudioClip? {
        guard case .loaded(let detail) = load else { return nil }
        return loadedMeaning?.meaning.audio ?? detail.meanings.lazy.compactMap(\.meaning.audio).first
    }

    @ViewBuilder
    private var meanings: some View {
        SectionTitle("Meanings") {
            if case .loaded(let detail) = load {
                let learned = detail.meanings.filter { $0.learnedAt != nil }.count
                Text("\(learned) / \(detail.meanings.count) learned")
                    .font(Typography.secondary.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .padding(.bottom, -Spacing.s)

        switch load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.l)
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Couldn’t load this word")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.errorInk)
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await loadDetail() }
                }
            }
            .padding(.vertical, Spacing.m)
        case .loaded(let detail):
            ForEach(PartOfSpeechGroup.grouping(detail.meanings) { $0.meaning.partOfSpeech }) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    PartOfSpeechEyebrow(value: group.partOfSpeech)
                    ForEach(Array(group.items.enumerated()), id: \.element.meaningId) { index, item in
                        card(item, number: index + 1)
                    }
                }
                .padding(.top, Spacing.s)
            }
        }
    }

    private func card(_ item: WordDetail.Meaning, number: Int) -> some View {
        let isExpanded = expandedIDs.contains(item.meaningId)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                motion.perform(MotionTokens.snap) { toggle(item.meaningId, isExpanded: isExpanded) }
            } label: {
                HStack(spacing: Spacing.s) {
                    Text(verbatim: "\(number)")
                        .font(Typography.body.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.ink400)
                        .frame(width: Spacing.m, alignment: .leading)
                    Text(verbatim: item.meaning.text)
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.xs)
                    if item.learnedAt != nil {
                        StatusPill("Learned", tone: .success, systemImage: "checkmark")
                    } else {
                        StatusPill("Not learned")
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink400)
                        .symbolReplace(value: isExpanded)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.rowMinHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if pronunciationsDiffer {
                WordPronunciation(term: lemma, ipa: item.meaning.ipa,
                    playAudio: item.meaning.audio.map { clip in { playingMeaningID = item.meaningId; practice.playClip(clip) } },
                    isPlayingAudio: playingMeaningID == item.meaningId && practice.audio.isPlaying, style: .compact)
                    .padding(.leading, Spacing.xl + Spacing.s)
                    .padding(.bottom, Spacing.xs)
            }
            if isExpanded {
                expandedContent(item)
                    .padding(.leading, Spacing.xl + Spacing.s)
                    .padding(.trailing, Spacing.m)
                    .padding(.bottom, Spacing.m)
                    .transition(.opacity)
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private func expandedContent(_ item: WordDetail.Meaning) -> some View {
        let sense = item.meaning
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let definition = sense.definition, !definition.isEmpty {
                field("Definition") {
                    Text(verbatim: definition)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.ink)
                }
            }
            if let example = sense.examples?.first {
                field("Example") {
                    VStack(alignment: .leading, spacing: Spacing.xs - 2) {
                        HighlightedSentence(sentence: example.text, term: lemma)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.ink)
                        if let translation = example.translation, !translation.isEmpty {
                            ExampleTranslation(text: translation)
                        }
                    }
                }
            }
            if let learnedAt = item.learnedAt {
                if let memory = item.memory {
                    field("Memory") {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            MemoryStrengthRow(memory: memory)
                            if item.needsPractice == true {
                                StatusPill("Needs practice", tone: .error)
                            }
                        }
                    }
                }
                if let speaking = item.speaking {
                    field("Speaking") {
                        speakingCell(speaking)
                    }
                }
                Text("Learned \(learnedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.active.locale)))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            } else {
                Text("This meaning hasn’t been learned yet. No progress is available.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs - 2) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ id: String, isExpanded: Bool) {
        if isExpanded { expandedIDs.remove(id) } else { expandedIDs.insert(id); focusedID = id }
    }

    private func loadDetail() async {
        load = .loading
        do {
            let detail = try await learner.wordDetail(id: wordID)
            if focusedID == nil {
                let ids = detail.meanings.map(\.meaningId)
                focusedID = focusMeaningID.flatMap { ids.contains($0) ? $0 : nil }
                    ?? detail.meanings.first { $0.learnedAt != nil }?.meaningId
                    ?? ids.first
                expandedIDs = Set(focusedID.map { [$0] } ?? [])
            }
            load = .loaded(detail)
        } catch {
            guard !Task.isCancelled else { return }
            load = .failed
        }
    }

    /// A tinted cell: the speaking status, coloured by it, over the scores when Azure scored the takes.
    private func speakingCell(_ speaking: MeaningSpeaking) -> some View {
        let tone = speakingTone(speaking.status)
        return VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
            HStack(spacing: Spacing.xxs) {
                Text(speakingLabel(speaking.status))
                    .font(Typography.micro.weight(.bold))
                if speaking.status == .fluent {
                    Image(systemName: "checkmark")
                        .font(Typography.caption.weight(.heavy))
                        .accessibilityHidden(true)
                }
            }
            if let last = speaking.lastScore {
                let best = Int((speaking.bestScore ?? last).rounded())
                Text("Last score \(Int(last.rounded())) · best \(best)")
                    .font(Typography.caption)
                    .opacity(0.9)
            }
        }
        .foregroundStyle(tone.fg)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.bg, in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func speakingLabel(_ status: SpeakingStatus) -> LocalizedStringKey {
        switch status {
        case .fluent: "Fluent"
        case .practicing: "Practicing"
        case .notTried, .unknown: "Not tried yet"
        }
    }

    private func speakingTone(_ status: SpeakingStatus) -> (bg: Color, fg: Color) {
        switch status {
        case .fluent: (.successSurface, .successInk)
        case .practicing: (.selectedSurface, .selectedInk)
        case .notTried, .unknown: (.neutralSurface, .ink600)
        }
    }
}

/// How well a learned meaning holds now: a bar for the chance of recall and the next review date.
private struct MemoryStrengthRow: View {
    let memory: MeaningMemory

    var body: some View {
        let percent = Int((memory.retrievability * 100).rounded())
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text("\(percent)% likely to remember now")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: Spacing.xs)
            }
            ProgressView(value: min(max(memory.retrievability, 0), 1))
                .tint(memory.retrievability >= 0.9 ? Color.successInk : Color.selectedInk)
                .accessibilityHidden(true)
            if let next = memory.nextReviewAt {
                Text("Next review \(next.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.active.locale)))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
