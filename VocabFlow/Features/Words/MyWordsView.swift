import SwiftUI

struct MyWordsView: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PracticeSessionStore.self) private var practice
    let onOpenRandomPractice: () -> Void
    @State private var query = ""
    @State private var selected: WordProgress?
    @State private var customWordSheet: CustomWordSheet?

    /// Reaching this many rows from the end loads the next page.
    private static let loadMoreDistance = 10

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let words = learner.words
        let stats = learner.wordStats
        let needPractice = stats?.needPracticeWords ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.s) {
                    ScreenTitle("My Words")
                    Spacer(minLength: 0)
                    SmallButton(title: "Add word", systemImage: "plus") { customWordSheet = .add }
                }
                .padding(.top, Spacing.l)

                if (stats?.learnedWords ?? words.count) == 0 && learner.wordsQuery.isEmpty {
                    emptyState
                        .padding(.top, Spacing.xl)
                } else {
                    if let stats {
                        LibraryStats(learned: stats.learnedWords, needPractice: needPractice, fluent: stats.fluentWords)
                            .padding(.top, Spacing.l)
                    }

                    SectionTitle("Practice")
                        .padding(.top, Spacing.xl + Spacing.xxs)
                    practiceCard(needPractice: needPractice)

                    SectionTitle("All words") {
                        TextLink(title: "Manage added") { customWordSheet = .list }
                    }
                    .padding(.top, Spacing.xl + Spacing.xxs)

                    SearchField(placeholder: "Search your words", text: $query)

                    wordList(words)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await learner.refresh() }
        .task(id: trimmedQuery) {
            let search = trimmedQuery
            guard search != learner.wordsQuery else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Detached from this task: leaving the tab must not abandon a query the store already recorded.
            Task { await learner.loadWords(matching: search) }
        }
        .sheet(item: $selected) { word in
            WordDetailSheet(
                wordID: word.wordId,
                lemma: word.lemma,
                ipa: word.ipa,
                playAudio: word.meanings.compactMap(\.meaning.audio).first.map { clip in { practice.playClip(clip) } },
                isPlayingAudio: practice.audio.isPlaying
            )
        }
        .sheet(item: $customWordSheet) { sheet in
            switch sheet {
            case .add: AddWordView()
            case .list: CustomWordsView()
            }
        }
    }

    @ViewBuilder
    private func wordList(_ words: [WordProgress]) -> some View {
        if words.isEmpty {
            if learner.isSearchingWords {
                loadingRow
            } else if let error = learner.wordsError {
                retry(error) { await learner.loadWords(matching: trimmedQuery) }
            } else if !learner.wordsQuery.isEmpty {
                Text("No words match “\(learner.wordsQuery)”")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.l - 2)
            }
        } else {
            let loadMoreTrigger = words.suffix(Self.loadMoreDistance).first?.id
            LazyVStack(spacing: 0) {
                ForEach(words) { word in
                    row(word, isLast: word.id == words.last?.id)
                        .onAppear {
                            guard word.id == loadMoreTrigger else { return }
                            Task { await learner.loadMoreWords() }
                        }
                }
                if learner.isLoadingMoreWords {
                    loadingRow
                } else if let error = learner.wordsError {
                    retry(error) {
                        if learner.hasMoreWords {
                            await learner.loadMoreWords()
                        } else {
                            await learner.loadWords(matching: trimmedQuery)
                        }
                    }
                }
            }
            .opacity(learner.isSearchingWords ? 0.5 : 1)
            .padding(.top, Spacing.xs)
        }
    }

    private var loadingRow: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
    }

    private func retry(_ message: String, action: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(verbatim: message)
                .font(Typography.secondary)
                .foregroundStyle(Color.errorInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                Task { await action() }
            }
        }
        .padding(.vertical, Spacing.m)
    }

    private func startPractice(_ mode: SessionMode) {
        Task { await practice.start(mode) }
    }

    /// Random practice needs one more step (›); Weak Words and Speaking start at once, Weak Words only when it has words.
    private func practiceCard(needPractice: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: onOpenRandomPractice) {
                PracticeRow(systemImage: "shuffle", tone: .accent, title: "Random Practice", subtitle: "Choose a collection or topics to practice") {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ink400)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityElement(children: .combine)

            CardDivider()

            PracticeRow(
                systemImage: "scope",
                tone: .error,
                title: "Weak Words",
                subtitle: needPractice > 0 ? "Words you keep missing" : "No words need practice"
            ) {
                if needPractice > 0 {
                    SmallButton(title: "Practice now", kind: .practice) { startPractice(.weakWordsPractice) }
                }
            }
            .accessibilityElement(children: .contain)

            CardDivider()

            PracticeRow(systemImage: "mic.fill", tone: .success, title: "Speaking Practice", subtitle: "Say your words out loud") {
                SmallButton(title: "Practice now", kind: .practice) { startPractice(.speakingPractice) }
            }
            .accessibilityElement(children: .contain)
        }
        .cardSurface()
    }

    private func row(_ word: WordProgress, isLast: Bool) -> some View {
        Button {
            selected = word
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
                    Text(verbatim: word.lemma)
                        .font(Typography.wordClass.weight(.bold))
                        .foregroundStyle(Color.ink)
                    if let ipa = word.ipa {
                        Text(verbatim: ipa)
                            .font(Typography.secondary)
                            .foregroundStyle(Color.mutedInk)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.xs)
                MeaningDots(learned: word.meanings.count, total: word.meaningCount)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink300)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.s)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.divider).frame(height: Borders.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows every meaning of the word"))
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s) {
            IconBadge(systemImage: "book", tone: .accent, size: Spacing.xl * 2)
                .rotationEffect(.degrees(-8))
            Text("No words yet")
                .font(Typography.sectionTitle)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xs)
            Text("Finish today’s flow and your words will collect here.")
                .font(Typography.secondary)
                .foregroundStyle(Color.bodyInk)
                .multilineTextAlignment(.center)
            TextLink(title: "Manage added") { customWordSheet = .list }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum CustomWordSheet: String, Identifiable {
    case add, list

    var id: String { rawValue }
}

/// The two library figures in one card, split by a hairline. Read-only.
private struct LibraryStats: View {
    let learned: Int
    let needPractice: Int
    /// Nil from an older backend: the figure is left out.
    let fluent: Int?

    var body: some View {
        HStack(spacing: 0) {
            figure(learned, caption: "Words learned", color: .ink)
            divider
            figure(needPractice, caption: "Need practice", color: needPractice > 0 ? .coral600 : .ink400)
            if let fluent {
                divider
                figure(fluent, caption: "Said fluently", color: .successInk)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardSurface()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(width: Borders.hairline)
            .accessibilityHidden(true)
    }

    private func figure(_ value: Int, caption: LocalizedStringKey, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value, format: .number.locale(AppLanguage.active.locale))
                .font(Typography.stat.monospacedDigit())
                .tracking(Typography.tightTracking)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(caption)
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(Color.mutedInk)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A row of the Practice card: icon badge, title and subtitle, then a trailing chevron or button.
private struct PracticeRow<Trailing: View>: View {
    let systemImage: String
    let tone: IconBadge.Tone
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.s) {
            IconBadge(systemImage: systemImage, tone: tone)
            VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
                Text(title)
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            trailing
        }
        .padding(Spacing.m)
    }
}

/// One dot per meaning: Green 500 learned, Ink 200 not yet. Without the server's total, only the learned ones.
private struct MeaningDots: View {
    /// More meanings than this show as a count instead.
    private static let maxDots = 6

    let learned: Int
    let total: Int?

    var body: some View {
        let count = max(total ?? learned, learned)
        Group {
            if count > Self.maxDots {
                Text(verbatim: "\(learned)/\(count)")
                    .font(Typography.micro.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.mutedInk)
            } else {
                HStack(spacing: Spacing.xxs) {
                    ForEach(0..<count, id: \.self) { index in
                        Circle()
                            .fill(index < learned ? Color.success : Color.stroke)
                            .frame(width: Spacing.xs, height: Spacing.xs)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? Text("1 of 1 meaning learned") : Text("\(learned) of \(count) meanings learned"))
    }
}
