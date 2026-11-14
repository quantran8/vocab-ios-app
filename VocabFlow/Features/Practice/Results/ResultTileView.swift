import SwiftUI

/// One of the three equal-height tiles on the results screen. One number, one caption, one bar.
struct ResultTileView: View {
    let tile: ResultTile
    /// False until the screen has appeared: the number counts up and the bar grows from it.
    let revealed: Bool
    var onTap: (() -> Void)?
    @Environment(\.motion) private var motion

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint(Text("Shows the words."))
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .top, spacing: 0) {
                Text(tile.title)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if tile.celebrates {
                    SyllieReactionView(reaction: motion.reduceMotion ? .idle : .proud)
                        .frame(width: 36, height: 32)
                        .accessibilityHidden(true)
                }
            }

            numberText
                .font(Typography.screenTitle.monospacedDigit())
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(tile.caption.text)
                .font(Typography.micro)
                .foregroundStyle(Color.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, tile.lines.isEmpty ? 0 : Spacing.xxs)

            ForEach(Array(tile.lines.enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.s)
        .cardSurface(radius: Radii.tile)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var numberText: some View {
        switch tile.number {
        case .none:
            Text(verbatim: "—").accessibilityLabel(Text("None"))
        case .fraction(let part, let total):
            let shown = revealed ? part : 0
            Text(verbatim: "\(shown)/\(total)")
                .contentTransition(.numericText(value: Double(shown)))
                .accessibilityLabel(Text("\(part) of \(total)"))
        case .plus(let value):
            let shown = revealed ? value : 0
            Text(verbatim: "+\(shown)").contentTransition(.numericText(value: Double(shown)))
        case .count(let value):
            Text(verbatim: "\(value)")
        }
    }
}

/// Three proportional parts: solid, light, and striped, so the levels read without color. Keyed on the sheet by the
/// swatch in front of each group's header.
struct SegmentedResultBar: View {
    let segments: [Int]
    let revealed: Bool
    @Environment(\.motion) private var motion

    var body: some View {
        GeometryReader { proxy in
            let total = max(segments.reduce(0, +), 1)
            let parts = segments.enumerated().filter { $0.element > 0 }
            let gaps = CGFloat(max(parts.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(parts, id: \.offset) { index, count in
                    ResultSwatch.fill(index)
                        .frame(width: max((proxy.size.width - gaps) * CGFloat(count) / CGFloat(total), 0))
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .scaleEffect(x: revealed ? 1 : 0, anchor: .leading)
            .animation(motion.reduceMotion ? nil : motion.animation(MotionTokens.progress.delay(MotionTokens.celebrationStatsDelay)), value: revealed)
        }
        .frame(height: 8)
        .background(Color.track)
        .clipShape(Capsule())
    }

}

/// One bar segment's look, used in the bar and as its key next to the labels.
struct ResultSwatch: View {
    let level: Int

    var body: some View {
        Self.fill(level).clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    @ViewBuilder static func fill(_ level: Int) -> some View {
        switch level {
        case 0: Rectangle().fill(Color.resultStrong)
        case 1: Rectangle().fill(Color.resultMid)
        default: Stripes().background(Color.resultWeakSurface)
        }
    }
}

/// Diagonal hatch for the weakest segment.
private struct Stripes: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 4
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            context.stroke(path, with: .color(.resultWeakStripe), lineWidth: 1.5)
        }
    }
}

extension ResultTile {
    var title: LocalizedStringKey {
        switch kind {
        case .review: "Review"
        case .newWords: "New words"
        case .practice: "Practice"
        case .skillsLeveledUp: "Skills"
        case .weakRemaining: "Still to practise"
        }
    }
}

extension ResultTile.Caption {
    var text: LocalizedStringKey {
        switch self {
        case .remembered: "remembered"
        case .noReviews: "no reviews today"
        case .pickedUp: "picked up"
        case .noNewWords: "no new words today"
        case .practiceClean: "right on your own"
        case .noSkillMeasured: "no skills measured this session"
        case .skillsLeveledUp: "skills leveled up"
        case .weakRemaining: "words to practise"
        case .noWeakWordsLeft: "no weak words left"
        }
    }
}

extension ResultTile.Line {
    var text: LocalizedStringKey {
        switch self {
        case .relearn(let n): "\(n) to relearn"
        case .shaky(let n): "\(n) not solid yet"
        case .neededRetry(let n): "\(n) needed a retry"
        case .sawAnswer(let n): "\(n) saw the answer"
        case .alreadyKnew(let n): "+\(n) already knew"
        case .missed(let n): "\(n) not done yet"
        case .helped(let n): "\(n) needed help"
        case .regressed(let n): "\(n) to practise again"
        case .newlyVerified(let n): "\(n) newly verified"
        case .verifiedHint: "Verified needs right answers in 2 sessions at least 24 h apart"
        case .weakDelta(let delta): "\(ResultTile.Line.signed(delta)) after this session"
        case .weakPending(let n): "\(n) to confirm after 12 h"
        }
    }

    /// "−3" / "+2", with a real minus sign.
    static func signed(_ value: Int) -> String {
        value < 0 ? "\u{2212}\(abs(value))" : "+\(value)"
    }
}
