import FamilyControls
import SwiftUI

/// 集中制限の設定画面。
///
/// 画面のルール一覧は `ScreenTimePolicyEvaluator.evaluate` の判定順とそろえている。
/// 上のルールほど先に判定され、下のルールは上のルールが成立した時点で使われない。
struct ScreenTimeSettingsScreen: View {
    @ObservedObject private var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController

    @State private var isShowingAllowedAppsPicker = false
    @State private var focusPickerSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var goalProgress: ScreenTimeDailyGoalProgress?
    @State private var isShowingTicketConfirmation = false
    @State private var editingSlot: ScheduleEditorTarget?
    @State private var isShowingLockSheet = false

    init(app: StudyAppContainer) {
        _app = ObservedObject(wrappedValue: app)
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    private var settings: ScreenTimeFocusSettings {
        focusController.settings
    }

    private var canEditSettings: Bool {
        !focusController.isSettingsLocked
    }

    /// 目標達成ルールがオンの間、タイマー・時間帯・チケットの判定には到達しない。
    private var goalRuleOverridesOthers: Bool {
        settings.unlockRestrictionsWhenDailyGoalReached
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusCard
                if settings.isEnabled, settings.ticketRestrictionEnabled {
                    ticketCard
                }
                rulesCard
                if settings.scheduledRestrictionEnabled {
                    scheduleSection
                }
                allowedAppsCard
                lockCard
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .strictScreen()
        .navigationTitle("集中制限")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            headerText: "集中制限中も使えるアプリとWebサイトを選択してください",
            footerText: "選択されていないアプリとWebサイトは集中制限中に開けなくなります。",
            isPresented: $isShowingAllowedAppsPicker,
            selection: $focusPickerSelection
        )
        .onChange(of: focusPickerSelection) { selection in
            guard canEditSettings else { return }
            // onAppear の同期代入で保存が走らないよう、実際に変化したときだけ書き込む。
            guard selection != settings.activitySelection else { return }
            applyFocusSettings { $0.activitySelection = selection }
        }
        .sheet(item: $editingSlot) { target in
            ScheduleSlotEditorSheet(
                focusController: focusController,
                slotID: target.id,
                canEdit: canEditSettings,
                onUpdate: { id, update in
                    updateScheduleSlot(id: id, update: update)
                },
                onDelete: { id in
                    removeScheduleSlot(id: id)
                }
            )
        }
        .sheet(isPresented: $isShowingLockSheet) {
            StrictLockSheet { months, days in
                activateStrictLock(months: months, days: days)
            }
        }
        .confirmationDialog(
            "チケットを1枚使います。よろしいですか？",
            isPresented: $isShowingTicketConfirmation,
            titleVisibility: .visible
        ) {
            Button("使う") {
                startTicket()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("開始すると10分間利用できます。途中で停止できず、使っていない時間も進みます。")
        }
        .task(id: app.dataVersion) {
            await refreshGoalProgress(reason: "screen-time-settings-data")
        }
        .onAppear {
            focusController.refresh()
            focusPickerSelection = settings.activitySelection
        }
        .task(id: focusController.ticketLedger?.activeTicketEndsAt) {
            guard let expiry = focusController.ticketLedger?.activeTicketEndDate else { return }
            let delay = max(expiry.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await refreshGoalProgress(reason: "screen-time-ticket-expired")
        }
    }

    // MARK: - いまの状態

    private var statusCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 13) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 44, height: 44)
                        .background(statusColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusHeadline(at: context.date))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(statusDetail(at: context.date))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    if focusController.isAuthorized {
                        Toggle(
                            "集中制限を使用",
                            isOn: Binding(
                                get: { settings.isEnabled },
                                set: { enabled in
                                    applyFocusSettings { $0.isEnabled = enabled }
                                }
                            )
                        )
                        .labelsHidden()
                        .tint(AppColors.success)
                        .disabled(!canEditSettings)
                    }
                }

                if focusController.isAvailable, !focusController.isAuthorized {
                    Button {
                        requestScreenTimeAuthorization()
                    } label: {
                        Label("Screen Timeを許可して始める", systemImage: "checkmark.shield.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(Color.white)
                            .background(AppColors.success, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if !warnings.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(warnings) { warning in
                            warningBanner(warning)
                        }
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var statusIcon: String {
        guard focusController.isAvailable, focusController.isAuthorized else {
            return "exclamationmark.shield.fill"
        }
        guard settings.isEnabled else { return "shield.slash.fill" }
        return isCurrentlyRestricted ? "lock.fill" : "lock.open.fill"
    }

    private var statusColor: Color {
        guard focusController.isAvailable, focusController.isAuthorized else {
            return AppColors.warning
        }
        guard settings.isEnabled else { return AppColors.textSecondary }
        return isCurrentlyRestricted ? AppColors.success : AppColors.blue
    }

    private var isCurrentlyRestricted: Bool {
        focusController.policyDecision?.isRestricted == true
    }

    private func statusHeadline(at date: Date) -> String {
        guard focusController.isAvailable else { return "この端末では使えません" }
        guard focusController.isAuthorized else { return "許可がまだです" }
        guard settings.isEnabled else { return "集中制限はオフ" }
        if let remaining = activeTicketRemainingText(at: date) {
            return "チケット利用中 \(remaining)"
        }
        return isCurrentlyRestricted ? "いま制限中" : "いま使えます"
    }

    private func statusDetail(at date: Date) -> String {
        guard focusController.isAvailable else {
            return "Screen TimeはiOS 16以降で利用できます。"
        }
        guard focusController.isAuthorized else {
            return "iPhoneのScreen Time機能を使って、勉強中の寄り道を防ぎます。"
        }
        guard settings.isEnabled else {
            return "右のスイッチをオンにすると、下のルールが動き始めます。"
        }
        if activeTicketRemainingText(at: date) != nil {
            return "終了すると再び制限されます。"
        }
        switch focusController.policyDecision?.reason {
        case .dailyGoalPending:
            return "今日の目標を達成するまで制限します（\(goalProgressText)）。"
        case .dailyGoalReached:
            return "今日の目標を達成したので、終日開放しています。"
        case .studyTimer:
            return "勉強タイマー中のため制限しています。"
        case .blockedSchedule:
            if let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart {
                return "使用禁止の時間帯です。次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))。"
            }
            return "使用禁止の時間帯です。"
        case .allowedSchedule:
            return "無料開放の時間帯です。チケットは減りません。"
        case .ticketRequired:
            return "チケットを1枚使うと10分だけ開けられます。"
        case .activeTicket:
            return "チケットの残り時間だけ使えます。"
        case .outsideScheduleBlocked:
            return "登録した時間帯以外なので制限しています。"
        case .masterDisabled, .unrestricted, .none:
            return "いまはどのルールにも当てはまっていません。"
        }
    }

    private func activeTicketRemainingText(at date: Date) -> String? {
        guard let ledger = focusController.ticketLedger,
              ledger.hasActiveTicket(at: date),
              let expiry = ledger.activeTicketEndDate else {
            return nil
        }
        let seconds = max(Int(ceil(expiry.timeIntervalSince(date))), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 警告

    private struct ScreenTimeWarning: Identifiable {
        let id: String
        let icon: String
        let message: String
        let color: Color
        var actionTitle: String?
        var action: (() -> Void)?
    }

    private var warnings: [ScreenTimeWarning] {
        guard focusController.isAuthorized, settings.isEnabled else { return [] }
        var items: [ScreenTimeWarning] = []

        // 許可アプリが空だと ManagedSettings 側は shield を解除するため、実際には何も制限されない。
        if settings.requiresAllowedSelection, !settings.canApplyRestrictions {
            items.append(
                ScreenTimeWarning(
                    id: "allowed-selection",
                    icon: "exclamationmark.triangle.fill",
                    message: "「制限中も使えるもの」が未選択のため、実際には何も制限されていません。",
                    color: AppColors.danger,
                    actionTitle: "選ぶ",
                    action: {
                        focusPickerSelection = settings.activitySelection
                        isShowingAllowedAppsPicker = true
                    }
                )
            )
        }

        if activeRuleCount == 0 {
            items.append(
                ScreenTimeWarning(
                    id: "no-rule",
                    icon: "questionmark.circle.fill",
                    message: "制限するルールが1つも選ばれていません。",
                    color: AppColors.warning
                )
            )
        }

        if !goalRuleOverridesOthers,
           settings.ticketRestrictionEnabled,
           settings.dailyTicketMinutes == 0 {
            items.append(
                ScreenTimeWarning(
                    id: "no-ticket",
                    icon: "ticket.fill",
                    message: "1日に使える時間が0分です。このままだと1日中開けられません。",
                    color: AppColors.warning
                )
            )
        }

        if !goalRuleOverridesOthers,
           settings.scheduledRestrictionEnabled,
           settings.enabledScheduleSlots.isEmpty {
            items.append(
                ScreenTimeWarning(
                    id: "no-slot",
                    icon: "calendar.badge.exclamationmark",
                    message: "使える時間帯が登録されていません。",
                    color: AppColors.warning
                )
            )
        }

        return items
    }

    private var activeRuleCount: Int {
        if goalRuleOverridesOthers { return 1 }
        return [
            settings.timerRestrictionEnabled,
            settings.scheduledRestrictionEnabled,
            settings.ticketRestrictionEnabled
        ]
        .filter { $0 }
        .count
    }

    private func warningBanner(_ warning: ScreenTimeWarning) -> some View {
        HStack(spacing: 9) {
            Image(systemName: warning.icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(warning.color)
            Text(warning.message)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let actionTitle = warning.actionTitle, let action = warning.action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(warning.color)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warning.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - チケット

    private var ticketCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            settingsGroup(title: "チケット") {
                HStack(spacing: 10) {
                    ticketMetric(
                        title: "今日の残り",
                        value: ticketCountText(at: context.date),
                        color: ticketRemainingCount(at: context.date) > 0 ? AppColors.success : AppColors.textSecondary
                    )

                    Rectangle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 1, height: 34)

                    ticketMetric(
                        title: "1日に使える時間",
                        value: "\(settings.dailyTicketMinutes)分",
                        color: AppColors.textPrimary,
                        // 使用済みチケットがある日は枚数を変えられないため、今日の残り枚数と食い違う。
                        subtitle: canUpdateTodayTicketCount(at: context.date) ? nil : "変更は明日から反映"
                    )
                }
                .padding(.bottom, 10)

                Button {
                    isShowingTicketConfirmation = true
                } label: {
                    Label(ticketButtonTitle(at: context.date), systemImage: ticketButtonIcon(at: context.date))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(ticketCanStart(at: context.date) ? Color.white : AppColors.textSecondary)
                        .background(
                            ticketCanStart(at: context.date) ? AppColors.success : AppColors.subtleBackground,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!ticketCanStart(at: context.date))
            } footer: {
                Text(ticketFooterText(at: context.date))
            }
            .onChange(of: Calendar.current.startOfDay(for: context.date)) { _ in
                Task {
                    await refreshGoalProgress(reason: "screen-time-ticket-day-changed")
                }
            }
        }
    }

    private func ticketMetric(
        title: String,
        value: String,
        color: Color,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func canUpdateTodayTicketCount(at date: Date) -> Bool {
        guard let ledger = focusController.ticketLedger else { return true }
        return ledger.canUpdateIssuedTicketCount(at: date)
    }

    private func ticketRemainingCount(at date: Date) -> Int {
        guard let ledger = focusController.ticketLedger, ledger.isForDay(containing: date) else { return 0 }
        return ledger.remainingTicketCount
    }

    private func ticketCountText(at date: Date) -> String {
        guard let ledger = focusController.ticketLedger, ledger.isForDay(containing: date) else {
            return "0 / 0枚"
        }
        return "\(ledger.remainingTicketCount) / \(ledger.issuedTicketCount)枚"
    }

    private func ticketCanStart(at date: Date) -> Bool {
        guard focusController.isAuthorized,
              ticketRemainingCount(at: date) > 0,
              focusController.ticketLedger?.hasActiveTicket(at: date) != true else {
            return false
        }
        return focusController.policyDecision?.canStartTicket == true
    }

    private func ticketButtonTitle(at date: Date) -> String {
        if let remaining = activeTicketRemainingText(at: date) {
            return "利用中 残り\(remaining)"
        }
        if ticketRemainingCount(at: date) == 0 {
            return "今日のチケットは終了"
        }
        if focusController.policyDecision?.canStartTicket != true {
            return "いまは使えません"
        }
        return "チケット1枚で10分使う"
    }

    private func ticketButtonIcon(at date: Date) -> String {
        focusController.ticketLedger?.hasActiveTicket(at: date) == true ? "hourglass" : "play.fill"
    }

    private func ticketFooterText(at date: Date) -> String {
        if focusController.ticketLedger?.hasActiveTicket(at: date) == true {
            return "チケットの時間は使用禁止時間帯に入っても止まりません。"
        }
        switch focusController.policyDecision?.reason {
        case .dailyGoalPending:
            return "「目標達成まで制限」がオンの間は、チケットを使えません。"
        case .studyTimer:
            return "勉強タイマー中はチケットを使えません。"
        case .blockedSchedule:
            if let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart {
                return "使用禁止の時間帯です。次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))。"
            }
            return "使用禁止の時間帯ではチケットを使えません。"
        case .allowedSchedule:
            return "無料開放の時間帯なので、チケットは消費されません。"
        case .dailyGoalReached:
            return "今日の目標を達成したため、終日開放されています。"
        default:
            return "1枚で開始から10分間使えます。\(ticketSettingsApplyTimingText)。"
        }
    }

    private var ticketSettingsApplyTimingText: String {
        canUpdateTodayTicketCount(at: Date())
            ? "枚数の変更は今日からすぐ反映"
            : "枚数の変更は次の0時から反映"
    }

    // MARK: - ルール

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("制限のルール")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("複数が重なったときは、上のルールが優先されます")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.leading, 11)

            VStack(spacing: 0) {
                goalRuleRows
                Divider()
                timerRuleRow
                Divider()
                scheduleRuleRows
                Divider()
                ticketRuleRows
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
            .disabled(!canEditSettings)
            .opacity(settings.isEnabled ? 1 : 0.55)

            if !settings.isEnabled {
                groupFooter("集中制限がオフの間は、どのルールも動きません。")
            } else if !canEditSettings {
                groupFooter("厳格ロック中のため変更できません。")
            }
        }
    }

    private var goalRuleRows: some View {
        VStack(spacing: 0) {
            ruleRow(
                icon: "target",
                title: "目標達成まで制限",
                detail: "達成するまで終日制限し、達成したら終日開放します",
                badge: goalRuleOverridesOthers ? RuleBadge(text: "最優先で動作中", color: AppColors.success) : nil,
                isOn: Binding(
                    get: { settings.unlockRestrictionsWhenDailyGoalReached },
                    set: { enabled in
                        applyFocusSettings { $0.unlockRestrictionsWhenDailyGoalReached = enabled }
                    }
                )
            )

            if goalRuleOverridesOthers {
                subRow(icon: "chart.line.uptrend.xyaxis", title: "今日の進み具合", detail: goalProgressStatusText) {
                    Text(goalProgressText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(goalProgress?.hasReachedTarget == true ? AppColors.success : AppColors.textPrimary)
                }

                Text("このルールがオンの間、下の3つのルールは使われません（手動で追加した学習記録は進み具合に含みません）。")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
            }
        }
    }

    private var timerRuleRow: some View {
        ruleRow(
            icon: "timer",
            title: "勉強タイマー中",
            detail: "タイマーを開始している間だけ制限します",
            badge: dormantBadge,
            isDormant: goalRuleOverridesOthers,
            isOn: Binding(
                get: { settings.timerRestrictionEnabled },
                set: { enabled in
                    applyFocusSettings { $0.timerRestrictionEnabled = enabled }
                }
            )
        )
    }

    private var scheduleRuleRows: some View {
        VStack(spacing: 0) {
            ruleRow(
                icon: "calendar.badge.clock",
                title: "決めた時間帯",
                detail: "曜日と時刻ごとに、使用禁止／無料開放を切り替えます",
                badge: dormantBadge,
                isDormant: goalRuleOverridesOthers,
                isOn: Binding(
                    get: { settings.scheduledRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.scheduledRestrictionEnabled = enabled }
                    }
                )
            )

            // チケット制がオンのときは判定がチケット側で止まるため、この設定は効かない。
            if settings.scheduledRestrictionEnabled, !settings.ticketRestrictionEnabled {
                subRowDivider
                ruleRow(
                    icon: "clock.badge.xmark",
                    title: "時間帯の外も制限",
                    detail: "無料開放に指定した時間だけ使えるようにします",
                    badge: dormantBadge,
                    isDormant: goalRuleOverridesOthers,
                    indented: true,
                    isOn: Binding(
                        get: { settings.restrictOutsideScheduleWhenTicketsDisabled },
                        set: { enabled in
                            applyFocusSettings { $0.restrictOutsideScheduleWhenTicketsDisabled = enabled }
                        }
                    )
                )
            }
        }
    }

    private var ticketRuleRows: some View {
        VStack(spacing: 0) {
            ruleRow(
                icon: "ticket",
                title: "チケット制",
                detail: "ふだんは制限し、チケット1枚で10分だけ開けます",
                badge: dormantBadge,
                isDormant: goalRuleOverridesOthers,
                isOn: Binding(
                    get: { settings.ticketRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.ticketRestrictionEnabled = enabled }
                    }
                )
            )

            if settings.ticketRestrictionEnabled {
                subRowDivider
                subRow(
                    icon: "clock.badge.checkmark",
                    title: "1日に使える時間",
                    detail: "\(settings.dailyTicketMinutes / ScreenTimeFocusSettings.ticketDurationMinutes)枚・\(ticketSettingsApplyTimingText)"
                ) {
                    Stepper(
                        value: Binding(
                            get: { settings.dailyTicketMinutes },
                            set: { minutes in
                                applyFocusSettings { $0.dailyTicketMinutes = minutes }
                            }
                        ),
                        in: ScreenTimeFocusSettings.minimumDailyTicketMinutes...ScreenTimeFocusSettings.maximumDailyTicketMinutes,
                        step: ScreenTimeFocusSettings.ticketDurationMinutes
                    ) {
                        Text("\(settings.dailyTicketMinutes)分")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private struct RuleBadge {
        let text: String
        let color: Color
    }

    private var dormantBadge: RuleBadge? {
        goalRuleOverridesOthers ? RuleBadge(text: "休止中", color: AppColors.textSecondary) : nil
    }

    private func ruleRow(
        icon: String,
        title: String,
        detail: String,
        badge: RuleBadge?,
        isDormant: Bool = false,
        indented: Bool = false,
        isOn: Binding<Bool>
    ) -> some View {
        let accentColor = isDormant ? AppColors.textSecondary : AppColors.success
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 30, height: 30)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                    if let badge {
                        Text(badge.text)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(badge.color.opacity(0.14), in: Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColors.success)
        }
        .padding(.leading, indented ? 16 : 0)
        .padding(.vertical, 11)
        .opacity(isDormant ? 0.6 : 1)
    }

    private func subRow<Trailing: View>(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.leading, 16)
        .padding(.vertical, 9)
    }

    private var subRowDivider: some View {
        Divider().padding(.leading, 46)
    }

    // MARK: - 時間帯

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("時間帯")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(enabledScheduleCountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
            .padding(.horizontal, 11)

            VStack(spacing: 0) {
                if settings.scheduleSlots.isEmpty {
                    Text("まだ登録されていません。使用禁止にする時間、または無料開放にする時間を追加してください。")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(settings.scheduleSlots.enumerated()), id: \.element.id) { index, slot in
                        if index > 0 {
                            Divider()
                        }
                        scheduleSlotRow(slot)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }

            Button {
                addScheduleSlot()
            } label: {
                Label("時間帯を追加", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(canAddScheduleSlot ? AppColors.success : AppColors.textSecondary)
                    .background(
                        canAddScheduleSlot ? AppColors.greenSoft : AppColors.subtleBackground,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAddScheduleSlot)
        }
    }

    private var canAddScheduleSlot: Bool {
        canEditSettings &&
            settings.enabledScheduleSlots.count < settings.maximumEnabledSlotsForCurrentConfiguration
    }

    private var enabledScheduleCountText: String {
        let slots = settings.scheduleSlots
        guard !slots.isEmpty else { return "未登録" }
        return "\(slots.filter(\.isEnabled).count) / \(slots.count) オン"
    }

    private func scheduleSlotRow(_ slot: FocusScheduleSlot) -> some View {
        HStack(spacing: 11) {
            Button {
                editingSlot = ScheduleEditorTarget(id: slot.id)
            } label: {
                HStack(spacing: 11) {
                    Text(slot.behavior.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(behaviorColor(slot.behavior))
                        .frame(width: 58)
                        .padding(.vertical, 6)
                        .background(behaviorColor(slot.behavior).opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(ScreenTimeFormat.timeRangeText(slot))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.textPrimary)
                        Text(ScreenTimeFormat.weekdaysSummary(slot) + "・" + ScreenTimeFormat.durationText(slot))
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                        if let message = ScreenTimeFormat.validationMessage(slot) {
                            Text(message)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.danger)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { slot.isEnabled },
                set: { enabled in
                    updateScheduleSlot(id: slot.id) { $0.isEnabled = enabled }
                }
            ))
            .labelsHidden()
            .tint(AppColors.success)
            .accessibilityLabel("\(ScreenTimeFormat.timeRangeText(slot))を有効にする")
        }
        .padding(.vertical, 9)
        .opacity(slot.isEnabled ? 1 : 0.55)
        .disabled(!canEditSettings)
    }

    private func behaviorColor(_ behavior: FocusScheduleBehavior) -> Color {
        behavior == .block ? AppColors.danger : AppColors.blue
    }

    // MARK: - 制限中も使えるもの

    private var allowedAppsCard: some View {
        settingsGroup(title: "制限中も使えるもの") {
            Button {
                focusPickerSelection = settings.activitySelection
                isShowingAllowedAppsPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 30, height: 30)
                        .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("アプリとWebサイト")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(allowedSelectionSummary)
                            .font(.caption)
                            .foregroundStyle(
                                settings.canApplyRestrictions ? AppColors.textSecondary : AppColors.danger
                            )
                    }

                    Spacer(minLength: 8)

                    Text("選ぶ")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.success)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .frame(minHeight: 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canEditSettings)
        } footer: {
            Text("ここで選んだものだけ、制限中も開けます。1つも選ばないと制限そのものがかかりません。")
        }
    }

    private var allowedSelectionSummary: String {
        let appCount = focusController.allowedApplicationCount
        let webCount = focusController.allowedWebDomainCount
        if appCount == 0, webCount == 0 {
            return "未選択（制限がかかりません）"
        }
        if webCount == 0 {
            return "アプリ \(appCount)件"
        }
        return "アプリ \(appCount)件・Webサイト \(webCount)件"
    }

    // MARK: - 設定を固定

    private var lockCard: some View {
        settingsGroup(title: "設定を固定") {
            if focusController.isSettingsLocked, let expiryDate = focusController.settingsLockExpiryDate {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.warning)
                        .frame(width: 30, height: 30)
                        .background(AppColors.warning.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("厳格ロック中")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("\(ScreenTimeFormat.lockDateText(expiryDate))まで変更できません")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(lockRemainingText(until: expiryDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.warning)
                }
                .frame(minHeight: 46)
            } else {
                Button {
                    isShowingLockSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.warning)
                            .frame(width: 30, height: 30)
                            .background(AppColors.warning.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("厳格ロック")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("決めた期間が終わるまで、自分でも設定を変えられなくします")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .frame(minHeight: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("一度オンにすると期限まで解除できません。iOSの設定アプリからScreen Timeの許可を取り消すことはできます。")
        }
    }

    private func lockRemainingText(until expiryDate: Date) -> String {
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: expiryDate)
        ).day ?? 0
        return dayCount <= 0 ? "まもなく解除" : "約\(dayCount)日"
    }

    // MARK: - 共通レイアウト

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, 11)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    private func settingsGroup<Content: View, Footer: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            settingsGroup(title: title, content: content)
            footer()
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
        }
    }

    private func groupFooter(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
    }

    // MARK: - 進捗

    private var goalProgressText: String {
        guard let goalProgress else { return "読み込み中" }
        guard goalProgress.hasTarget else { return "目標未設定" }
        return "\(Goal.format(minutes: goalProgress.studyMinutes)) / \(Goal.format(minutes: goalProgress.targetMinutes))"
    }

    private var goalProgressStatusText: String {
        guard let goalProgress else { return "進捗を確認しています" }
        guard goalProgress.hasTarget else { return "1日の学習目標を設定してください" }
        return goalProgress.hasReachedTarget ? "目標を達成しました" : "目標達成まで制限中"
    }

    // MARK: - アクション

    private func applyFocusSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) {
        guard canEditSettings else { return }
        do {
            try focusController.updateSettings(update)
            Task { await refreshGoalProgress(reason: "screen-time-settings") }
        } catch {
            app.present(error)
        }
    }

    private func updateScheduleSlot(id: String, update: (inout FocusScheduleSlot) -> Void) {
        applyFocusSettings { settings in
            guard let index = settings.scheduleSlots.firstIndex(where: { $0.id == id }) else { return }
            update(&settings.scheduleSlots[index])
        }
    }

    private func addScheduleSlot() {
        do {
            try focusController.addScheduleSlot()
            Task { await refreshGoalProgress(reason: "screen-time-add-schedule") }
        } catch {
            app.present(error)
        }
    }

    private func removeScheduleSlot(id: String) {
        do {
            if editingSlot?.id == id {
                editingSlot = nil
            }
            try focusController.removeScheduleSlot(id: id)
            Task { await refreshGoalProgress(reason: "screen-time-remove-schedule") }
        } catch {
            app.present(error)
        }
    }

    private func startTicket() {
        do {
            try focusController.startTicket()
            Task { await refreshGoalProgress(reason: "screen-time-ticket-start") }
        } catch {
            app.present(error)
        }
    }

    private func activateStrictLock(months: Int, days: Int) {
        do {
            try focusController.activateSettingsLock(months: months, days: days)
            Task { await refreshGoalProgress(reason: "screen-time-strict-lock") }
        } catch {
            app.present(error)
        }
    }

    private func requestScreenTimeAuthorization() {
        Task {
            do {
                try await focusController.requestAuthorization()
                await refreshGoalProgress(reason: "screen-time-authorization")
            } catch {
                app.present(error)
            }
        }
    }

    @MainActor
    private func refreshGoalProgress(reason: String) async {
        if let progress = await app.refreshScreenTimeFocusState(reason: reason) {
            goalProgress = progress
        }
    }

    private struct ScheduleEditorTarget: Identifiable, Equatable {
        let id: String
    }

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d H:mm"
        return formatter
    }()
}

// MARK: - 時間帯エディタ

private struct ScheduleSlotEditorSheet: View {
    @ObservedObject var focusController: ScreenTimeFocusController
    let slotID: String
    let canEdit: Bool
    let onUpdate: (String, (inout FocusScheduleSlot) -> Void) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false

    private var slot: FocusScheduleSlot? {
        focusController.settings.scheduleSlots.first { $0.id == slotID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let slot {
                    editor(slot)
                } else {
                    Color.clear
                        .onAppear { dismiss() }
                }
            }
            .strictScreen()
            .navigationTitle("時間帯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .font(.body.weight(.bold))
                }
            }
            .confirmationDialog("この時間帯を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    onDelete(slotID)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func editor(_ slot: FocusScheduleSlot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard(slot)
                behaviorGroup(slot)
                timeGroup(slot)
                weekdayGroup(slot)
                deleteButton
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 32)
            .disabled(!canEdit)
        }
    }

    private func summaryCard(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ScreenTimeFormat.timeRangeText(slot))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
            Text("\(ScreenTimeFormat.weekdaysSummary(slot))・\(ScreenTimeFormat.durationText(slot))・\(slot.behavior.title)")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            if let message = ScreenTimeFormat.validationMessage(slot) {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.danger)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func behaviorGroup(_ slot: FocusScheduleSlot) -> some View {
        group(title: "この時間帯の動作") {
            Picker(
                "この時間帯の動作",
                selection: Binding(
                    get: { slot.behavior },
                    set: { behavior in
                        onUpdate(slot.id) { $0.behavior = behavior }
                    }
                )
            ) {
                ForEach(FocusScheduleBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            Text(slot.behavior == .block
                 ? "この時間はチケットも使えず、必ず制限されます。"
                 : "この時間はチケットを使わずに開けられます。")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func timeGroup(_ slot: FocusScheduleSlot) -> some View {
        group(title: "時刻") {
            DatePicker(
                selection: timeBinding(slot, endpoint: .start),
                displayedComponents: .hourAndMinute
            ) {
                Text("開始")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .frame(minHeight: 44)

            Divider()

            DatePicker(
                selection: timeBinding(slot, endpoint: .end),
                displayedComponents: .hourAndMinute
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("終了")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    if ScreenTimeFormat.crossesMidnight(slot) {
                        Text("翌日")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .frame(minHeight: 44)
        }
    }

    private func weekdayGroup(_ slot: FocusScheduleSlot) -> some View {
        group(title: "繰り返す曜日") {
            HStack(spacing: 7) {
                weekdayPreset(slot, title: "毎日", weekdays: FocusScheduleSlot.allWeekdays)
                weekdayPreset(slot, title: "平日", weekdays: [2, 3, 4, 5, 6])
                weekdayPreset(slot, title: "週末", weekdays: [1, 7])
            }
            .padding(.vertical, 4)

            HStack(spacing: 6) {
                ForEach(ScreenTimeFormat.orderedWeekdays, id: \.self) { weekday in
                    weekdayChip(slot, weekday: weekday)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }

    private func weekdayPreset(_ slot: FocusScheduleSlot, title: String, weekdays: Set<Int>) -> some View {
        let isSelected = slot.weekdays == weekdays
        return Button {
            onUpdate(slot.id) { $0.weekdays = weekdays }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? AppColors.success : AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    isSelected ? AppColors.greenSoft : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func weekdayChip(_ slot: FocusScheduleSlot, weekday: Int) -> some View {
        let isOn = slot.weekdays.contains(weekday)
        return Button {
            onUpdate(slot.id) { current in
                if current.weekdays.contains(weekday) {
                    current.weekdays.remove(weekday)
                } else {
                    current.weekdays.insert(weekday)
                }
            }
        } label: {
            Text(ScreenTimeFormat.weekdayShortTitle(weekday))
                .font(.caption.weight(.bold))
                .foregroundStyle(isOn ? Color.white : ScreenTimeFormat.weekdayColor(weekday))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    isOn ? AppColors.success : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isOn ? AppColors.success : AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ScreenTimeFormat.weekdayShortTitle(weekday))曜日")
        .accessibilityValue(isOn ? "選択中" : "未選択")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("この時間帯を削除", systemImage: "trash")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(AppColors.danger)
                .background(AppColors.redSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func timeBinding(_ slot: FocusScheduleSlot, endpoint: TimeEndpoint) -> Binding<Date> {
        Binding(
            get: {
                let now = Date()
                switch endpoint {
                case .start:
                    return Calendar.current.date(bySettingHour: slot.startHour, minute: slot.startMinute, second: 0, of: now) ?? now
                case .end:
                    return Calendar.current.date(bySettingHour: slot.endHour, minute: slot.endMinute, second: 0, of: now) ?? now
                }
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                onUpdate(slot.id) { current in
                    switch endpoint {
                    case .start:
                        current.startHour = components.hour ?? current.startHour
                        current.startMinute = components.minute ?? current.startMinute
                    case .end:
                        current.endHour = components.hour ?? current.endHour
                        current.endMinute = components.minute ?? current.endMinute
                    }
                }
            }
        )
    }

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, 11)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    private enum TimeEndpoint {
        case start
        case end
    }
}

// MARK: - 厳格ロック

private struct StrictLockSheet: View {
    let onActivate: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var months = 0
    @State private var days = 1
    @State private var isShowingConfirmation = false

    private static let presets: [(title: String, months: Int, days: Int)] = [
        ("1日", 0, 1),
        ("3日", 0, 3),
        ("1週間", 0, 7),
        ("1か月", 1, 0),
        ("3か月", 3, 0)
    ]

    private var expiryDate: Date? {
        ScreenTimeFocusSettings.lockExpiryDate(from: Date(), months: months, days: days)
    }

    private var expiryHeadline: String {
        guard let expiryDate else { return "期間を指定してください" }
        return "\(ScreenTimeFormat.lockDateText(expiryDate))まで"
    }

    private var expiryDetail: String {
        guard expiryDate != nil else { return "1日以上を指定すると固定できます。" }
        return "今日から\(durationSummary)、集中制限の設定を変更できなくなります。"
    }

    private var durationSummary: String {
        switch (months, days) {
        case (0, let days): return "\(days)日"
        case (let months, 0): return "\(months)か月"
        case (let months, let days): return "\(months)か月\(days)日"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expiryHeadline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(expiryDate == nil ? AppColors.danger : AppColors.textPrimary)
                        Text(expiryDetail)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.warning.opacity(0.35), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("期間")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.leading, 11)

                        VStack(spacing: 10) {
                            HStack(spacing: 7) {
                                ForEach(Self.presets, id: \.title) { preset in
                                    presetButton(preset)
                                }
                            }

                            Divider()

                            stepperRow(title: "か月", value: $months, range: 0...24)
                            stepperRow(title: "日", value: $days, range: 0...31)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        }
                    }

                    Text("一度固定すると、期限が来るまで自分でも解除できません。iOSの設定アプリからScreen Timeの許可を取り消すことはできます。")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)

                    Button {
                        isShowingConfirmation = true
                    } label: {
                        Label("この期間で固定する", systemImage: "lock.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Color.white)
                            .background(
                                expiryDate == nil ? AppColors.textSecondary : AppColors.warning,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(expiryDate == nil)
                }
                .padding(.horizontal, 17)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .strictScreen()
            .navigationTitle("設定を固定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .confirmationDialog("厳格ロックを有効にしますか？", isPresented: $isShowingConfirmation, titleVisibility: .visible) {
                Button("ロックする", role: .destructive) {
                    onActivate(months, days)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let expiryDate {
                    Text("\(durationSummary)後の\(ScreenTimeFormat.lockDateText(expiryDate))まで、集中制限の設定を変更できなくなります。")
                } else {
                    Text("ロック期間は1日以上を指定してください。")
                }
            }
        }
    }

    private func presetButton(_ preset: (title: String, months: Int, days: Int)) -> some View {
        let isSelected = months == preset.months && days == preset.days
        return Button {
            months = preset.months
            days = preset.days
        } label: {
            Text(preset.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color.white : AppColors.warning)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    isSelected ? AppColors.warning : AppColors.warning.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)\(title)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(minWidth: 64, alignment: .trailing)
            }
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }
}

// MARK: - 表示フォーマット

private enum ScreenTimeFormat {
    /// 日曜始まり。アプリ内の他の曜日表示と合わせている。
    static let orderedWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func timeRangeText(_ slot: FocusScheduleSlot) -> String {
        let base = "\(timeText(hour: slot.startHour, minute: slot.startMinute)) → \(timeText(hour: slot.endHour, minute: slot.endMinute))"
        return crossesMidnight(slot) ? base + "（翌日）" : base
    }

    static func crossesMidnight(_ slot: FocusScheduleSlot) -> Bool {
        slot.endHour * 60 + slot.endMinute < slot.startHour * 60 + slot.startMinute
    }

    static func durationText(_ slot: FocusScheduleSlot) -> String {
        let duration = slot.durationMinutes
        guard duration > 0 else { return "時刻を確認" }
        let hours = duration / 60
        let minutes = duration % 60
        switch (hours, minutes) {
        case (0, let minutes): return "\(minutes)分"
        case (let hours, 0): return "\(hours)時間"
        case (let hours, let minutes): return "\(hours)時間\(minutes)分"
        }
    }

    static func weekdaysSummary(_ slot: FocusScheduleSlot) -> String {
        let selected = slot.weekdays
        if selected.isEmpty { return "曜日未選択" }
        if selected == FocusScheduleSlot.allWeekdays { return "毎日" }
        if selected == [2, 3, 4, 5, 6] { return "平日" }
        if selected == [1, 7] { return "週末" }
        return orderedWeekdays
            .filter { selected.contains($0) }
            .map { weekdayShortTitle($0) }
            .joined(separator: "・")
    }

    static func validationMessage(_ slot: FocusScheduleSlot) -> String? {
        guard slot.isEnabled else { return nil }
        if slot.durationMinutes == 0 {
            return "開始と終了を別の時刻にしてください"
        }
        if slot.durationMinutes < ScreenTimeFocusSettings.minimumScheduleDurationMinutes {
            return "15分以上の時間帯を指定してください"
        }
        if !slot.hasSelectedWeekday {
            return "曜日を1つ以上選んでください"
        }
        return nil
    }

    static func weekdayShortTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        case 7: return "土"
        default: return ""
        }
    }

    static func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return AppColors.danger
        case 7: return AppColors.blue
        default: return AppColors.textPrimary
        }
    }

    static func lockDateText(_ date: Date) -> String {
        lockDateFormatter.string(from: date)
    }

    private static let lockDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}
