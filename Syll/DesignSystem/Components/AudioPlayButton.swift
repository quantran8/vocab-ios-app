import SwiftUI

/// User-triggered pronunciation control. Never autoplays and never reveals the answer in its label.
struct AudioPlayButton: View {
    let isSpeaking: Bool
    let isAvailable: Bool
    var isLarge = false
    let action: () -> Void

    var body: some View {
        let size: CGFloat = isLarge ? 128 : 44
        Button(action: action) {
            icon
                .foregroundStyle(isAvailable ? (isLarge ? Color.white : Color.blue600) : Color.disabledInk)
                .frame(width: size, height: size)
                .background(isAvailable ? (isLarge ? Color.interactive : Color.selectedSurface) : Color.disabledSurface, in: Circle())
                .background(Circle().fill(isLarge && isAvailable ? Color.interactiveDepth : Color.clear).offset(y: 5))
                .contentShape(Circle())
        }
        .buttonStyle(SoundControlButtonStyle(isRaised: isLarge))
        .disabled(!isAvailable)
        .frame(width: isLarge ? 176 : 44, height: isLarge ? 176 : 44)
        .accessibilityLabel(Text(isAvailable ? "Play pronunciation" : "Audio unavailable"))
        .accessibilityValue(isSpeaking ? Text("Playing") : Text(verbatim: ""))
        .accessibilityHint(isAvailable ? Text("Replays the word. You can play it as often as you like.") : Text("Use the written clue instead."))
    }

    @ViewBuilder private var icon: some View {
        if isAvailable {
            SpeakerWaveIcon(isPlaying: isSpeaking, side: isLarge ? 48 : 22)
        } else {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: isLarge ? 34 : 24, weight: .bold))
        }
    }
}

/// The raised sound control sinks to its depth edge while pressed.
struct SoundControlButtonStyle: ButtonStyle {
    var isRaised = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && isRaised && isEnabled ? 5 : 0)
            .scaleEffect(configuration.isPressed && !isRaised ? motion.pressedScale : 1)
            .animation(motion.animation(MotionTokens.press), value: configuration.isPressed)
    }
}
