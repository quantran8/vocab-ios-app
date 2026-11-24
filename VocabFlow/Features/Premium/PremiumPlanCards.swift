import StoreKit
import SwiftUI

/// Profile 6.6: the upgrade card right under the account block while the learner isn't Premium. The paywall's wash,
/// a 2 pt Grape 200 border, the Premium badge, one line of benefits, the free words used on a Grape bar and the Sun
/// Premium button (its one action). No close button: it goes only when the server says the learner is Premium.
struct ProfileUpgradeCard: View {
    let limits: PremiumPlan.Limits?
    let onUpgrade: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.s - 2) {
                PremiumBadge(size: 34)
                Text("Upgrade to Premium")
                    .font(Typography.wordClass.weight(.heavy))
                    .tracking(Typography.tightTracking / 2)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text("Unlimited new words, every topic, a score for every syllable, no ads.")
                .font(Typography.secondary)
                .foregroundStyle(Color.ink700)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs - 2)
            if let limits {
                Text("\(limits.newWordsUsed) of \(limits.maxNewWords) free words used")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.ink700)
                    .padding(.top, Spacing.s)
                GeometryReader { proxy in
                    let fraction = limits.maxNewWords > 0 ? min(Double(limits.newWordsUsed) / Double(limits.maxNewWords), 1) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white)
                        Capsule().fill(Color.grape500).frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 8)
                .padding(.top, Spacing.xs - 2)
                .accessibilityHidden(true)
            }
            PrimaryButton(title: "Upgrade to Premium", systemImage: "crown.fill", kind: .premium, action: onUpgrade)
                .padding(.top, Spacing.m)
        }
        .padding(Spacing.m)
        .background(PremiumGradient.wash, in: shape)
        .overlay(shape.strokeBorder(Color.grape200, lineWidth: Borders.card))
    }
}

/// Profile 6.6a: the plan card of a Premium learner, in the upgrade card's place. A quiet status, not a sales card:
/// Grape 50 (no Coral), a 2 pt Grape 200 border, the Premium badge, "Premium", the renewal or end date and a ›.
/// Tapping opens "Your plan" (`PremiumPlanSheet`); Profile has no other Premium action.
struct ProfilePremiumCard: View {
    let plan: PremiumPlan?
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                PremiumBadge()
                VStack(alignment: .leading, spacing: Spacing.xxs / 2) {
                    Text(verbatim: "Premium")
                        .font(Typography.wordClass.weight(.heavy))
                        .foregroundStyle(Color.ink)
                    if let line = PremiumPlanText.dateLine(plan) {
                        Text(line)
                            .font(Typography.micro)
                            .foregroundStyle(Color.mutedInk)
                    }
                }
                Spacer(minLength: Spacing.s)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.ink400)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.grape50, in: shape)
            .overlay(shape.strokeBorder(Color.grape200, lineWidth: Borders.card))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Your plan"))
    }
}

/// The plan's dates as Profile and "Your plan" show them.
enum PremiumPlanText {
    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.active.locale))
    }

    /// "Renews 23 Nov 2027" for an App Store plan that renews, otherwise "Until …".
    static func dateLine(_ plan: PremiumPlan?) -> LocalizedStringKey? {
        guard let until = plan?.premiumUntil else { return nil }
        return plan?.autoRenew == true ? "Renews \(date(until))" : "Until \(date(until))"
    }
}

/// 6.6b "Your plan": a sheet sized to its content. An info card (plan, renewal or end date, App Store price), one line about
/// cancelling in the App Store, the links "Restore purchases" and "Redeem a code" (while the server allows it), and the
/// outline "Manage subscription" pinned at the bottom (the App Store's manage sheet). A redeemed plan shows "Expires"
/// instead of "Renews", and has no price and no manage button.
struct PremiumPlanSheet: View {
    @Environment(LearnerStore.self) private var learner
    @Environment(PurchaseStore.self) private var purchases
    @State private var isRedeeming = false
    @State private var isManaging = false

    var body: some View {
        let plan = learner.profile?.plan
        let isAppStore = plan?.source == .appstore
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    SheetCloseButton()
                }
                .padding(.top, Spacing.xs)

                SheetTitle("Your plan")

                VStack(spacing: 0) {
                    infoRow("Plan", value: planName(plan))
                    if let until = plan?.premiumUntil {
                        CardDivider()
                        infoRow(isAppStore && plan?.autoRenew == true ? "Renews" : "Expires", value: Text(verbatim: PremiumPlanText.date(until)))
                    }
                    if isAppStore, let price = price(plan) {
                        CardDivider()
                        infoRow("Price", value: price)
                    }
                }
                .cardSurface()
                .padding(.top, Spacing.l - 4)

                if isAppStore {
                    Text("Your plan is managed in the App Store. Cancel at least 24 hours before it renews to avoid being charged for the next period.")
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.s)
                }

                HStack(spacing: Spacing.l) {
                    Button("Restore purchases") { Task { await purchases.restore() } }
                        .disabled(purchases.activity != .idle)
                    if learner.canRedeem {
                        Button("Redeem a code") { isRedeeming = true }
                    }
                }
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(Color.link)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                .padding(.top, Spacing.s)

                if let notice = purchases.notice, purchases.activity == .idle {
                    Text(verbatim: notice)
                        .font(Typography.micro)
                        .foregroundStyle(Color.mutedInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isAppStore {
                    SecondaryButton(title: "Manage subscription", kind: .outline) { isManaging = true }
                        .padding(.top, Spacing.m)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
        .task {
            purchases.clearNotice()
            await purchases.loadOffers()
        }
        .sheet(isPresented: $isRedeeming) {
            RedeemCodeSheet()
        }
        .manageSubscriptionsSheet(isPresented: $isManaging)
    }

    private func infoRow(_ label: LocalizedStringKey, value: Text) -> some View {
        CardRow {
            Text(label)
                .foregroundStyle(Color.bodyInk)
            Spacer(minLength: Spacing.s)
            value
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func planName(_ plan: PremiumPlan?) -> Text {
        if plan?.productId == PremiumProduct.yearly { return Text(verbatim: "Syll Premium · ") + Text("Yearly") }
        if plan?.productId == PremiumProduct.monthly { return Text(verbatim: "Syll Premium · ") + Text("Monthly") }
        return Text(verbatim: "Syll Premium")
    }

    /// The App Store's price for the learner's product, once the offers have loaded.
    private func price(_ plan: PremiumPlan?) -> Text? {
        guard let offer = purchases.offers.first(where: { $0.id == plan?.productId }) else { return nil }
        switch offer.period {
        case .year: return Text("\(offer.displayPrice) / year")
        case .month: return Text("\(offer.displayPrice) / month")
        case .other: return Text(verbatim: offer.displayPrice)
        }
    }
}
