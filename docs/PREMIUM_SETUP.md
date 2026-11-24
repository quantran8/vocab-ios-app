# Premium setup (App Store)

The app sells Syll Premium only through the App Store. The backend is the source of truth: it verifies every signed transaction and listens to App Store Server Notifications V2. Contract: `vocab-backend/docs/FRONTEND_FLOW.md` §16.

## App Store Connect

1. **Agreements:** the Paid Apps agreement, tax and banking must be active, or products never load.
2. **Subscription group** "Syll Premium" with two auto-renewable subscriptions:
   - `syll.premium.yearly` (1 year, level 1), optional free trial as an introductory offer
   - `syll.premium.monthly` (1 month, level 2)
   The ids must match `PremiumProduct` (iOS), the backend's `APPSTORE_PRODUCT_IDS` and `Syll.storekit`.
3. **App Store Server Notifications** (App Information → App Store Server Notifications), version 2, the same URL for Production and Sandbox:
   `https://<backend host>/v1/appstore/notifications`
   Use "Request a Test Notification" to check that it answers 200.
4. **Review information:** a screenshot of `PaywallView`, and a privacy policy URL. Put the same URL in `VocabFlow-Info.plist` as `PrivacyPolicyURL` so the paywall links it (Terms use Apple's standard EULA).

No App Store Server API key is needed: the backend checks the signatures locally.

## Backend

| Variable | Value |
| --- | --- |
| `FREEMIUM_ENABLED` | `true` once an app build with the paywall is live. Off, nobody is limited |
| `FREE_MAX_TOPICS`, `FREE_MAX_NEW_WORDS` | Free plan limits (default 3 and 150) |
| `REDEEM_ENABLED` | `true` to let learners redeem codes |
| `APPSTORE_BUNDLE_ID` | `com.visiongroup.syll` |
| `APPSTORE_PRODUCT_IDS` | `syll.premium.monthly,syll.premium.yearly` |
| `APPSTORE_ALLOW_XCODE` | Local only: accepts Xcode StoreKit-testing transactions |

Redeem codes (full admins): `POST /admin/redeem-codes {code, durationDays, maxUses?, expiresAt?, note?}`, `GET /admin/redeem-codes`, `POST /admin/redeem-codes/{code}/disable`.

## Local testing

1. Xcode → Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration: `Syll.storekit`.
2. Run the local backend with `FREEMIUM_ENABLED=true` and `APPSTORE_ALLOW_XCODE=true`.
3. Buy in the simulator; `/me` should turn `premium`. Debug → StoreKit → Manage Transactions can refund or expire, but Xcode doesn't send server notifications: test renewals, expiry and refunds with Sandbox on a device.

## Sandbox (device)

Create a Sandbox tester in App Store Connect and sign in under Settings → App Store → Sandbox Account. Sandbox renews monthly plans every few minutes, so renewal, expiry and grace-period notifications arrive quickly. Production accepts Sandbox transactions (App Review buys in Sandbox).
