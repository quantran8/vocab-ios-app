import SwiftUI

/// Learning-plan inputs shared by onboarding and the Profile plan editor.

extension CEFRLevel {
    var title: LocalizedStringKey {
        switch self {
        case .a1: "Beginner"
        case .a2: "Elementary"
        case .b1: "Intermediate"
        case .b2: "Upper-intermediate"
        case .c1: "Advanced"
        case .c2: "Proficient"
        }
    }

    /// What a learner at this level can do, so choosing by hand has something to go on.
    var example: LocalizedStringKey {
        switch self {
        case .a1: "Greetings, introducing yourself"
        case .a2: "Shopping, asking the way, daily errands"
        case .b1: "Telling stories, talking about work"
        case .b2: "Reading the news, meetings, debates"
        case .c1: "Reading specialist texts"
        case .c2: "Close to a native speaker"
        }
    }
}

/// The six levels as rows in one card: code, name and an example of what it covers.
struct LevelList: View {
    let selected: CEFRLevel?
    let onSelect: (CEFRLevel) -> Void

    var body: some View {
        ChoiceCard(items: CEFRLevel.allCases) { level in
            let isSelected = level == selected
            ChoiceRow(isSelected: isSelected) {
                onSelect(level)
            } content: {
                Text(verbatim: level.rawValue)
                    .font(Typography.secondary.weight(.heavy))
                    .foregroundStyle(isSelected ? Color.white : Color.ink700)
                    .frame(width: 44, height: 36)
                    .background(
                        isSelected ? Color.interactive : Color.neutralSurface,
                        in: RoundedRectangle(cornerRadius: Radii.badge, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(Typography.secondary.weight(.bold))
                        .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    Text(level.example)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// One row per collection in a card: mark dot, name, summary and topic count. Exactly one is selected.
struct CollectionList: View {
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        ChoiceCard(items: TopicCatalog.collections) { collection in
            let isSelected = collection.id == selectedID
            ChoiceRow(isSelected: isSelected, alignment: .top) {
                onSelect(collection.id)
            } content: {
                CollectionMarkDot(color: CollectionMarkColor.color(for: collection))
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: collection.name)
                        .font(Typography.emphasis)
                        .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    if !collection.summary.isEmpty {
                        Text(verbatim: collection.summary)
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(collection.topics.count) topics")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.leading)
            }
        }
    }
}

/// "Every day", a run such as "T2 – T6", or the days listed.
enum LearningDaysSummary {
    static func text(_ days: Set<Int>) -> Text {
        if days == LearningPreferences.allWeekdays { return Text("Every day") }
        let ordered = Weekday.ordered
        let picked = ordered.enumerated().filter { days.contains($0.element.id) }
        guard let first = picked.first, let last = picked.last else { return Text(verbatim: "–") }
        if picked.count >= 3, last.offset - first.offset == picked.count - 1 {
            return Text(verbatim: "\(first.element.short) – \(last.element.short)")
        }
        return Text(verbatim: picked.map(\.element.short).joined(separator: ", "))
    }
}

/// "Not sure? Take the test": first on a level screen, so someone unsure sees it before guessing on the list.
struct PlacementTestCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                IconBadge(systemImage: "checklist", tone: .accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not sure? Take the test")
                        .font(Typography.emphasis)
                        .foregroundStyle(Color.ink)
                    Text("Syll scores it and picks your level")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink400)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.m)
            .cardSurface()
            .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The topics of one collection, with a "Select all / Clear all" shortcut.
struct TopicPicker: View {
    let collection: VocabCollection
    let selectedIDs: Set<String>
    let onToggleTopic: (String) -> Void
    let onToggleAll: () -> Void
    /// "Everyday · 3/12 topics" in the eyebrow instead of the name alone.
    var countsSelection = false
    /// Learned/total on each chip; off for a new account, where every topic reads 0.
    var showsProgress = true

    var body: some View {
        let hasAll = selectedIDs == collection.topicIDs
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                if countsSelection {
                    Eyebrow(text: "\(collection.name) · \(selectedIDs.intersection(collection.topicIDs).count)/\(collection.topics.count) topics")
                } else {
                    Eyebrow(text: LocalizedStringKey(collection.name))
                }
                Spacer()
                TextLink(title: hasAll ? "Clear all" : "Select all", action: onToggleAll)
                    .padding(.vertical, -Spacing.s)
            }
            .staticLabelRow()

            // Topics with new words left first; finished ones last but still selectable.
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(collection.topics.filter { !$0.isFinished } + collection.topics.filter(\.isFinished)) { topic in
                    TopicChip(
                        title: topic.name,
                        systemImage: topic.systemImage,
                        isSelected: selectedIDs.contains(topic.id),
                        progress: showsProgress ? topic.total.map { (learned: topic.learned ?? 0, total: $0) } : nil,
                        isFinished: showsProgress && topic.isFinished
                    ) {
                        onToggleTopic(topic.id)
                    }
                }
            }
        }
    }
}

/// − value + inside a card, clamped to `range`: 48 pt round Ink 100 buttons around a 30 pt number.
struct WordsPerDayStepper: View {
    let value: Int
    var range: ClosedRange<Int> = LearningPreferences.wordsPerDayRange
    var label: LocalizedStringKey = "New words per day"
    var decreaseLabel: LocalizedStringKey = "Decrease new words per day"
    var increaseLabel: LocalizedStringKey = "Increase new words per day"
    let onAdjust: (Int) -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        HStack(spacing: Spacing.m) {
            stepperButton("minus", label: decreaseLabel, isEnabled: value > range.lowerBound) {
                onAdjust(-1)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs - 2) {
                Text(verbatim: "\(value)")
                    .font(Typography.stat.monospacedDigit())
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(motion.animation(MotionTokens.snap), value: value)
                Text("words")
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text("\(value) words"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdjust(1)
                case .decrement: onAdjust(-1)
                @unknown default: break
                }
            }
            stepperButton("plus", label: increaseLabel, isEnabled: value < range.upperBound) {
                onAdjust(1)
            }
        }
        .padding(Spacing.s)
        .cardSurface()
    }

    private func stepperButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
                .frame(width: Spacing.fieldHeight, height: Spacing.fieldHeight)
                .background(Color.neutralSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
    }
}

/// Title row with an "Every day / Clear all" link, seven day toggles and a summary line.
struct LearningDaysPicker: View {
    let selected: Set<Int>
    let onToggleDay: (Int) -> Void
    let onToggleEveryDay: () -> Void

    var body: some View {
        let isEveryDay = selected == LearningPreferences.allWeekdays
        VStack(alignment: .leading, spacing: Spacing.s - 2) {
            HStack(alignment: .firstTextBaseline) {
                PlanSectionTitle(text: "Learning days")
                Spacer()
                TextLink(title: isEveryDay ? "Clear all" : "Every day", action: onToggleEveryDay)
                    .padding(.vertical, -Spacing.s)
            }
            .staticLabelRow()

            HStack(spacing: Spacing.xs - 2) {
                ForEach(Weekday.ordered) { day in
                    DayToggle(
                        title: day.short,
                        accessibilityName: day.full,
                        isSelected: selected.contains(day.id)
                    ) {
                        onToggleDay(day.id)
                    }
                }
            }

            Group {
                if selected.isEmpty {
                    Text("Choose at least one day")
                } else if isEveryDay {
                    Text("Every day")
                } else {
                    Text("\(selected.count) days a week")
                }
            }
            .font(Typography.micro)
            .foregroundStyle(Color.mutedInk)
        }
    }
}

/// "Reviews / session": follows the new-word goal until the learner sets a number.
struct ReviewsPerSessionPicker: View {
    @Binding var preferences: LearningPreferences
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s - 2) {
            HStack(alignment: .firstTextBaseline) {
                PlanSectionTitle(text: "Reviews / session")
                Spacer(minLength: Spacing.s)
                if preferences.reviewsPerSession != nil {
                    TextLink(title: "Match new words") {
                        preferences.reviewsPerSession = nil
                        settings.feedback.selectionChanged()
                    }
                    .padding(.vertical, -Spacing.s)
                }
            }
            WordsPerDayStepper(
                value: preferences.effectiveReviewsPerSession,
                range: LearningPreferences.reviewsPerSessionRange,
                label: "Reviews per session",
                decreaseLabel: "Decrease reviews per session",
                increaseLabel: "Increase reviews per session"
            ) { amount in
                let before = preferences.effectiveReviewsPerSession
                preferences.adjustReviewsPerSession(by: amount)
                if preferences.effectiveReviewsPerSession != before { settings.feedback.selectionChanged() }
            }
            Group {
                if preferences.reviewsPerSession == nil {
                    Text("Follows your new words, at least \(LearningPreferences.reviewsPerSessionFollowMin).")
                } else {
                    Text("Words due for review wait for the next session.")
                }
            }
            .font(Typography.micro)
            .foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Speaking practice": read-aloud tasks in Daily. Its ⓘ says that speaking never changes a word's progress
/// (backend "Daily speaking"), so turning it on is only about pronunciation.
struct DailySpeakingToggle: View {
    @Binding var preferences: LearningPreferences
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            PlanSectionTitle(text: "Speaking practice")
                .accessibilityHidden(true)
            InfoPopoverButton(
                text: "Read words aloud in your lessons. Right or wrong, it never changes your progress.",
                accessibilityLabel: "About speaking practice"
            )
            Spacer(minLength: Spacing.s)
            Toggle(isOn: $preferences.dailySpeaking) {
                Text("Speaking practice")
            }
            .labelsHidden()
            .tint(Color.interactive)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.rowMinHeight)
        .cardSurface()
        .onChange(of: preferences.dailySpeaking) { settings.feedback.selectionChanged() }
    }
}

/// One card: a "Remind me" switch row above the reminder time. Tapping the time opens the system time
/// picker as a popup (compact `DatePicker`); the row dims while reminders are off.
struct ReminderPicker: View {
    @Binding var preferences: LearningPreferences
    @Environment(\.motion) private var motion

    var body: some View {
        let isOn = preferences.reminderEnabled
        VStack(spacing: 0) {
            Toggle(isOn: $preferences.reminderEnabled.animation(motion.animation(MotionTokens.press))) {
                PlanSectionTitle(text: "Remind me")
            }
            .tint(Color.interactive)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(minHeight: Spacing.rowMinHeight)

            CardDivider()

            HStack(spacing: Spacing.s) {
                Image(systemName: "clock")
                    .font(Typography.body.weight(.medium))
                    .foregroundStyle(Color.mutedInk)
                    .accessibilityHidden(true)
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    Text("Reminder time")
                        .font(Typography.body)
                        .foregroundStyle(Color.bodyInk)
                }
                .datePickerStyle(.compact)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            .disabled(!isOn)
            .opacity(isOn ? 1 : 0.5)
        }
        .cardSurface()
    }

    private var reminderTime: Binding<Date> {
        Binding {
            preferences.reminderDate
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.reminderHour = parts.hour ?? preferences.reminderHour
            preferences.reminderMinute = parts.minute ?? preferences.reminderMinute
        }
    }
}

struct PlanSectionTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typography.emphasis)
            .tracking(-0.4)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Weekday labels in the app's language, starting on the calendar's first weekday (Monday in Vietnamese).
/// Vietnamese uses the usual T2…T7 and CN (the system's short symbols read "Th 2").
struct Weekday: Identifiable {
    /// `Calendar` weekday number, 1 = Sunday.
    let id: Int
    let short: String
    let full: String

    static var ordered: [Weekday] {
        let calendar = Calendar.current
        var names = calendar
        names.locale = AppLanguage.active.locale
        return (0..<7).map { offset in
            // A Vietnamese week runs T2 → CN whatever the device region says.
            let first = AppLanguage.active == .vietnamese ? 2 : calendar.firstWeekday
            let id = (first - 1 + offset) % 7 + 1
            return Weekday(
                id: id,
                short: short(id, names),
                full: names.weekdaySymbols[id - 1]
            )
        }
    }

    private static func short(_ id: Int, _ calendar: Calendar) -> String {
        guard AppLanguage.active == .vietnamese else { return calendar.shortWeekdaySymbols[id - 1] }
        return id == 1 ? "CN" : "T\(id)"
    }
}
