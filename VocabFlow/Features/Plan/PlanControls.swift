import SwiftUI

/// Learning-plan inputs shared by onboarding and the Profile plan editor.

/// One CEFR level with a short plain-language name, for the level grids.
struct LevelTile: View {
    let level: CEFRLevel
    let isSelected: Bool
    let action: () -> Void

    private var summary: LocalizedStringKey {
        switch level {
        case .a1: "Beginner"
        case .a2: "Elementary"
        case .b1: "Intermediate"
        case .b2: "Upper-intermediate"
        case .c1: "Advanced"
        case .c2: "Proficient"
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Text(verbatim: level.rawValue)
                    .font(Typography.tileLarge.weight(.bold))
                    .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                Text(summary)
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One card per collection; exactly one is selected.
struct CollectionPicker: View {
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: Spacing.s - 2) {
            ForEach(TopicCatalog.collections) { collection in
                CollectionCard(collection: collection, isSelected: collection.id == selectedID) {
                    onSelect(collection.id)
                }
            }
        }
    }
}

private struct CollectionCard: View {
    let collection: VocabCollection
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.motion) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: collection.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.ink)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? Color.interactive : Color.neutralSurface,
                        in: RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs - 2) {
                    Text(verbatim: collection.name)
                        .font(Typography.emphasis)
                        .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                    Text(verbatim: collection.summary)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("\(collection.topics.count) topics")
                    .font(Typography.micro.weight(.bold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.selectedInk : Color.mutedInk)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: Borders.card))
            .contentShape(shape)
            .animation(motion.animation(MotionTokens.press), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The topics of one collection, with a "Select all / Clear all" shortcut.
struct TopicPicker: View {
    let collection: VocabCollection
    let selectedIDs: Set<String>
    let onToggleTopic: (String) -> Void
    let onToggleAll: () -> Void

    var body: some View {
        let hasAll = selectedIDs == collection.topicIDs
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: LocalizedStringKey(collection.name))
                Spacer()
                TextLink(title: hasAll ? "Clear all" : "Select all", action: onToggleAll)
                    .padding(.vertical, -Spacing.s)
            }

            // Topics with new words left first; finished ones last but still selectable.
            FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.xs, alignment: .leading) {
                ForEach(collection.topics.filter { !$0.isFinished } + collection.topics.filter(\.isFinished)) { topic in
                    TopicChip(
                        title: topic.name,
                        systemImage: topic.systemImage,
                        isSelected: selectedIDs.contains(topic.id),
                        progress: topic.total.map { (learned: topic.learned ?? 0, total: $0) },
                        isFinished: topic.isFinished
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
