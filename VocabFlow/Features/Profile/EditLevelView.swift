import SwiftUI

/// Sheet changing the English level. Dismissing discards the draft.
struct EditLevelView: View {
    let onSave: (CEFRLevel) -> Void
    /// The placement test saved a new level and the learner accepted it.
    let onPlaced: () -> Void
    @Environment(AppSettingsStore.self) private var settings
    @Environment(PlacementTestStore.self) private var placement
    @Environment(\.motion) private var motion
    /// What the server holds. A finished test changes it while this sheet stays open.
    @State private var saved: CEFRLevel?
    @State private var draft: CEFRLevel?
    @State private var isTakingTest = false

    init(initial: CEFRLevel?, onSave: @escaping (CEFRLevel) -> Void, onPlaced: @escaping () -> Void) {
        self.onSave = onSave
        self.onPlaced = onPlaced
        _saved = State(initialValue: initial)
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }

                SheetTitle("Your level")
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.l)

                PlacementTestCard {
                    placement.start()
                    isTakingTest = true
                }

                Eyebrow(text: "Or choose it yourself")
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.s - 2)

                LevelList(selected: draft) { level in
                    guard level != draft else { return }
                    motion.perform(MotionTokens.snap) { draft = level }
                    settings.feedback.selectionChanged()
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            PinnedActionBar {
                PrimaryButton(
                    title: "Save changes",
                    requirement: "Choose your level",
                    isEnabled: draft != nil && draft != saved
                ) {
                    guard let draft else { return }
                    settings.feedback.success()
                    onSave(draft)
                }
            }
        }
        .fullScreenCover(isPresented: $isTakingTest) {
            PlacementTestView(
                doneTitle: "Done",
                onDone: { _ in
                    isTakingTest = false
                    onPlaced()
                },
                onChooseLevel: { result in
                    if let result {
                        saved = result.proficiencyLevel
                        draft = result.proficiencyLevel
                    }
                    isTakingTest = false
                },
                onLeave: { isTakingTest = false }
            )
        }
    }
}
