import SwiftUI

/// Weekly leaderboard (spec §4, §10). This week's LP and rank stay apart from the lifetime Tier,
/// and nothing here pressures: no "falling behind", no timer on Home, no rank on the session results.
struct RankingView: View {
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner
    @Environment(\.motion) private var motion
    @State private var view: LeaderboardView = .top
    @State private var showsIntro = false
    @State private var isEditingProfile = false
    @State private var reportTarget: LeaderboardRow?
    @State private var notice: String?
    @State private var showsLPInfo = false

    private var isVisible: Bool { learner.profile?.settings.leaderboardVisible ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Weekly ranking")
                if let mine = ranking.mine {
                    Text(verbatim: weekSubtitle(mine))
                        .font(Typography.secondary)
                        .foregroundStyle(Color.mutedInk)
                        .padding(.top, Spacing.xs - 2)
                }
                if let mine = ranking.mine {
                    statsCard(mine)
                        .padding(.top, Spacing.l)
                } else if ranking.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.l)
                }
                if let error = ranking.error {
                    message(Text(verbatim: error))
                        .padding(.top, Spacing.l)
                }
                if ranking.isBoardClosed {
                    closedCard
                        .padding(.top, Spacing.l)
                } else if ranking.mine != nil {
                    if !isVisible {
                        joinCard
                            .padding(.top, Spacing.l)
                    }
                    board
                        .padding(.top, Spacing.l)
                }
                if let notice {
                    message(Text(verbatim: notice))
                        .padding(.top, Spacing.m)
                }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.canvas)
        .refreshable { await ranking.refreshRanking() }
        .task {
            await ranking.refreshRanking()
            if learner.profile?.rankingIntroSeen == false, !ranking.isBoardClosed { showsIntro = true }
        }
        .sheet(isPresented: $showsIntro) {
            RankingIntroSheet { isEditingProfile = true }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditPublicProfileSheet()
        }
        .sheet(item: $reportTarget) { row in
            ReportPlayerSheet(username: row.username, reasons: ranking.reportReasons) { reason in
                reportTarget = nil
                report(row, reason)
            }
        }
    }

    // MARK: This week

    /// "09–15/11 · Resets Monday, 07:00": the ISO week in UTC, the reset in device time.
    private func weekSubtitle(_ mine: MyRanking) -> String {
        let locale = AppLanguage.active.locale
        let reset = mine.weekEndsAt.formatted(.dateTime.weekday(.wide).hour().minute().locale(locale))
        guard let range = WeekLabel.range(mine.weekStart) else {
            return String(localized: "Resets \(reset)", bundle: .appLanguage)
        }
        return String(localized: "\(range) · Resets \(reset)", bundle: .appLanguage)
    }

    private func statsCard(_ mine: MyRanking) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                positionValue(mine)
                Text(mine.position?.kind == .percentile ? "Estimated" : "Weekly rank")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(Color.mutedInk)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Rectangle()
                .fill(Color.divider)
                .frame(width: Borders.hairline)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs - 2) {
                    Image(systemName: "bolt.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.reward)
                        .accessibilityHidden(true)
                    Text(mine.weeklyLP, format: .number.locale(AppLanguage.active.locale))
                        .font(Typography.stat.monospacedDigit())
                        .tracking(Typography.tightTracking)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                HStack(spacing: Spacing.xxs) {
                    Text("LP this week")
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(Color.mutedInk)
                    lpInfoButton
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardSurface()
    }

    @ViewBuilder
    private func positionValue(_ mine: MyRanking) -> some View {
        switch mine.position?.kind {
        case .rank?:
            if let rank = mine.position?.rank {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(verbatim: "#\(rank)")
                        .font(Typography.stat.monospacedDigit())
                        .tracking(Typography.tightTracking)
                        .foregroundStyle(Color.ink)
                    if let total = mine.totalListed, total >= rank {
                        Text(verbatim: "/ \(total)")
                            .font(Typography.emphasis.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.mutedInk)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } else {
                noPosition
            }
        case .percentile?:
            if let percentile = mine.position?.percentile {
                Text("About top \(percentText(percentile))")
                    .font(Typography.screenTitle.weight(.heavy))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                noPosition
            }
        default:
            noPosition
        }
    }

    private var noPosition: some View {
        Text(verbatim: "–")
            .font(Typography.stat)
            .foregroundStyle(Color.mutedInk)
            .accessibilityLabel(Text("Not on the board"))
    }

    private var lpInfoButton: some View {
        Button {
            showsLPInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(Color.mutedInk)
                .frame(minWidth: Spacing.minTouchTarget, minHeight: Spacing.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -Spacing.s)
        .accessibilityLabel(Text("About LP"))
        .popover(isPresented: $showsLPInfo) {
            Text("You earn LP by learning new words, reviewing words when they’re due and practising extra. Right and wrong answers earn the same. Weekly LP starts again every Monday.")
                .font(Typography.secondary)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.m)
                .frame(width: 280, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func percentText(_ value: Int) -> String {
        (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.active.locale))
    }

    // MARK: Board

    private var closedCard: some View {
        message(Text("The leaderboard opens soon. Your LP and Tier already count."))
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("You’re not on the leaderboard")
                .font(Typography.emphasis)
                .foregroundStyle(Color.ink)
            Text("If you join, your name, avatar, Tier and LP this week are public.")
                .font(Typography.secondary)
                .foregroundStyle(Color.bodyInk)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Join the leaderboard") { setVisible(true) }
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.m)
        .cardSurface()
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SegmentedControl(
                options: [(value: LeaderboardView.top, title: "All"), (value: LeaderboardView.around, title: "Around me")],
                selection: $view
            )

            let rows = view == .top ? ranking.top : ranking.around
            if rows.isEmpty {
                Text(view == .around
                     ? (isVisible ? "Earn LP this week to appear on the board." : "Join the leaderboard to see who’s around you.")
                     : "Nobody is on the board yet this week.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .padding(.vertical, Spacing.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            if Self.skipsRanks(after: rows[index - 1], to: row) {
                                CardDivider()
                                rankGap
                            }
                            CardDivider()
                        }
                        LeaderboardRowView(row: row, onMore: reportAction(for: row))
                    }
                }
                .cardSurface()
            }
        }
    }

    /// The ⋯ button reports a player; the learner's own row has none.
    private func reportAction(for row: LeaderboardRow) -> (() -> Void)? {
        guard !row.isMe else { return nil }
        return { reportTarget = row }
    }

    /// Ranks that aren't next to each other (top three, then the learner's neighbours) get a "···" gap.
    private static func skipsRanks(after previous: LeaderboardRow, to row: LeaderboardRow) -> Bool {
        guard let before = previous.rank, let rank = row.rank else { return false }
        return rank > before + 1
    }

    private var rankGap: some View {
        Text(verbatim: "···")
            .font(Typography.secondary.weight(.bold))
            .foregroundStyle(Color.ink300)
            .frame(maxWidth: .infinity, minHeight: Spacing.xl)
            .accessibilityHidden(true)
    }

    // MARK: Actions

    private func message(_ text: Text) -> some View {
        text
            .font(Typography.secondary)
            .foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.neutralSurface, in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
    }

    private func setVisible(_ visible: Bool) {
        Task {
            do {
                try await ranking.setVisible(visible)
                notice = nil
            } catch {
                notice = error.asAPIError.userMessage
            }
        }
    }

    private func report(_ row: LeaderboardRow, _ reason: ReportReason) {
        Task {
            do {
                try await ranking.report(username: row.username, reason: reason)
                notice = String(localized: "Thanks. We’ll take a look.", bundle: .appLanguage)
            } catch {
                notice = error.asAPIError.userMessage
            }
        }
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    /// Opens the report sheet; nil for the learner's own row.
    var onMore: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Group {
                    if let rank = row.rank { Text(verbatim: "\(rank)") } else { Text(verbatim: "–") }
                }
                .font(Typography.body.weight(.heavy).monospacedDigit())
                .foregroundStyle(row.rank == 1 ? Color.sun600 : Color.ink400)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: Spacing.l + Spacing.xxs)
                AvatarView(key: row.avatarKey, size: Spacing.iconBadge, initial: row.username)
                Text(verbatim: row.username)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if row.isMe {
                    StatusPill("You", tone: .accentSolid)
                }
                Text("\(row.weeklyLP) LP")
                    .font(Typography.secondary.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            if let onMore {
                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(Typography.secondary.weight(.bold))
                        .foregroundStyle(Color.ink400)
                        .frame(width: Spacing.l, height: Spacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.trailing, -Spacing.xs)
                .accessibilityLabel(Text("Actions for \(row.username)"))
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Spacing.tileMinHeight)
        .background(row.isMe ? Color.selectedSurface : Color.clear)
    }
}

/// Report a player from the leaderboard's ⋯ button: one reason per row, Cancel always visible.
struct ReportPlayerSheet: View {
    let username: String
    let reasons: [ReportReason]
    let onReport: (ReportReason) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                IconBadge(systemImage: "flag", tone: .error, size: Spacing.fieldHeight)
                    .clipShape(Circle())
                Text("Report \(username)?")
                    .font(Typography.screenTitle.weight(.heavy))
                    .tracking(Typography.tightTracking)
                    .foregroundStyle(Color.ink)
                    .padding(.top, Spacing.m)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(reasons.enumerated()), id: \.element.id) { index, reason in
                        if index > 0 { CardDivider() }
                        Button {
                            onReport(reason)
                        } label: {
                            CardRow {
                                Text(reason.title)
                                    .font(Typography.body.weight(.semibold))
                                Spacer(minLength: Spacing.xs)
                                Image(systemName: "chevron.right")
                                    .font(Typography.micro.weight(.bold))
                                    .foregroundStyle(Color.ink400)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardSurface()
                .padding(.top, Spacing.l)
                SecondaryButton(title: "Cancel") { dismiss() }
                    .padding(.top, Spacing.m)
            }
            .padding(.horizontal, Spacing.practiceGutter)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
    }
}

/// Ranking weeks start Monday 00:00 UTC, so their dates read in UTC whatever the device zone.
enum WeekLabel {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Monday to Sunday of the week, e.g. "09–15/11".
    static func range(_ weekStart: String) -> String? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let start = parser.date(from: weekStart),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else { return nil }
        let formatter = DateIntervalFormatter()
        formatter.locale = AppLanguage.active.locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateTemplate = "ddMM"
        return formatter.string(from: start, to: end)
    }
}

extension ReportReason {
    var title: LocalizedStringKey {
        switch self {
        case .offensiveName: "Offensive name"
        case .impersonation: "Pretending to be someone else"
        case .suspiciousActivity: "Suspicious activity"
        case .other: "Something else"
        }
    }
}

/// First visit: what the leaderboard is and what becomes public. Seeing it never opts in (spec §4.3).
struct RankingIntroSheet: View {
    let onEditProfile: () -> Void
    @Environment(RankingStore.self) private var ranking
    @Environment(LearnerStore.self) private var learner
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .top) {
                    SheetTitle("Weekly leaderboard")
                    Spacer(minLength: Spacing.xs)
                    SheetCloseButton()
                }
                Text("Compare the LP you earn this week with other learners. It starts again every Monday.")
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let profile = learner.profile, let username = profile.username {
                    HStack(spacing: Spacing.s) {
                        AvatarView(key: profile.avatarKey ?? "", size: Spacing.fieldHeight, initial: username)
                        Text(verbatim: username)
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                }
                Label("If you join, your name, avatar, Tier and LP this week are public. Your email, level and words are never shown.",
                      systemImage: "eye")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let error {
                    Text(verbatim: error)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.errorInk)
                }
                PrimaryButton(title: "Join", isEnabled: !isJoining, action: join)
                SecondaryButton(title: "Edit name and avatar") {
                    dismiss()
                    onEditProfile()
                }
                SecondaryButton(title: "Not now") { dismiss() }
            }
            .padding(.horizontal, Spacing.screenGutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .task { await ranking.markIntroSeen() }
    }

    private func join() {
        isJoining = true
        Task {
            defer { isJoining = false }
            do {
                try await ranking.setVisible(true)
                dismiss()
            } catch {
                self.error = error.asAPIError.userMessage
            }
        }
    }
}
