import CoreHaptics
import UIKit

protocol FeedbackProviding {
    func selectionChanged()
    func success()
    func error()
}

/// Plays through its own `CHHapticEngine` rather than `UIFeedbackGenerator`, which stayed silent on device
/// alongside the app's audio session. The engine is started on first use and restarted whenever it stops.
final class FeedbackHaptics: FeedbackProviding {
    private var engine: CHHapticEngine?
    private var isRunning = false
    private lazy var patterns: (selection: CHHapticPattern?, success: CHHapticPattern?, error: CHHapticPattern?) = (
        Self.pattern([(0, 0.5, 0.7)]),
        Self.pattern([(0, 0.6, 0.4), (0.12, 1.0, 0.6)]),
        Self.pattern([(0, 0.8, 0.8), (0.1, 0.8, 0.8), (0.2, 1.0, 0.9)])
    )

    func selectionChanged() { play(patterns.selection) }
    func success() { play(patterns.success) }
    func error() { play(patterns.error) }

    private func play(_ pattern: CHHapticPattern?) {
        guard let pattern, let engine = runningEngine() else { return }
        do {
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // The engine can stop without calling `stoppedHandler` first (audio session change); retry once.
            isRunning = false
            guard let engine = runningEngine() else { return }
            try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        }
    }

    private func runningEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if engine == nil {
            guard let created = try? CHHapticEngine() else { return nil }
            created.playsHapticsOnly = true
            created.isAutoShutdownEnabled = true
            created.stoppedHandler = { [weak self] _ in
                DispatchQueue.main.async { self?.isRunning = false }
            }
            created.resetHandler = { [weak self] in
                DispatchQueue.main.async { self?.isRunning = false }
            }
            engine = created
        }
        if !isRunning {
            do {
                try engine?.start()
                isRunning = true
            } catch {
                return nil
            }
        }
        return engine
    }

    /// Transient taps as (time, intensity, sharpness).
    private static func pattern(_ taps: [(TimeInterval, Float, Float)]) -> CHHapticPattern? {
        let events = taps.map { time, intensity, sharpness in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: time
            )
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }
}

struct NoOpFeedback: FeedbackProviding {
    func selectionChanged() {}
    func success() {}
    func error() {}
}

/// Forwards to another provider only while haptics are switched on in Settings.
final class SettingsAwareFeedback: FeedbackProviding {
    var isEnabled = true
    private let base: FeedbackProviding

    init(base: FeedbackProviding) {
        self.base = base
    }

    func selectionChanged() {
        if isEnabled { base.selectionChanged() }
    }

    func success() {
        if isEnabled { base.success() }
    }

    func error() {
        if isEnabled { base.error() }
    }
}
