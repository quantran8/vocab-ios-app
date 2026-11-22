import SwiftUI

extension ResultSection: Identifiable {
    var id: Self { self }
}

/// The words behind the tiles, grouped as the server decided. Opens scrolled to the tapped tile's block.
struct SessionResultDetailSheet: View {
    let result: PracticeResult
    let focus: ResultSection
    @Environment(LearnerStore.self) private var learner
    @Environment(\.motion) private var motion
    @State private var expanded: Set<String> = []
    @State private var collapsed: Set<String> = []
    @State private var selectedWord: SelectedWord?

    private struct SelectedWord: Identifiable {
        let wordId: String
        let lemma: String
        let meaningId: String
        var id: String { meaningId }
    }

    private var blocks: [ResultSheetBlock] { ResultSheetModel.blocks(for: result) }
    private var calendar: Calendar { ResultDateText.calendar(timeZone: learner.profile?.settings.timeZone) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Text("Session details")
                            .font(Typography.sectionTitle.weight(.heavy))
                            .tracking(Typography.tightTracking)
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        SheetCloseButton()
                    }

                    VStack(alignment: .leading, spacing: Spacing.l + Spacing.xxs) {
                        ForEach(blocks) { block in
                            blockView(block)
                        }
                    }
                    .padding(.top, Spacing.m)
                }
                .padding(.horizontal, Spacing.screenGutter)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
            }
            .onAppear {
                // The first block of the tapped tile's section.
                guard let target = blocks.first(where: { $0.section == focus })?.id else { return }
                Task { @MainActor in proxy.scrollTo(target, anchor: .top) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(wordID: word.wordId, lemma: word.lemma, ipa: nil, focusMeaningID: word.meaningId, playAudio: nil)
        }
    }

    // MARK: Blocks

    private func blockView(_ block: ResultSheetBlock) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                Eyebrow(text: block.title.text)
                    .accessibilityAddTraits(.isHeader)

                // The block's proportions; each group header below carries its part's swatch, so the names are the key.
                if let bar = block.bar {
                    SegmentedResultBar(segments: bar, revealed: true)
                        .accessibilityHidden(true)
                }
            }

            if let spoken = block.spoken {
                Text("Said right: \(spoken.passed) of \(spoken.total) words")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }

            if !block.groups.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(block.groups.enumerated()), id: \.element.id) { index, group in
                        if index > 0 { CardDivider() }
                        groupView(group, in: block)
                    }
                }
                .cardSurface()
            }

            if let excluded = block.excluded, excluded.count > 0 {
                Text("\(excluded.count) answers weren’t scored: \(reasonList(excluded.reasons))")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !block.countedAsReview.isEmpty {
                countedAsReview(block.countedAsReview)
            }
            if block.title == .speaking {
                Text("Speaking never changes your progress.")
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func countedAsReview(_ items: [ResultItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("\(items.count) due words counted as review")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.ink)
            if let next = items.first?.nextReviewAt {
                nextReviewText(next)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    // MARK: Groups

    private func key(_ group: ResultSheetGroup, in block: ResultSheetBlock) -> String { "\(block.id)-\(group.id)" }

    private func isExpanded(_ group: ResultSheetGroup, in block: ResultSheetBlock) -> Bool {
        let key = key(group, in: block)
        return group.collapsedByDefault ? expanded.contains(key) : !collapsed.contains(key)
    }

    private func toggle(_ group: ResultSheetGroup, in block: ResultSheetBlock) {
        let key = key(group, in: block)
        motion.perform(MotionTokens.snap) {
            if group.collapsedByDefault {
                if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) }
            } else {
                if collapsed.contains(key) { collapsed.remove(key) } else { collapsed.insert(key) }
            }
        }
    }

    private func groupView(_ group: ResultSheetGroup, in block: ResultSheetBlock) -> some View {
        let open = isExpanded(group, in: block)
        return VStack(alignment: .leading, spacing: 0) {
            Button { toggle(group, in: block) } label: {
                HStack(alignment: .center, spacing: Self.swatchGap) {
                    // The swatch keys the group to its bar segment; without one the column stays, so words line up.
                    Group {
                        if block.bar != nil, let level = group.barLevel {
                            ResultSwatch(level: level)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: Self.swatchSize.width, height: Self.swatchSize.height)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.kind.header(group.items.count))
                            .font(Typography.secondary.weight(.bold))
                            .foregroundStyle(Color.ink)
                        if let subtitle = subtitle(group) {
                            subtitle
                                .font(Typography.caption)
                                .foregroundStyle(Color.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.ink400)
                        .symbolReplace(value: open)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .frame(minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityValue(Text(open ? "Expanded" : "Collapsed"))

            if open {
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        itemRow(item, group: group)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: Items

    @ViewBuilder private func itemRow(_ item: ResultItem, group: ResultSheetGroup) -> some View {
        let row = HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: item.lemma)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                if !item.gloss.isEmpty {
                    Text(verbatim: item.gloss)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
            }
            Spacer(minLength: Spacing.xs)
            VStack(alignment: .trailing, spacing: 0) {
                if let tag = tag(for: item, in: group) {
                    tag
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(Color.selectedInk)
                }
                if let detail = detail(for: item) {
                    detail
                        .font(Typography.caption)
                        .foregroundStyle(Color.mutedInk)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        // Words line up under the group title, past the swatch column.
        .padding(.leading, Spacing.m + Self.swatchSize.width + Self.swatchGap)
        .padding(.trailing, Spacing.m)
        .padding(.bottom, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if let wordId = item.wordId {
            Button {
                selectedWord = SelectedWord(wordId: wordId, lemma: item.lemma, meaningId: item.meaningId)
            } label: { row }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint(Text("Opens the word."))
        } else {
            row
        }
    }

    private func tag(for item: ResultItem, in group: ResultSheetGroup) -> Text? {
        // Speaking changes: the Azure score; a device-scored take has none.
        if let score = item.score { return Text("Score \(Int(score.rounded()))") }
        if let skill = item.skill?.name { return Text(verbatim: skill) }
        // Review and new words: what the deciding answer was.
        if let cause = item.cause, cause != .unknown { return Text(cause.text) }
        return nil
    }

    /// Under the reason: the skill it happened in, and for a review word learned this week, when.
    /// Under a speaking score: its band, as the read-aloud titled it.
    private func detail(for item: ResultItem) -> Text? {
        var parts: [Text] = []
        if item.score != nil, let band = item.band, band != .unknown {
            parts.append(Text(verbatim: band.title))
        }
        if item.cause != nil, let skill = item.struggledAt?.name {
            parts.append(Text("while \(skill.lowercased(with: AppLanguage.active.locale))"))
        }
        if let learned = ResultDateText.recentlyLearned(item.learnedAt, now: .now, calendar: calendar) {
            parts.append(Text("learned \(learned.formatted(weekdayStyle))"))
        }
        return parts.reduce(nil) { joined, part in joined.map { $0 + Text(verbatim: " · ") + part } ?? part }
    }

    /// What puts a word in this group, then when the group comes back.
    private func subtitle(_ group: ResultSheetGroup) -> Text? {
        let explanation = group.kind.explanation.map { Text($0) }
        let next = group.showsNextReview ? group.items.first?.nextReviewAt.map(nextReviewText) : nil
        switch (explanation, next) {
        case let (explanation?, next?): return explanation + Text(verbatim: " · ") + next
        case let (explanation?, nil): return explanation
        case let (nil, next?): return next
        default: return nil
        }
    }

    private func nextReviewText(_ date: Date) -> Text {
        switch ResultDateText.nextReview(date, now: .now, calendar: calendar) {
        case .tonight: Text("Back tonight")
        case .tomorrow: Text("Back tomorrow")
        case .weekday(let day): Text("Back on \(day.formatted(weekdayStyle))")
        case .inDays(let days): Text("Back in \(days) days")
        }
    }

    private var weekdayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: AppLanguage.active.locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide)
    }

    private func reasonList(_ reasons: [String]) -> String {
        reasons.compactMap(Self.reasonName).formatted(.list(type: .and).locale(AppLanguage.active.locale))
    }

    private static func reasonName(_ reason: String) -> String? {
        switch reason {
        case "invalid_recording": String(localized: "unclear recordings", bundle: .appLanguage)
        case "unavailable": String(localized: "couldn’t record", bundle: .appLanguage)
        // Sent by an older backend only.
        case "weak_template": String(localized: "easier exercise types", bundle: .appLanguage)
        case "audio_not_played": String(localized: "audio didn’t play", bundle: .appLanguage)
        case "quality_unqualified": String(localized: "exercises still in review", bundle: .appLanguage)
        default: nil
        }
    }

    /// The 14 × 10 group swatch and the gap after it (gap-2.5).
    private static let swatchSize = CGSize(width: 14, height: 10)
    private static let swatchGap = Spacing.xs + 2
}

extension ResultSheetBlock.Title {
    var text: LocalizedStringKey {
        switch self {
        case .review: "Review"
        case .newWords: "New words"
        case .answers: "Answers"
        case .speaking: "Speaking"
        }
    }
}

extension ResultCause {
    var text: LocalizedStringKey {
        switch self {
        case .hinted: "Used a hint"
        case .retried: "Right after another try"
        case .primed: "Saw it just before"
        case .recognizedOnly: "Recognised, not recalled"
        case .revealed: "Saw the answer"
        case .outOfTries: "Not right after all tries"
        case .wrongChoice: "Picked another answer"
        case .notPassed: "Pronunciation not passed yet"
        case .unknown: ""
        }
    }
}

extension ResultSheetGroup.Kind {
    /// One plain line on what puts a word in this group; nil where the header already says it.
    var explanation: LocalizedStringKey? {
        switch self {
        case .relearn: "Didn’t come back on your own"
        case .shaky: "Right, but not fully on your own"
        case .solid: "Right first time, on your own"
        case .revealed: "Saw the answer or ran out of tries"
        case .retried: "Right after a hint or another try"
        case .smooth: "Right first time, no hints"
        case .known: "You already knew these"
        case .missed: "Not right this time"
        case .helped: "Right with a hint or another try"
        case .clean: "Right first time, on your own"
        case .notPassed: "Not passed on the first try"
        case .spokeRight: "Passed on the first try"
        case .becameFluent: "Said right again and again"
        case .slipped: "Fluent before, not right this time"
        }
    }

    func header(_ count: Int) -> LocalizedStringKey {
        switch self {
        case .relearn: "Relearn (\(count))"
        case .shaky: "Not solid yet (\(count))"
        case .solid: "Remembered (\(count))"
        case .revealed: "Saw the answer (\(count))"
        case .retried: "Needed a retry (\(count))"
        case .smooth: "Picked up right away (\(count))"
        case .known: "Already knew (\(count))"
        case .missed: "Not done yet (\(count))"
        case .helped: "Right with help (\(count))"
        case .clean: "Right on your own (\(count))"
        case .notPassed: "Not passed yet (\(count))"
        case .spokeRight: "Said right (\(count))"
        case .becameFluent: "Now fluent (\(count))"
        case .slipped: "Need practice again (\(count))"
        }
    }
}

extension ResultSkill {
    /// Same words as the skill rows on the word page; nil for a skill this app doesn't know.
    var name: String? {
        switch self {
        case .spelling: String(localized: "Spelling", bundle: .appLanguage)
        case .listening: String(localized: "Listening", bundle: .appLanguage)
        case .speaking: String(localized: "Speaking", bundle: .appLanguage)
        case .unknown: nil
        }
    }
}
