import SwiftUI

/// Sheet editing only the routine (daily goal, reviews per session, learning days, reminder); topics are untouched.
/// Dismissing discards the draft.
struct EditRoutineView: View {
    let onSave: (LearningPreferences) -> Void
    @Environment(AppSettingsStore.self) private var settings
    @State private var draft: LearningPreferences

    init(initial: LearningPreferences, onSave: @escaping (LearningPreferences) -> Void) {
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                SheetTitle("Your routine")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l + Spacing.xxs)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.s - 2) {
                        PlanSectionTitle(text: "New words / day")
                        WordsPerDayStepper(value: draft.wordsPerDay) { amount in
                            draft.adjustWordsPerDay(by: amount)
                            settings.feedback.selectionChanged()
                        }
                    }
                    ReviewsPerSessionPicker(preferences: $draft)
                    LearningDaysPicker(
                        selected: draft.learningDays,
                        onToggleDay: { day in
                            draft.toggleDay(day)
                            settings.feedback.selectionChanged()
                        },
                        onToggleEveryDay: {
                            draft.toggleEveryDay()
                            settings.feedback.selectionChanged()
                        }
                    )
                    ReminderPicker(preferences: $draft)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
    }

    private var saveBar: some View {
        PinnedActionBar {
            PrimaryButton(
                title: "Save changes",
                requirement: "Choose at least one learning day",
                isEnabled: draft.isComplete
            ) {
                settings.feedback.success()
                onSave(draft)
            }
        }
    }
}
