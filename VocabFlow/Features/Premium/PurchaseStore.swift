import Foundation
import Observation

/// Buying, restoring and syncing Premium through the App Store. The backend has the final say: every
/// verified transaction goes to `POST /me/subscriptions/appstore`, and a transaction is finished only once it answers.
/// An unfinished one comes back at the next launch through `transactionUpdates`, so nothing is lost offline.
@Observable
@MainActor
final class PurchaseStore {
    enum Activity: Equatable {
        case idle
        case loadingOffers
        case purchasing(productID: String)
        case restoring
    }

    private(set) var offers: [PremiumOffer] = []
    private(set) var activity: Activity = .idle
    /// A message for the paywall: a failure, or a purchase waiting for approval.
    private(set) var notice: String?
    /// Set after a purchase or restore made the learner Premium, so the paywall can close.
    private(set) var didUnlock = false

    private let client: StoreKitClient
    private let api: VocabAPI
    private let learner: LearnerStore
    private var updates: Task<Void, Never>?

    init(client: StoreKitClient, api: VocabAPI, learner: LearnerStore) {
        self.client = client
        self.api = api
        self.learner = learner
    }

    /// Call once at launch: StoreKit delivers renewals, Ask to Buy approvals and unfinished transactions here.
    func listen() {
        guard updates == nil else { return }
        let stream = client.transactionUpdates()
        updates = Task { [weak self] in
            for await transaction in stream {
                await self?.deliver(transaction)
            }
        }
    }

    /// After sign-in: sends what this Apple ID is entitled to, so a purchase made while signed out or on
    /// another device reaches this account. Quiet: failures wait for the next launch.
    func syncEntitlements() async {
        for transaction in await client.currentEntitlements() {
            await deliver(transaction)
        }
    }

    func loadOffers() async {
        guard offers.isEmpty, activity == .idle else { return }
        activity = .loadingOffers
        defer { activity = .idle }
        do {
            offers = try await client.offers(ids: PremiumProduct.ids)
            if offers.isEmpty { notice = String(localized: "Premium isn’t available right now. Please try again later.", bundle: .appLanguage) }
        } catch {
            notice = String(localized: "Couldn’t load the plans. Check your connection and try again.", bundle: .appLanguage)
        }
    }

    func purchase(_ offer: PremiumOffer) async {
        guard activity == .idle, let token = learner.accountToken else { return }
        activity = .purchasing(productID: offer.id)
        notice = nil
        defer { activity = .idle }
        do {
            switch try await client.purchase(productID: offer.id, accountToken: token) {
            case .purchased(let transaction):
                await deliver(transaction, reportsFailure: true)
            case .pending:
                notice = String(localized: "Your purchase is waiting for approval. Premium starts as soon as it’s approved.", bundle: .appLanguage)
            case .cancelled:
                break
            }
        } catch {
            notice = String(localized: "The purchase didn’t go through. You haven’t been charged.", bundle: .appLanguage)
        }
    }

    func restore() async {
        guard activity == .idle else { return }
        activity = .restoring
        notice = nil
        defer { activity = .idle }
        do {
            try await client.sync()
        } catch {
            notice = String(localized: "Couldn’t reach the App Store. Please try again.", bundle: .appLanguage)
            return
        }
        let transactions = await client.currentEntitlements()
        for transaction in transactions {
            await deliver(transaction, reportsFailure: true)
        }
        if !learner.isPremium, notice == nil {
            notice = String(localized: "No subscription found for this Apple ID.", bundle: .appLanguage)
        }
    }

    func clearNotice() {
        notice = nil
    }

    func acknowledgeUnlock() {
        didUnlock = false
    }

    /// The backend first, then `finish`. A transaction owned by another account is finished too:
    /// keeping it would only resend it forever. A network failure leaves it for StoreKit to deliver again.
    private func deliver(_ transaction: VerifiedTransaction, reportsFailure: Bool = false) async {
        guard learner.profile != nil else { return }
        let wasPremium = learner.isPremium
        do {
            let plan = try await api.syncAppStoreTransaction(signedTransaction: transaction.signedTransaction)
            await transaction.finish()
            await learner.adoptPlan(plan)
            if plan.isPremium, !wasPremium { didUnlock = true }
        } catch {
            let failure = error.asAPIError
            if failure.code == "APPSTORE_TRANSACTION_OWNED" || failure.code == "APPSTORE_TRANSACTION_INVALID" {
                await transaction.finish()
            }
            if reportsFailure { notice = failure.userMessage }
        }
    }
}
