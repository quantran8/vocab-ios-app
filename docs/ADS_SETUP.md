# Ads setup (Google AdMob)

Free learners see one AdMob interstitial after every `features.adEverySessions` finished sessions (backend `AD_EVERY_SESSIONS`, default 3; 0 turns ads off). It shows only when the shell reappears after a session the learner just finished, never during one and never at launch. Premium has no ads.

## 1. Add the SDK (once, in Xcode)

File → Add Package Dependencies → `https://github.com/googleads/swift-package-manager-google-mobile-ads` (version 12 or later), add `GoogleMobileAds` to the VocabFlow target. It brings `UserMessagingPlatform` (consent). Until the package is added, `AdMobInterstitials` isn't compiled and the app uses `NoInterstitialAds`.

## 2. AdMob console

1. Create the iOS app and an **Interstitial** ad unit.
2. Privacy & messaging: create a **GDPR** message (and an **IDFA explainer** if you want one before the iOS prompt). The app shows them through UMP before any ad request.
3. Add `app-ads.txt` to the developer website listed on the App Store.

## 3. Info.plist (`VocabFlow-Info.plist`)

| Key | Value |
| --- | --- |
| `GADApplicationIdentifier` | Your AdMob app ID. The checked-in value is Google's **test** app ID |
| `AdMobInterstitialUnitID` | Your interstitial unit ID. The checked-in value is Google's **test** unit |
| `SKAdNetworkItems` | Google's `cstr6suwn9.skadnetwork` is in; add Google's full list of third-party buyers from the AdMob docs |
| `NSUserTrackingUsageDescription` | The ATT prompt text, translated in `InfoPlist.xcstrings` |

Replace both test IDs before release. Without `GADApplicationIdentifier` or the unit ID the SDK isn't started and no ads show.

## 4. App Store Connect

App Privacy: declare the data AdMob collects (Identifiers → Device ID, Usage Data → Advertising Data, Diagnostics) as used for third-party advertising and, if ATT is granted, tracking. The SDK ships its own privacy manifest.
