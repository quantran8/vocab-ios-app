import SwiftUI

/// The Learn word introduction: centered spelling hero (animated unless turned off) with IPA and audio,
/// then Part of speech, Meaning, Definition and In context sections separated by dividers.
/// `.card` (live practice) puts the sections in one card, each under an eyebrow; `.flat` leaves them on the page.
struct WordIntroContent: View {
    enum Style { case flat, card }

    let word: VocabularyItem
    let presentation: IntroductionPresentation
    /// Plays recorded audio when there is some; otherwise the word is spoken by the device.
    var playAudio: (() -> Void)?
    /// Whether `playAudio`'s clip is playing right now, for the speaker waves.
    var isPlayingAudio = false
    var animatesWord = true
    var style: Style = .flat
    @Environment(SpeechPlayer.self) private var speech

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: style == .card ? Spacing.m : Spacing.xs) {
                IntroMotionHost(word: word.term, presentation: presentation, animates: animatesWord)
                WordPronunciation(
                    term: word.term,
                    ipa: word.ipa,
                    playAudio: playAudio,
                    isPlayingAudio: isPlayingAudio,
                    style: style == .card ? .hero : .standard
                )
            }
            // Flat: with the first section's top padding, this makes the 32pt gap between hero and information.
            // Card: mt-7 above the card.
            .padding(.bottom, style == .card ? Spacing.l + Spacing.xxs : Spacing.m)

            switch style {
            case .flat:
                sections
            case .card:
                sections
                    .padding(.horizontal, Spacing.m + Spacing.xxs)
                    .padding(.vertical, Spacing.xxs)
                    .cardSurface()
            }
        }
        .onDisappear { speech.stop() }
    }

    @ViewBuilder private var sections: some View {
        VStack(spacing: 0) {
            // Meaning is always present, so anchoring dividers on it keeps them strictly between sections.
            if let partOfSpeech = word.partOfSpeechLabel {
                section("Part of speech") {
                    Text(verbatim: partOfSpeech)
                        .font(Typography.wordClass)
                        .foregroundStyle(Color.ink)
                }
                divider
            }

            section("Meaning") {
                Text(verbatim: word.meaningVi)
                    .font(Typography.wordMeaning)
                    .tracking(style == .card ? Typography.tightTracking : 0)
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel(Text("Vietnamese meaning: \(word.meaningVi)"))
            }

            if let definition = word.definitionEN {
                divider
                section("Definition") {
                    Text(verbatim: definition)
                        .font(Typography.body)
                        .foregroundStyle(bodyColor)
                }
            }

            if !word.example.isEmpty {
                divider
                section("In context") {
                    VStack(alignment: .leading, spacing: style == .card ? Spacing.xs : Spacing.s) {
                        Text(style == .card ? Self.marked(word.term, in: word.example) : LearnView.highlight(word.term, in: word.example))
                            .font(Typography.body)
                            .foregroundStyle(bodyColor)
                        if let translation = word.exampleTranslation, !translation.isEmpty {
                            ExampleTranslation(text: translation)
                        }
                    }
                }
            }
        }
    }

    private var bodyColor: Color { style == .card ? .ink700 : .ink }

    /// Card style: 1.5 pt Ink 100 hairline; flat: the older 1 pt stroke.
    @ViewBuilder private var divider: some View {
        switch style {
        case .card:
            CardDivider()
        case .flat:
            Rectangle()
                .fill(Color.stroke)
                .frame(height: 1)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: style == .card ? Spacing.xs - 2 : Spacing.xs) {
            Eyebrow(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.m)
    }

    /// The word marked like a highlighter: Blue 100 behind bold Blue 800 text.
    private static func marked(_ term: String, in sentence: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        if let range = attributed.range(of: term, options: .caseInsensitive) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            attributed[range].foregroundColor = Color.blue800
            attributed[range].backgroundColor = Color.blue100
        }
        return attributed
    }
}

/// IPA next to the play button. Plays recorded audio when there is some; otherwise the device speaks the word.
struct WordPronunciation: View {
    /// `.hero` is the word intro card's: 44 pt Blue 50 button, Ink 600 IPA.
    enum Style { case standard, hero, compact }

    let term: String
    let ipa: String?
    var playAudio: (() -> Void)?
    /// Whether `playAudio`'s clip is playing right now. Without `playAudio` the device speech is watched instead.
    var isPlayingAudio = false
    var style: Style = .standard
    var usesWhiteSurface = false
    @Environment(SpeechPlayer.self) private var speech

    private var isPlaying: Bool { playAudio == nil ? (speech.isSpeaking && speech.spokenText == term && speech.spokenIPA == ipa) : isPlayingAudio }
    private var buttonSize: CGFloat { style == .hero ? 44 : 36 }
    /// Icon side: half the button.
    private var iconSide: CGFloat { style == .hero ? 22 : 18 }

    var body: some View {
        HStack(spacing: Spacing.s) {
            if let ipa {
                Text(verbatim: ipa)
                    .font(style == .compact ? Typography.ipaCard : Typography.body)
                    .foregroundStyle(style == .hero ? Color.bodyInk : Color.mutedInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text("IPA: \(ipa)"))
            }
            Button {
                if let playAudio {
                    playAudio()
                } else {
                    _ = speech.speak(term, ipa: ipa)
                }
            } label: {
                Group {
                    if playAudio != nil || speech.isAvailable {
                        SpeakerWaveIcon(isPlaying: isPlaying, side: iconSide)
                    } else {
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 22, weight: .medium))
                    }
                }
                .foregroundStyle((playAudio != nil || speech.isAvailable) ? (style == .hero ? Color.link : Color.interactive) : Color.disabledInk)
                .frame(width: buttonSize, height: buttonSize)
                .background((playAudio != nil || speech.isAvailable) ? (usesWhiteSurface ? Color.white : Color.selectedSurface) : Color.disabledSurface, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(playAudio == nil && !speech.isAvailable)
            .accessibilityLabel(Text((playAudio != nil || speech.isAvailable) ? "Play pronunciation" : "Audio unavailable"))
            .accessibilityValue(isPlaying ? Text("Playing") : Text(verbatim: ""))
        }
    }
}

/// The example's translation; its place under the sentence marks it, so it has no icon.
struct ExampleTranslation: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .accessibilityLabel(Text("Translation"))
            .accessibilityValue(Text(verbatim: text))
    }
}
