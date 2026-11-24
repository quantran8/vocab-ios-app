#if canImport(GoogleMobileAds)
import AppTrackingTransparency
import GoogleMobileAds
import UIKit
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// Google AdMob interstitials (Google Mobile Ads SDK 12+). Compiled only once the `GoogleMobileAds` package is added
/// (docs/ADS_SETUP.md); until then the app uses `NoInterstitialAds`.
/// Order on first use: UMP consent form where the law asks for it, then the App Tracking Transparency prompt,
/// then the SDK starts. Without consent no ad is requested.
@MainActor
final class AdMobInterstitials: NSObject, InterstitialAdProviding, FullScreenContentDelegate {
    private let unitID: String
    private var ad: InterstitialAd?
    private var isLoading = false
    private var isPrepared = false
    private var dismissal: CheckedContinuation<Void, Never>?

    /// Nil when Info.plist has no `GADApplicationIdentifier` or `AdMobInterstitialUnitID`: the SDK would crash without the first.
    init?(bundle: Bundle = .main) {
        guard let appID = bundle.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String, !appID.isEmpty,
              let unitID = bundle.object(forInfoDictionaryKey: "AdMobInterstitialUnitID") as? String, !unitID.isEmpty
        else { return nil }
        self.unitID = unitID
    }

    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true
        #if canImport(UserMessagingPlatform)
        try? await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        if let root = Self.topViewController() {
            try? await ConsentForm.loadAndPresentIfRequired(from: root)
        }
        guard ConsentInformation.shared.canRequestAds else { return }
        #endif
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        await MobileAds.shared.start()
    }

    func preload() async {
        await prepare()
        #if canImport(UserMessagingPlatform)
        guard ConsentInformation.shared.canRequestAds else { return }
        #endif
        guard ad == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await InterstitialAd.load(with: unitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
        } catch {
            ad = nil
        }
    }

    func present() async -> Bool {
        guard let ad, let root = Self.topViewController() else { return false }
        self.ad = nil
        await withCheckedContinuation { continuation in
            dismissal = continuation
            ad.present(from: root)
        }
        return true
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finishPresenting() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finishPresenting() }
    }

    private func finishPresenting() {
        dismissal?.resume()
        dismissal = nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
