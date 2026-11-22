import SwiftUI

/// How a backend-scored Recording draws its word: sweeping while the take is scored, then coloured per syllable.
enum RecordingPromptStyle: Equatable {
    case scoring
    /// Nil-band segments (the text between syllables) stay ink.
    case scored([PronunciationSegment])
}

/// The prompt word of a backend-scored Recording. Fonts and alignment come from `TaskPromptView`.
struct RecordingPromptWord: View {
    let text: String
    let style: RecordingPromptStyle

    @Environment(\.motion) private var motion
    /// Syllables coloured so far; they take their colour in reading order once the score ring has filled.
    @State private var coloured = 0

    var body: some View {
        switch style {
        case .scoring:
            ScoringSweepText(text: text)
        case .scored(let segments):
            coloredText(segments)
                .accessibilityLabel(Text(verbatim: text))
                .accessibilityValue(Text(PronunciationSummary.text(for: segments)))
                .task(id: segments) { await revealColors(of: segments) }
        }
    }

    private func coloredText(_ segments: [PronunciationSegment]) -> Text {
        var syllableIndex = 0
        return segments.reduce(Text(verbatim: "")) { text, segment in
            guard let band = segment.band else {
                return text + Text(verbatim: segment.text).foregroundStyle(Color.ink)
            }
            defer { syllableIndex += 1 }
            let color = syllableIndex < coloured ? band.wordColor : Color.ink
            return text + Text(verbatim: segment.text).foregroundStyle(color)
        }
    }

    private func revealColors(of segments: [PronunciationSegment]) async {
        let count = segments.filter { $0.band != nil }.count
        guard !motion.reduceMotion, count > 0 else {
            coloured = count
            return
        }
        coloured = 0
        try? await Task.sleep(for: .seconds(MotionTokens.scoreRingFillDuration))
        for index in 1...count {
            guard !Task.isCancelled else { return }
            withAnimation(MotionTokens.syllableColor) { coloured = index }
            try? await Task.sleep(for: .seconds(MotionTokens.syllableColorStagger))
        }
    }
}

/// The word in Ink 300 with a light sweeping across it while the take is scored. Reduce Motion: no sweep.
private struct ScoringSweepText: View {
    let text: String

    @Environment(\.motion) private var motion

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(Color.ink300)
            .overlay {
                if !motion.reduceMotion {
                    TimelineView(.animation) { context in
                        let period = MotionTokens.scoringSweepPeriod
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                        GeometryReader { proxy in
                            let band = proxy.size.width * 0.5
                            LinearGradient(colors: [.clear, Color.ink50, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: band)
                                .offset(x: -band + (proxy.size.width + band) * phase)
                        }
                    }
                    .mask(Text(verbatim: text))
                    // The word is English: the sweep follows its reading order in every app language.
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
            .accessibilityLabel(Text(verbatim: text))
    }
}

/// The overall score in the mic's place: a ring that fills to the score while the number counts up.
struct PronunciationScoreRing: View {
    let score: Double
    let band: PronunciationBand

    @Environment(\.motion) private var motion
    @State private var shown: Double = 0

    static let size: CGFloat = 176
    private static let lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.neutralSurface, lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: min(max(shown, 0), 100) / 100)
                .stroke(band.ringColor, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CountingNumber(value: shown)
                .font(Typography.scoreHero)
                .tracking(Typography.displayTracking)
                .foregroundStyle(Color.ink)
        }
        .padding(Self.lineWidth / 2)
        .frame(width: Self.size, height: Self.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(PronunciationSummary.scoreText(score)))
        .onAppear {
            if motion.reduceMotion {
                shown = score
            } else {
                withAnimation(MotionTokens.scoreRingFill) { shown = score }
            }
        }
    }
}

/// A whole number that counts through the values in between while `value` animates.
private struct CountingNumber: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: "\(Int(value.rounded()))")
            .monospacedDigit()
    }
}

/// The feedback panel of a scored take: one line naming the syllables to practise, and "Details" that expands
/// the panel in place to every syllable's sounds and score.
struct PronunciationDetail: View {
    let syllables: [PronunciationSyllable]
    let passed: Bool

    @Environment(\.motion) private var motion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                // Like a sheet changing detent: one spring for opening and closing.
                motion.perform(MotionTokens.panelExpand) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.s) {
                    Text(PronunciationSummary.text(for: syllables))
                        .font(Typography.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) {
                        Text("Details")
                            .font(Typography.actionSmall)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isExpanded ? .isSelected : [])

            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(passed ? Color.green100 : Color.coral100)
                        .frame(height: 1.5)
                    ForEach(syllables.indices, id: \.self) { index in
                        row(syllables[index])
                    }
                }
                // The rows don't move on their own: the panel's edge reveals them as it grows, as a sheet's would.
                .transition(.opacity)
            }
        }
        .foregroundStyle(passed ? Color.successInk : Color.errorInk)
    }

    private func row(_ syllable: PronunciationSyllable) -> some View {
        HStack(spacing: Spacing.s) {
            Text(verbatim: syllable.text)
                .font(Typography.secondary.weight(.bold))
                .foregroundStyle(syllable.band.wordColor)
                .frame(minWidth: 56, alignment: .leading)
            Text(verbatim: PronunciationSummary.ipa(syllable.ipa))
                .font(Typography.secondary)
                .foregroundStyle(Color.mutedInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let score = syllable.score {
                Text(verbatim: "\(Int(score.rounded()))")
                    .font(Typography.secondary.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(syllable.band.wordColor)
            }
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }
}

/// Copy shared by the word's VoiceOver value, the panel line and the score ring.
enum PronunciationSummary {
    static func text(for segments: [PronunciationSegment]) -> String {
        summary(poor: segments.filter { $0.band == .poor }.map(\.text))
    }

    static func text(for syllables: [PronunciationSyllable]) -> String {
        summary(poor: syllables.filter { $0.band == .poor }.map(\.text))
    }

    static func scoreText(_ score: Double) -> String {
        let value = Int(score.rounded())
        return String(localized: "Pronunciation score: \(value)", bundle: .appLanguage)
    }

    /// The server may send the sounds with or without slashes.
    static func ipa(_ ipa: String?) -> String {
        guard let ipa, !ipa.isEmpty else { return "" }
        return ipa.hasPrefix("/") ? ipa : "/\(ipa)/"
    }

    private static func summary(poor: [String]) -> String {
        guard !poor.isEmpty else { return String(localized: "All sounds were good", bundle: .appLanguage) }
        let names = poor.formatted(.list(type: .and).locale(AppLanguage.active.locale))
        return String(localized: "Needs practice: \(names)", bundle: .appLanguage)
    }
}

extension PronunciationBand {
    var title: String {
        switch self {
        case .excellent: String(localized: "Excellent!", bundle: .appLanguage)
        case .good, .unknown: String(localized: "Good job", bundle: .appLanguage)
        case .fair: String(localized: "Almost there", bundle: .appLanguage)
        case .poor: String(localized: "Keep practicing", bundle: .appLanguage)
        }
    }

    var titleColor: Color {
        switch self {
        case .excellent, .good, .unknown: .green700
        case .fair: .sun700
        case .poor: .coral700
        }
    }

    var ringColor: Color {
        switch self {
        case .excellent, .good, .unknown: .green600
        case .fair: .sun600
        case .poor: .coral600
        }
    }
}

extension SyllableBand {
    var wordColor: Color {
        switch self {
        case .good: .green700
        case .poor: .coral600
        case .unknown: .ink
        }
    }
}
