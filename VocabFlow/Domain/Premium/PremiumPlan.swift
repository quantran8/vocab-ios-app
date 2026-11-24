import Foundation

/// The learner's plan from `GET /me` (backend FRONTEND_FLOW §16). The server decides who is Premium;
/// the app only reads this and sends StoreKit transactions up.
struct PremiumPlan: Decodable, Equatable {
    enum Tier: String, LenientEnum {
        case free, premium
        static let fallback = Tier.free
    }

    enum Source: String, LenientEnum {
        case appstore, redeem, unknown
        static let fallback = Source.unknown
    }

    /// What the free tier still allows. Nil whenever nothing limits the learner.
    struct Limits: Decodable, Equatable {
        let maxTopics: Int
        let maxNewWords: Int
        let newWordsUsed: Int

        var newWordsLeft: Int { max(maxNewWords - newWordsUsed, 0) }
    }

    let tier: Tier
    var premiumUntil: Date? = nil
    var source: Source? = nil
    var productId: String? = nil
    var autoRenew: Bool? = nil
    var limits: Limits? = nil

    var isPremium: Bool { tier == .premium }
}

/// Server-side switches the app follows. Nil from an older backend: no freemium, no redeem.
struct AppFeatures: Decodable, Equatable {
    var freemiumEnabled: Bool? = nil
    var redeemEnabled: Bool? = nil
    /// Free learners see an interstitial after every this many finished sessions; 0 or nil means no ads.
    var adEverySessions: Int? = nil
}

/// `GET /me/learn-home` `freeAllowance`: present only while the free tier limits new words.
struct FreeAllowance: Decodable, Equatable {
    let used: Int
    let max: Int
    let remaining: Int
}

/// The App Store products that grant Premium. Must match the backend's `APPSTORE_PRODUCT_IDS`
/// and `Syll.storekit`.
enum PremiumProduct {
    static let monthly = "syll.premium.monthly"
    static let yearly = "syll.premium.yearly"
    static let ids = [yearly, monthly]
}
