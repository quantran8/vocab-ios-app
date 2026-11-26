import RiveRuntime
import SwiftUI

/// First screen on launch: Syllie blinking, nothing else. `AppRootView` keeps it up for at least
/// `MotionTokens.splashHold` and until the account has loaded, so no loading screen flashes in between.
///
/// Syllie sits exactly where the static launch screen draws `LaunchSyllieV2` (centred on the full screen, body
/// 169 pt wide, image 175×130 pt centred on the body), so the hand-off from the launch screen doesn't jump.
struct SplashView: View {
    @Environment(\.motion) private var motion
    // The `Syllie` state machine has no blink-only mood: play the `loading_blink` timeline (the `Blink` layer of
    // `LoadingFly`) on its own.
    @StateObject private var syllie = RiveViewModel(
        fileName: "syllie", animationName: "loading_blink", fit: .contain, artboardName: "Syllie"
    )

    var body: some View {
        syllie.view()
            // `Syllie` artboard (520×430) at the scale that makes the body as wide as `LaunchSyllieV2`.
            .frame(width: 217, height: 179)
            // The body isn't centred in the artboard: move it onto the screen centre.
            .offset(x: 4.5, y: -17.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Syll"))
            .onAppear {
                if motion.reduceMotion {
                    syllie.pause()
                } else {
                    syllie.play(animationName: "loading_blink", loop: .loop)
                }
            }
    }
}

#Preview {
    SplashView()
        .background(Color.canvas)
}
