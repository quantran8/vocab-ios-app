import Foundation
import StoreKit

/// A Premium product as the paywall shows it. Prices and names come from the App Store, already localized.
struct PremiumOffer: Identifiable, Equatable, Sendable {
    enum Period: Equatable, Sendable {
        case month, year, other
    }

    let id: String
    let displayName: String
    let displayPrice: String
    let period: Period
    /// A yearly plan's price per month, formatted like `displayPrice` (the storefront's currency). Nil otherwise.
    let monthlyDisplayPrice: String?
    /// For comparing plans ("Save 40%" and the struck-out twelve months); formatted with `priceFormat`.
    var price: Decimal = 0
    /// The storefront's currency format, so derived prices read like `displayPrice`.
    var priceFormat: Decimal.FormatStyle.Currency = .currency(code: "USD")
    /// "1 week free" and the like, when the learner is eligible for an introductory offer.
    let freeTrial: String?
}

/// A transaction StoreKit has verified. The backend verifies `signedTransaction` again; `finish` runs only after it answers.
struct VerifiedTransaction: Sendable {
    let id: UInt64
    let productID: String
    let signedTransaction: String
    let finish: @Sendable () async -> Void
}

enum PurchaseOutcome: Sendable {
    case purchased(VerifiedTransaction)
    /// Ask to Buy or a payment that needs action: it arrives later through `transactionUpdates`.
    case pending
    case cancelled
}

/// StoreKit 2 behind a protocol, so stores, tests and previews never touch the real App Store.
protocol StoreKitClient: Sendable {
    func offers(ids: [String]) async throws -> [PremiumOffer]
    func purchase(productID: String, accountToken: UUID) async throws -> PurchaseOutcome
    /// Every verified transaction made or changed outside a purchase call: renewals, Ask to Buy, other devices,
    /// and unfinished ones StoreKit delivers again at launch.
    func transactionUpdates() -> AsyncStream<VerifiedTransaction>
    /// The subscriptions the Apple ID is entitled to now.
    func currentEntitlements() async -> [VerifiedTransaction]
    /// "Restore purchases": asks the App Store for the latest transactions (may show a sign-in).
    func sync() async throws
}

struct LiveStoreKit: StoreKitClient {
    func offers(ids: [String]) async throws -> [PremiumOffer] {
        let products = try await Product.products(for: ids)
        var offers: [PremiumOffer] = []
        for product in products {
            offers.append(await Self.offer(product))
        }
        // The order the paywall lists them in: `ids`' order.
        return offers.sorted { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }
    }

    func purchase(productID: String, accountToken: UUID) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else { throw StoreKitError.unknown }
        switch try await product.purchase(options: [.appAccountToken(accountToken)]) {
        case .success(let result):
            guard let verified = Self.verified(result) else { throw StoreKitError.unknown }
            return .purchased(verified)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func transactionUpdates() -> AsyncStream<VerifiedTransaction> {
        AsyncStream { continuation in
            let task = Task.detached {
                for await result in Transaction.updates {
                    if let verified = Self.verified(result) { continuation.yield(verified) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func currentEntitlements() async -> [VerifiedTransaction] {
        var transactions: [VerifiedTransaction] = []
        for await result in Transaction.currentEntitlements {
            if let verified = Self.verified(result) { transactions.append(verified) }
        }
        return transactions
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    /// An unverified transaction is never sent up: the backend would refuse it anyway.
    private static func verified(_ result: VerificationResult<Transaction>) -> VerifiedTransaction? {
        guard case .verified(let transaction) = result else { return nil }
        return VerifiedTransaction(
            id: transaction.id,
            productID: transaction.productID,
            signedTransaction: result.jwsRepresentation,
            finish: { await transaction.finish() }
        )
    }

    private static func offer(_ product: Product) async -> PremiumOffer {
        let unit = product.subscription?.subscriptionPeriod
        let period: PremiumOffer.Period
        if let unit, unit.value == 1, unit.unit == .month {
            period = .month
        } else if let unit, unit.value == 1, unit.unit == .year {
            period = .year
        } else {
            period = .other
        }
        var trial: String?
        if let intro = product.subscription?.introductoryOffer, intro.paymentMode == .freeTrial,
           await product.subscription?.isEligibleForIntroOffer == true {
            trial = intro.period.formatted(product.subscriptionPeriodFormatStyle)
        }
        return PremiumOffer(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            period: period,
            monthlyDisplayPrice: period == .year ? (product.price / 12).formatted(product.priceFormatStyle) : nil,
            price: product.price,
            priceFormat: product.priceFormatStyle,
            freeTrial: trial
        )
    }
}

/// Previews and tests: no products, nothing to restore.
struct NoStoreKit: StoreKitClient {
    func offers(ids: [String]) async throws -> [PremiumOffer] { [] }
    func purchase(productID: String, accountToken: UUID) async throws -> PurchaseOutcome { .cancelled }
    func transactionUpdates() -> AsyncStream<VerifiedTransaction> { AsyncStream { $0.finish() } }
    func currentEntitlements() async -> [VerifiedTransaction] { [] }
    func sync() async throws {}
}
