import SwiftUI

/// Home's compact Challenge card (one half of the two-up row). It never suggests the Daily Lesson is blocked,
/// and carries no urgent badge. Tapping it opens the Challenge Map, which holds every chapter state;
/// while the map can't load, it retries.
struct ChallengeHomeCard: View {
    let onOpenMap: () -> Void
    @Environment(ChallengeMapStore.self) private var store
    @Environment(ChallengeRunStore.self) private var run

    var body: some View {
        let summary = store.summary
        HomeTile(
            systemImage: "bolt.fill",
            tone: .reward,
            title: "Challenge",
            isEnabled: summary != nil || store.error != nil,
            action: {
                if summary == nil {
                    Task { await store.refresh() }
                } else {
                    onOpenMap()
                }
            }
        ) {
            detail(summary)
        }
        .modifier(PlayAction(summary: summary, play: play))
    }

    @ViewBuilder
    private func detail(_ summary: ChallengeHomeSummary?) -> some View {
        switch summary {
        case .notYetEligible(let eligible, let required)?:
            Text("\(eligible) / \(required) eligible words")
                .monospacedDigit()
        case .chapterReady(let chapterNo)?:
            Text("Chapter \(chapterNo) unlocked!")
        case .inProgress(let chapterNo, let levelNo, _, _)?:
            Text("Chapter \(chapterNo) · Level \(levelNo)")
        case .contentUnavailable(let chapterNo, _, _)?:
            Text("Chapter \(chapterNo)")
        case .chapterComplete(let chapterNo, _, _, _, _)?:
            Text("Chapter \(chapterNo) cleared")
        case nil:
            if store.error != nil {
                Text("Challenge isn’t available right now.")
            } else {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, Spacing.xxs)
            }
        }
    }

    private func play(_ chapterNo: Int, _ levelNo: Int) {
        let node = ChallengeNodeRef(chapterNo: chapterNo, levelNo: levelNo)
        Task { await run.play(node, level: store.level(node)) }
    }
}

/// The card used to have a Play button for the current level; VoiceOver keeps it as an action.
private struct PlayAction: ViewModifier {
    let summary: ChallengeHomeSummary?
    let play: (Int, Int) -> Void

    func body(content: Content) -> some View {
        if case .inProgress(let chapterNo, let levelNo, _, _)? = summary {
            content.accessibilityAction(named: Text("Play")) { play(chapterNo, levelNo) }
        } else {
            content
        }
    }
}
