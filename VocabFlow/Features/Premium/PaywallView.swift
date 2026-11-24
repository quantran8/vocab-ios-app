import SwiftUI

/// Why the paywall opened; it picks the subtitle, so the learner sees the limit they just met.
enum PaywallReason: Equatable {
    case general
    /// Tried to choose more topics than the free plan allows.
    case topics(max: Int)
    /// Tried to switch collection: the free plan keeps the first one saved (`FREE_COLLECTION_LOCKED`).
    case collection
    /// The free plan's new words are used up.
    case words(max: Int)
    /// A free take was checked on the device, without a pronunciation score.
    case speaking
}

/// The links App Review asks for next to a subscription. The privacy policy comes from Info.plist
/// (`PrivacyPolicyURL`); without it the link is left out.
enum PremiumLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static var privacy: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }
}

/// Premium sheet in two steps (redesign v1, 6.1 and 6.2), laid out after Brilliant's paywall in Syll's own materials and the
/// Premium identity: the Grape → Coral wash, a fan of word cards as the key visual, "Premium" in the signature gradient.
/// Step 1 compares Free and Premium (the Premium column a flat Grape block); step 2 shows both plans as cards.
/// Only the Sun Premium button is pinned. Prices and the trial come from StoreKit.
/// It closes itself once the server says the learner is Premium.
struct PaywallView: View {
    let reason: PaywallReason
    @Environment(PurchaseStore.self) private var purchases
    @Environment(LearnerStore.self) private var learner
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motion) private var motion
    @State private var step = Step.compare
    @State private var selectedID: String?
    @State private var isRedeeming = false

    private enum Step {
        case compare, plans
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step == .plans {
                    SheetBackButton { motion.perform(MotionTokens.transition) { step = .compare } }
                }
                Spacer()
                SheetCloseButton()
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.xs)

            ZStack {
                switch step {
                case .compare:
                    PaywallCompareStep(reason: reason)
                        .transition(motion.stepTransition(isMovingBack: { step == .compare }))
                case .plans:
                    PaywallPlansStep(selectedID: $selectedID, onRedeem: { isRedeeming = true })
                        .transition(motion.stepTransition(isMovingBack: { step == .compare }))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(alignment: .top) {
            PremiumWash().ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radii.sheet)
        .presentationBackground(Color.surface)
        .task {
            purchases.clearNotice()
            await purchases.loadOffers()
            if selectedID == nil {
                selectedID = (purchases.offers.first { $0.period == .year } ?? purchases.offers.first)?.id
            }
        }
        .onChange(of: purchases.didUnlock) { _, unlocked in
            guard unlocked else { return }
            purchases.acknowledgeUnlock()
            dismiss()
        }
        .onChange(of: learner.isPremium) { _, premium in
            if premium { dismiss() }
        }
        .sheet(isPresented: $isRedeeming) {
            RedeemCodeSheet()
        }
    }

    private var selectedOffer: PremiumOffer? {
        purchases.offers.first { $0.id == selectedID } ?? purchases.offers.first
    }

    /// Only the main action is pinned, like Brilliant: the Sun Premium button. Restore and redeem sit in the plan step's content.
    private var actionBar: some View {
        VStack(spacing: Spacing.xs) {
            switch step {
            case .compare:
                PrimaryButton(title: "See plans", systemImage: "crown.fill", kind: .premium) {
                    motion.perform(MotionTokens.transition) { step = .plans }
                }
            case .plans:
                if purchases.activity != .idle, purchases.activity != .loadingOffers {
                    ProgressView()
                }
                PrimaryButton(
                    title: selectedOffer?.freeTrial == nil ? "Subscribe" : "Start free trial",
                    systemImage: "crown.fill",
                    isEnabled: selectedOffer != nil && purchases.activity == .idle,
                    kind: .premium
                ) {
                    guard let offer = selectedOffer else { return }
                    Task { await purchases.purchase(offer) }
                }
            }
        }
        .padding(.horizontal, Spacing.screenGutter)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.xs)
        .background(Color.surface)
        .overlay(alignment: .top) { CardDivider() }
    }
}

extension [PremiumOffer] {
    /// The yearly price against twelve months of the monthly plan, in whole percent; nil below 5% or without both.
    var yearlySavingPercent: Int? {
        guard let monthly = first(where: { $0.period == .month })?.price,
              let yearly = first(where: { $0.period == .year })?.price, monthly > 0 else { return nil }
        let saving = 1 - NSDecimalNumber(decimal: yearly).doubleValue / (NSDecimalNumber(decimal: monthly).doubleValue * 12)
        let percent = Int((saving * 100).rounded())
        return percent >= 5 ? percent : nil
    }
}

// MARK: - Key visual

/// A fan of vocabulary cards, no Syllie: three solid cards (Grape 500, Coral 400, Sun 400, each on its 700 edge) tilted
/// behind a white word card ("unlimited", its IPA and meaning), with two small Sun sparkles. The cards spread out
/// when the paywall opens; with Reduce Motion they are already spread.
private struct PremiumKeyVisual: View {
    var compact = false
    @Environment(\.motion) private var motion
    @State private var spread = false

    var body: some View {
        ZStack {
            backCard(.grape500, edge: .grape700, rotation: -16, x: -44, y: 6)
            backCard(.coral400, edge: .coral700, rotation: 13, x: 46, y: 4)
            backCard(.sun400, edge: .sun700, rotation: -5, x: -10, y: -10)
            wordCard
            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.sun500)
                .offset(x: 108, y: -66)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.sun500)
                .offset(x: -104, y: 60)
        }
        .frame(width: 260, height: 170)
        .scaleEffect(compact ? 0.72 : 0.8)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 132 : 150)
        .accessibilityHidden(true)
        .onAppear {
            if motion.reduceMotion {
                spread = true
            } else {
                motion.perform(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) { spread = true }
            }
        }
    }

    private func backCard(_ face: Color, edge: Color, rotation: Double, x: CGFloat, y: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        let amount: CGFloat = spread ? 1 : 0.15
        return shape.fill(face)
            .background(shape.fill(edge).offset(y: 5))
            .frame(width: 168, height: 108)
            .rotationEffect(.degrees(rotation * amount))
            .offset(x: x * amount, y: y * amount)
    }

    private var wordCard: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "unlimited")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.ink)
            Text(verbatim: "/ʌnˈlɪmɪtɪd/")
                .font(.system(size: 13))
                .foregroundStyle(Color.mutedInk)
                .padding(.top, Spacing.xxs)
            CardDivider()
                .padding(.top, Spacing.s - 2)
            Text("without limits")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s + 2)
        .frame(width: 176, alignment: .leading)
        .background(Color.surface, in: shape)
        .overlay(shape.strokeBorder(Color.stroke, lineWidth: Borders.card))
        .background(shape.fill(Color.stroke).offset(y: 5))
        .rotationEffect(.degrees(3))
        .offset(y: 6)
    }
}

/// A benefit Premium (or Free) includes: a flat Grape 500 disc with a white check. A missing one: a white ✕ on Ink 200.
private struct BenefitMark: View {
    let included: Bool

    var body: some View {
        if included {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(Color.grape500, in: Circle())
        } else {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Color.ink200, in: Circle())
        }
    }
}

// MARK: - Step 1: Free vs Premium

private struct PaywallCompareStep: View {
    let reason: PaywallReason
    @Environment(LearnerStore.self) private var learner
    @Environment(PurchaseStore.self) private var purchases

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PremiumKeyVisual()
                Text(verbatim: "Syll Premium")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.grape700)
                VStack(spacing: 0) {
                    Text("Learn without limits with")
                        .foregroundStyle(Color.ink)
                    PremiumWord()
                }
                .font(Typography.display)
                .tracking(Typography.displayTracking)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.xs - 2)
                if let line = reasonLine {
                    Text(line)
                        .font(Typography.body)
                        .foregroundStyle(Color.bodyInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xs)
                }

                table
                    .padding(.top, Spacing.m)

                if let notice = purchases.notice {
                    FieldErrorText(message: notice)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
    }

    /// The limit that opened the paywall; nothing from Settings.
    private var reasonLine: LocalizedStringKey? {
        switch reason {
        case .general: nil
        case .topics(let max): "The free plan includes \(max) topics. Upgrade to learn from every topic you like."
        case .collection: "The free plan keeps the first collection you chose. Upgrade to switch to any collection."
        case .words(let max): "You’ve learned your \(max) free words. Upgrade to keep learning new words."
        case .speaking: "Upgrade to get a pronunciation score and see how you said each syllable."
        }
    }

    private struct Row: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        var detail: Text?
        let free: Bool
        var isReason = false
    }

    /// From what Free has to what it doesn't (✓ before ✕); among the ✕ rows the limit just met leads, in bold with its free amount.
    private var rows: [Row] {
        let limits = learner.freeLimits
        var rows = [
            Row(id: 0, title: "Daily lessons and reviews", free: true),
            Row(id: 1, title: "Unlimited new words", detail: limits.map { Text("Free: \($0.maxNewWords) words") }, free: false,
                isReason: { if case .words = reason { true } else { false } }()),
            // Scope: the free plan keeps one collection and `maxTopics` of its topics.
            Row(id: 2, title: "Every collection and topic", detail: limits.map { Text("Free: 1 collection, \($0.maxTopics) topics") }, free: false,
                isReason: { switch reason { case .topics, .collection: true; default: false } }()),
            Row(id: 3, title: "Pronunciation score", detail: Text("For every syllable"), free: false, isReason: reason == .speaking),
        ]
        if (learner.profile?.features?.adEverySessions ?? 0) > 0 {
            rows.append(Row(id: 4, title: "No ads", free: false))
        }
        return rows.filter(\.free)
            + rows.filter { !$0.free && $0.isReason }
            + rows.filter { !$0.free && !$0.isReason }
    }

    private static let rowHeight: CGFloat = 54
    private static let freeWidth: CGFloat = 78
    private static let premiumWidth: CGFloat = 96
    /// The Grape band around the Premium column's white inside.
    private static let band: CGFloat = 7

    private var table: some View {
        let rows = rows
        return HStack(alignment: .bottom, spacing: 0) {
            // Benefits
            VStack(alignment: .leading, spacing: 0) {
                Text("Benefits")
                    .font(Typography.body.weight(.heavy))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
                    .padding(.bottom, Spacing.xs)
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title)
                            .font(Typography.secondary.weight(row.isReason ? .bold : .regular))
                            .foregroundStyle(Color.ink)
                        if row.isReason, let detail = row.detail {
                            detail
                                .font(Typography.caption)
                                .foregroundStyle(Color.mutedInk)
                        }
                    }
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Self.rowHeight)
                    .overlay(alignment: .top) { CardDivider() }
                }
            }

            // Free: an Ink 50 strip, a little shorter than Premium.
            VStack(spacing: 0) {
                Text("Free")
                    .font(Typography.secondary.weight(.bold))
                    .foregroundStyle(Color.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .bottom)
                    .padding(.bottom, Spacing.xs)
                ForEach(rows) { row in
                    BenefitMark(included: row.free)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.rowHeight)
                        .overlay(alignment: .top) { Rectangle().fill(Color.surface).frame(height: Borders.hairline) }
                }
            }
            .frame(width: Self.freeWidth)
            .background(Color.ink50, in: UnevenRoundedRectangle(topLeadingRadius: Radii.tile + 2, topTrailingRadius: Radii.tile + 2, style: .continuous))

            // Premium: a taller flat Grape 500 block, its title in white on the band, a white inside for the checks.
            VStack(spacing: 0) {
                Text(verbatim: "Premium")
                    .font(Typography.body.weight(.heavy))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                    .padding(.bottom, Spacing.s - 2)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, _ in
                        BenefitMark(included: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.rowHeight)
                            .overlay(alignment: .top) { if index > 0 { CardDivider() } }
                    }
                }
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Radii.card - Self.band, style: .continuous))
                .padding([.horizontal, .bottom], Self.band)
            }
            .frame(width: Self.premiumWidth)
            .background(Color.grape500, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .padding(.bottom, -Self.band)
        }
        .padding(.bottom, Self.band)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Premium includes every benefit in the list. The free plan includes daily lessons and reviews."))
    }
}

// MARK: - Step 2: plans

private struct PaywallPlansStep: View {
    @Binding var selectedID: String?
    let onRedeem: () -> Void
    @Environment(PurchaseStore.self) private var purchases
    @Environment(LearnerStore.self) private var learner
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PremiumKeyVisual(compact: true)
                Text("Choose your \(Text(verbatim: "Premium").foregroundStyle(PremiumGradient.accent)) plan")
                    .font(Typography.display)
                    .tracking(Typography.displayTracking)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xxs)
                Text("Learn without limits. Cancel anytime.")
                    .font(Typography.body)
                    .foregroundStyle(Color.bodyInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)

                if purchases.offers.isEmpty {
                    if purchases.activity == .loadingOffers {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight * 2)
                    }
                } else {
                    VStack(spacing: Spacing.m) {
                        ForEach(plans) { offer in
                            planCard(offer)
                        }
                    }
                    .padding(.top, Spacing.l - 4)
                }

                if let notice = purchases.notice {
                    FieldErrorText(message: notice)
                        .padding(.top, Spacing.s)
                }

                legal
                    .padding(.top, Spacing.l - 4)
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.bottom, Spacing.l)
        }
    }

    /// Yearly first (chosen by default), then monthly, then anything else the App Store sends.
    private var plans: [PremiumOffer] {
        let rank: (PremiumOffer.Period) -> Int = { $0 == .year ? 0 : $0 == .month ? 1 : 2 }
        return purchases.offers.sorted { rank($0.period) < rank($1.period) }
    }

    private var selectedOffer: PremiumOffer? {
        purchases.offers.first { $0.id == selectedID } ?? purchases.offers.first
    }

    /// The chosen plan: Grape 50 with a 2 pt Grape 500 border and a Grape check, no shadow. The other: white, Ink 200, an empty ring.
    /// The yearly card carries the real saving as a Coral pill over its top edge.
    private func planCard(_ offer: PremiumOffer) -> some View {
        let isOn = offer.id == selectedOffer?.id
        let shape = RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
        let monthly = purchases.offers.first { $0.period == .month }
        let saving = offer.period == .year ? purchases.offers.yearlySavingPercent : nil
        return Button {
            motion.perform(MotionTokens.snap) { selectedID = offer.id }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Group {
                        switch offer.period {
                        case .year: Text("Yearly")
                        case .month: Text("Monthly")
                        case .other: Text(verbatim: offer.displayName)
                        }
                    }
                    .font(Typography.wordClass.weight(.bold))
                    Spacer(minLength: Spacing.s)
                    if isOn {
                        BenefitMark(included: true)
                    } else {
                        Circle()
                            .strokeBorder(Color.ink300, lineWidth: Borders.card)
                            .frame(width: 28, height: 28)
                    }
                }
                switch offer.period {
                case .year:
                    priceLine(offer.monthlyDisplayPrice ?? offer.displayPrice)
                    HStack(spacing: Spacing.xs - 2) {
                        Text("12 months · \(offer.displayPrice)")
                        if saving != nil, let monthly {
                            Text(verbatim: (monthly.price * 12).formatted(monthly.priceFormat))
                                .strikethrough()
                                .foregroundStyle(Color.ink400)
                        }
                    }
                    .font(Typography.secondary.monospacedDigit())
                case .month:
                    priceLine(offer.displayPrice)
                    Text("Billed monthly")
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                case .other:
                    Text(verbatim: offer.displayPrice)
                        .font(.system(size: 30, weight: .heavy).monospacedDigit())
                }
                if let trial = offer.freeTrial {
                    Text("\(trial) free, then \(offer.displayPrice)")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(Color.grape800)
                        .padding(.horizontal, Spacing.s - 2)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.grape100, in: Capsule())
                        .padding(.top, Spacing.xs - 2)
                }
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Color.grape50 : Color.surface, in: shape)
            .overlay(shape.strokeBorder(isOn ? Color.grape500 : Color.stroke, lineWidth: Borders.card))
            .overlay(alignment: .topTrailing) {
                if let saving {
                    Text("Save \(saving)%")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Spacing.s)
                        .frame(height: 28)
                        .background(Color.coral500, in: Capsule())
                        .offset(x: -Spacing.xl - Spacing.l, y: -14)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// The price per month, large, with a smaller muted "/ month".
    private func priceLine(_ price: String) -> some View {
        Text("\(Text(verbatim: price).font(.system(size: 30, weight: .heavy)).tracking(-1).foregroundStyle(Color.ink)) / month")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(Color.mutedInk)
            .monospacedDigit()
    }

    private var legal: some View {
        VStack(spacing: Spacing.s) {
            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel them in your App Store account settings.")
                .font(Typography.caption)
                .foregroundStyle(Color.mutedInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.m) {
                Button("Restore purchases") { Task { await purchases.restore() } }
                    .disabled(purchases.activity != .idle)
                if learner.canRedeem {
                    Button("Have a code?", action: onRedeem)
                }
                Link("Terms of Use", destination: PremiumLinks.terms)
                if let privacy = PremiumLinks.privacy {
                    Link("Privacy Policy", destination: privacy)
                }
            }
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(Color.link)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

extension PaywallReason: Identifiable {
    var id: String {
        switch self {
        case .general: "general"
        case .topics: "topics"
        case .collection: "collection"
        case .words: "words"
        case .speaking: "speaking"
        }
    }
}
