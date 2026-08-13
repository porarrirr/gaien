import FamilyControls
import SwiftUI

/// 集中制限の設定画面。
///
/// 画面は「いまの状態 → 実績 → 壁のルール → チケット → 対象の選択 → 固定」の順に並ぶ。
/// ルールは互いに独立して効くため、以前のような優先順の説明や休止表示は持たない。
/// 表示される理由だけが優先順（`ScreenTimePolicyEvaluator`）に従う。
struct ScreenTimeSettingsScreen: View {
    private enum ActivityPickerTarget: Equatable {
        case allowedDuringRestriction
        case dailyBudget
    }

    @ObservedObject private var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController

    @State private var isShowingActivityPicker = false
    @State private var activityPickerTarget: ActivityPickerTarget = .allowedDuringRestriction
    @State private var activityPickerSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pendingSettings: ScreenTimeFocusSettings?
    @State private var goalProgress: ScreenTimeDailyGoalProgress?
    @State private var isShowingTicketConfirmation = false
    @State private var editingSlot: ScheduleEditorTarget?
    @State private var editingZone: LocationEditorTarget?
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusCard
                if shouldShowPresets {
                    presetCard
                }
                if settings.isEnabled, settings.ticketsEnabled {
                    ticketCard
                }
                reportCard
                wallRulesCard
                if settings.scheduledRestrictionEnabled {
                    scheduleSection
                }
                if settings.locationRestrictionEnabled {
                    locationSection
                }
                ticketRuleCard
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
            headerText: activityPickerHeaderText,
            footerText: activityPickerFooterText,
            isPresented: $isShowingActivityPicker,
            selection: $activityPickerSelection
        )
        .onChange(of: activityPickerSelection) { selection in
            handleActivitySelectionChange(selection)
        }
        .onChange(of: isShowingActivityPicker) { isPresented in
            guard !isPresented else { return }
            continuePendingSettingsUpdate(afterDismissing: activityPickerTarget)
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
        .sheet(item: $editingZone) { target in
            LocationZoneEditorSheet(
                focusController: focusController,
                zoneID: target.id,
                canEdit: canEditSettings,
                onUpdate: { id, update in
                    updateLocationZone(id: id, update: update)
                },
                onDelete: { id in
                    removeLocationZone(id: id)
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
            Text(ticketConfirmationMessage)
        }
        .task(id: app.dataVersion) {
            await refreshGoalProgress(reason: "screen-time-settings-data")
        }
        .onAppear {
            focusController.refresh()
            activityPickerSelection = settings.activitySelection
        }
        .task(id: focusController.ticketLedger?.activeTicketEndsAt) {
            guard let expiry = focusController.ticketLedger?.activeTicketEndDate else { return }
            let delay = max(expiry.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await refreshGoalProgress(reason: "screen-time-ticket-expired")
        }
    }

    private var activityPickerHeaderText: String {
        switch activityPickerTarget {
        case .allowedDuringRestriction:
            return "集中制限中も使えるアプリとWebサイトを選択してください"
        case .dailyBudget:
            return "時間を決めて使うアプリとWebサイトを選択してください"
        }
    }

    private var activityPickerFooterText: String {
        switch activityPickerTarget {
        case .allowedDuringRestriction:
            return "選択されていないアプリとWebサイトは集中制限中に開けなくなります。"
        case .dailyBudget:
            return "選択したものの使用時間が持ち時間から引かれ、使い切ると開けなくなります。"
        }
    }

    private func showActivityPicker(for target: ActivityPickerTarget) {
        if pendingSettings == nil {
            // FamilyActivityPicker は選択のたびに Binding を更新する。操作途中の空選択を
            // 保存して検証エラーにしないよう、閉じるまでは常に下書きへ保持する。
            pendingSettings = settings
        }
        activityPickerTarget = target
        let source = pendingSettings ?? settings
        switch target {
        case .allowedDuringRestriction:
            activityPickerSelection = source.activitySelection
        case .dailyBudget:
            activityPickerSelection = source.budgetSelection
        }
        isShowingActivityPicker = true
    }

    private func handleActivitySelectionChange(_ selection: FamilyActivitySelection) {
        guard pendingSettings != nil else { return }
        switch activityPickerTarget {
        case .allowedDuringRestriction:
            pendingSettings?.activitySelection = selection
        case .dailyBudget:
            pendingSettings?.budgetSelection = selection
        }
    }

    /// 選択が必須の設定変更は、対象選択を終えてから同じ変更を再開する。
    /// ピッカーをキャンセルした場合は、未完成の設定を保存しない。
    private func continuePendingSettingsUpdate(afterDismissing dismissedTarget: ActivityPickerTarget) {
        guard var candidate = pendingSettings else { return }
        // dismiss と最後の Binding 更新の通知順に依存せず、閉じた時点の値を確定候補へ入れる。
        switch dismissedTarget {
        case .allowedDuringRestriction:
            candidate.activitySelection = activityPickerSelection
        case .dailyBudget:
            candidate.budgetSelection = activityPickerSelection
        }

        if candidate.requiresBudgetSelection, !candidate.hasBudgetSelection {
            guard dismissedTarget != .dailyBudget else {
                pendingSettings = nil
                return
            }
            pendingSettings = candidate
            DispatchQueue.main.async {
                showActivityPicker(for: .dailyBudget)
            }
            return
        }

        if candidate.requiresAllowedSelection, !hasAllowedSelection(candidate) {
            guard dismissedTarget != .allowedDuringRestriction else {
                pendingSettings = nil
                return
            }
            pendingSettings = candidate
            DispatchQueue.main.async {
                showActivityPicker(for: .allowedDuringRestriction)
            }
            return
        }

        pendingSettings = nil
        if focusController.requiresRestoredActivitySelection {
            do {
                try focusController.resolveRestoredActivitySelections(
                    allowedSelection: candidate.activitySelection,
                    budgetSelection: candidate.budgetSelection
                )
            } catch {
                app.present(error)
                return
            }

            // 復元修復と同時にトグル等を操作していた場合だけ、その変更も続けて反映する。
            let repaired = settings
            candidate.activitySelection = repaired.activitySelection
            candidate.budgetSelection = repaired.budgetSelection
            candidate.selectionWasConfigured = repaired.selectionWasConfigured
            candidate.budgetSelectionWasConfigured = repaired.budgetSelectionWasConfigured
            candidate.updatedAt = repaired.updatedAt
            guard candidate != repaired else { return }
        }
        guard candidate != settings else { return }
        commitFocusSettings { $0 = candidate }
    }

    private func hasAllowedSelection(_ settings: ScreenTimeFocusSettings) -> Bool {
        !settings.allowedApplicationTokens.isEmpty || !settings.allowedWebDomainTokens.isEmpty
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
        guard focusController.isAvailable else { return "exclamationmark.shield.fill" }
        if focusController.isProtectionInterrupted { return "exclamationmark.shield.fill" }
        guard focusController.isAuthorized else { return "exclamationmark.shield.fill" }
        guard settings.isEnabled else { return "shield.slash.fill" }
        return isCurrentlyRestricted ? "lock.fill" : "lock.open.fill"
    }

    private var statusColor: Color {
        guard focusController.isAvailable else { return AppColors.warning }
        if focusController.isProtectionInterrupted { return AppColors.danger }
        guard focusController.isAuthorized else { return AppColors.warning }
        guard settings.isEnabled else { return AppColors.textSecondary }
        return isCurrentlyRestricted ? AppColors.success : AppColors.blue
    }

    private var isCurrentlyRestricted: Bool {
        focusController.policyDecision?.isRestricted == true
    }

    private func statusHeadline(at date: Date) -> String {
        guard focusController.isAvailable else { return "この端末では使えません" }
        if focusController.isProtectionInterrupted { return "制限が効いていません" }
        guard focusController.isAuthorized else { return "許可がまだです" }
        guard settings.isEnabled else { return "集中制限はオフ" }
        if let remaining = activeTicketRemainingText(at: date) {
            return "チケット利用中 \(remaining)"
        }
        switch focusController.policyDecision?.reason {
        case .budgetExhausted:
            return "持ち時間を使い切りました"
        case .lockedSchedule:
            return "いま制限中（解除不可）"
        case .lockedLocation:
            return "いま制限中（この場所は解除不可）"
        default:
            return isCurrentlyRestricted ? "いま制限中" : "いま使えます"
        }
    }

    private func statusDetail(at date: Date) -> String {
        guard focusController.isAvailable else {
            return "Screen TimeはiOS 16以降で利用できます。"
        }
        if focusController.isProtectionInterrupted {
            return "iOSの設定でScreen Timeの許可が外れています。許可し直すまで制限はかかりません。"
        }
        guard focusController.isAuthorized else {
            return "iPhoneのScreen Time機能を使って、勉強中の寄り道と使いすぎを防ぎます。"
        }
        guard settings.isEnabled else {
            return "右のスイッチをオンにすると、下のルールが動き始めます。"
        }
        if activeTicketRemainingText(at: date) != nil {
            return "終了すると再び制限されます。"
        }
        switch focusController.policyDecision?.reason {
        case .budgetExhausted:
            return "対象のアプリは明日まで開けません。\(earnHintText)"
        case .lockedSchedule:
            return "チケットでも開けられない時間帯です。"
        case .lockedLocation:
            return "この場所ではチケットでも開けられません。"
        case .dailyGoalPending:
            return "今日の目標を達成するまで制限します（\(goalProgressText)）。"
        case .dailyGoalReached:
            return "今日の目標を達成しました。\(goalBonusStatusText)"
        case .studyTimer:
            return "勉強タイマー中のため制限しています。"
        case .blockedSchedule:
            if let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart {
                return "使用禁止の時間帯です。次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))。"
            }
            return "使用禁止の時間帯です。"
        case .blockedLocation:
            return "決めた場所にいるため制限しています。この場所を離れると解除されます。"
        case .allowedSchedule:
            return "無料開放の時間帯です。チケットは減りません。"
        case .alwaysRestricted:
            guard settings.ticketsEnabled else {
                return "常に制限がオンです。\(nextFreeOpeningDetailText)"
            }
            return "チケットを1枚使うと\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ開けられます。"
        case .activeTicket:
            return "チケットの残り時間だけ使えます。"
        case .masterDisabled, .unrestricted, .none:
            return remainingAllowanceStatusText
        }
    }

    private var remainingAllowanceStatusText: String {
        guard settings.budgetRestrictionEnabled, let ledger = focusController.ticketLedger else {
            return "いまはどのルールにも当てはまっていません。"
        }
        return "対象アプリの持ち時間は残り\(ledger.remainingAllowanceMinutes)分です（目安）。"
    }

    private var goalBonusStatusText: String {
        settings.goalBonusAllowanceMinutes > 0
            ? "持ち時間に\(settings.goalBonusAllowanceMinutes)分のボーナスが入りました。"
            : "目標未達成による制限は解除されました。"
    }

    /// 無料開放枠の案内。壁を開ける手段が時間帯しかないときに使う。
    private var nextFreeOpeningDetailText: String {
        guard let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart else {
            return "無料開放の時間帯がないため、いまは開ける手段がありません。"
        }
        return "次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))です。"
    }

    private var earnHintText: String {
        guard settings.earnedAllowanceEnabled, settings.studyMinutesPerEarnedMinute > 0 else {
            return "明日また使えます。"
        }
        return "勉強\(settings.studyMinutesPerEarnedMinute)分ごとに持ち時間が1分増えます。"
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

    /// 許可が外れている間も警告を出す。以前は未許可だと警告ごと消えていて、
    /// 「制限しているつもりで何も効いていない」状態が見えなかった。
    private var warnings: [ScreenTimeWarning] {
        guard settings.isEnabled else { return [] }
        var items: [ScreenTimeWarning] = []

        if focusController.isProtectionInterrupted {
            items.append(
                ScreenTimeWarning(
                    id: "authorization-lost",
                    icon: "exclamationmark.shield.fill",
                    message: "Screen Timeの許可が外れているため、制限は一切かかっていません。この状態は記録に残ります。",
                    color: AppColors.danger,
                    actionTitle: "許可する",
                    action: { requestScreenTimeAuthorization() }
                )
            )
            return items
        }

        if focusController.isLocationProtectionInterrupted {
            items.append(
                ScreenTimeWarning(
                    id: "location-authorization",
                    icon: "location.slash.fill",
                    message: "場所の制限には位置情報の「常に許可」が必要です。許可がないあいだ、場所ルールは動きません。",
                    color: AppColors.danger,
                    actionTitle: "許可する",
                    action: { requestLocationAuthorization() }
                )
            )
        }

        // 許可アプリが空だと ManagedSettings 側は shield を解除するため、実際には何も制限されない。
        if settings.requiresAllowedSelection, !settings.canApplyRestrictions {
            items.append(
                ScreenTimeWarning(
                    id: "allowed-selection",
                    icon: "exclamationmark.triangle.fill",
                    message: focusController.requiresRestoredActivitySelection
                        ? "ほかの端末の設定を復元しました。対象アプリはこの端末で選び直してください。"
                        : "「制限中も使えるもの」が未選択のため、壁のルールが何も効いていません。",
                    color: AppColors.danger,
                    actionTitle: "選ぶ",
                    action: {
                        showActivityPicker(for: .allowedDuringRestriction)
                    }
                )
            )
        }

        if settings.budgetRestrictionEnabled, !settings.hasBudgetSelection {
            items.append(
                ScreenTimeWarning(
                    id: "budget-selection",
                    icon: "hourglass",
                    message: "「時間を決めて使うもの」が未選択のため、使用時間が測れていません。",
                    color: AppColors.danger,
                    actionTitle: "選ぶ",
                    action: {
                        showActivityPicker(for: .dailyBudget)
                    }
                )
            )
        }

        if settings.activeRuleCount == 0 {
            items.append(
                ScreenTimeWarning(
                    id: "no-rule",
                    icon: "questionmark.circle.fill",
                    message: "制限するルールが1つも選ばれていません。",
                    color: AppColors.warning
                )
            )
        }

        if settings.budgetRestrictionEnabled,
           ScreenTimeAllowance.maximumPossibleMinutes(settings: settings) == 0 {
            items.append(
                ScreenTimeWarning(
                    id: "no-allowance",
                    icon: "hourglass.bottomhalf.filled",
                    message: "持ち時間が0分です。このままだと対象アプリは1日中開けません。",
                    color: AppColors.warning
                )
            )
        }

        // 常に制限は、チケットも無料開放枠も無いと二度と開かない設定になる。
        if settings.alwaysRestrictEnabled, !hasAnyWayToOpenWall {
            items.append(
                ScreenTimeWarning(
                    id: "always-no-escape",
                    icon: "lock.trianglebadge.exclamationmark.fill",
                    message: "「常に制限」がオンですが、チケットも無料開放の時間帯もありません。このままだと解除する手段がありません。",
                    color: AppColors.warning
                )
            )
        }

        if settings.ticketsEnabled, settings.dailyTicketCount == 0 {
            items.append(
                ScreenTimeWarning(
                    id: "no-ticket",
                    icon: "ticket.fill",
                    message: "チケットが0枚です。壁を一時的に開ける手段がありません。",
                    color: AppColors.warning
                )
            )
        }

        // 常に制限がオンの間、チケットで開ける使用禁止の枠は壁を何も足さない。
        // 表示だけが「この時間帯だけ禁止」に見えて誤解を生むので警告する。
        if settings.scheduleSlots.contains(where: { isRedundantBlockSlot($0) }) {
            items.append(
                ScreenTimeWarning(
                    id: "redundant-block-slot",
                    icon: "calendar.badge.exclamationmark",
                    message: "「常に制限」がオンなので、チケットで開ける使用禁止の時間帯は何も変えません。無料開放にするか、チケットでも開けない設定にしてください。",
                    color: AppColors.warning
                )
            )
        }

        if settings.scheduledRestrictionEnabled, settings.enabledScheduleSlots.isEmpty {
            items.append(
                ScreenTimeWarning(
                    id: "no-slot",
                    icon: "calendar.badge.exclamationmark",
                    message: "時間帯が登録されていません。",
                    color: AppColors.warning
                )
            )
        }

        if settings.locationRestrictionEnabled, settings.enabledLocationZones.isEmpty {
            items.append(
                ScreenTimeWarning(
                    id: "no-location-zone",
                    icon: "mappin.slash",
                    message: "場所が登録されていません。地図で位置を指定してください。場所は端末ごとに設定します。",
                    color: AppColors.warning
                )
            )
        }

        return items
    }

    /// 「常に制限」がすでに同じ壁を立てているため、何も足していない使用禁止の枠。
    private func isRedundantBlockSlot(_ slot: FocusScheduleSlot) -> Bool {
        settings.isEnabled
            && settings.alwaysRestrictEnabled
            && settings.scheduledRestrictionEnabled
            && slot.isEnabled
            && slot.hasSelectedWeekday
            && slot.behavior == .block
            && slot.allowsTicketBypass
    }

    /// 壁を開ける手段があるか。チケットか、無料開放の時間帯のどちらか。
    private var hasAnyWayToOpenWall: Bool {
        if settings.ticketsEnabled, settings.dailyTicketCount > 0 { return true }
        guard settings.scheduledRestrictionEnabled else { return false }
        return settings.enabledScheduleSlots.contains { $0.behavior == .allow && $0.hasSelectedWeekday }
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

    // MARK: - おすすめ設定

    /// ルールが1つも選ばれていない間だけ出す。全オフから組み立てるのは負担が大きい。
    private var shouldShowPresets: Bool {
        canEditSettings && focusController.isAuthorized && settings.activeRuleCount == 0
    }

    private var presetCard: some View {
        settingsGroup(title: "おすすめ設定") {
            VStack(spacing: 0) {
                ForEach(Array(ScreenTimeFocusPreset.all.enumerated()), id: \.element.id) { index, preset in
                    if index > 0 {
                        Divider()
                    }
                    presetRow(preset)
                }
            }
        } footer: {
            Text("当てたあとで細かく変えられます。対象アプリの選択はこの端末で行ってください。")
        }
    }

    private func presetRow(_ preset: ScreenTimeFocusPreset) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 30, height: 30)
                    .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(preset.summary)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColors.success)
                    }
                    Text(preset.detail)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("当てる")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 持ち時間

    private var allowanceCard: some View {
        settingsGroup(title: "今日の持ち時間") {
            if let ledger = focusController.ticketLedger {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("残り")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(ledger.remainingAllowanceMinutes)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        ledger.remainingAllowanceMinutes > 0 ? AppColors.textPrimary : AppColors.danger
                                    )
                                Text("/ \(ledger.totalAllowanceMinutes)分")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("使用（目安）")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(ledger.usageMilestoneMinutes)分")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    allowanceBar(ledger: ledger)
                    allowanceBreakdown(ledger: ledger)
                }
                .padding(.vertical, 4)
            } else {
                Text("持ち時間を準備しています。")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        } footer: {
            Text(allowanceFooterText)
        }
    }

    private func allowanceBar(ledger: ScreenTimeTicketLedger) -> some View {
        GeometryReader { geometry in
            let ratio = ledger.allowanceProgressRatio
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.subtleBackground)
                Capsule()
                    .fill(ratio >= 1 ? AppColors.danger : AppColors.blue)
                    .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
    }

    private func allowanceBreakdown(ledger: ScreenTimeTicketLedger) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                breakdownChip(title: "基本", minutes: ledger.baseAllowanceMinutes, color: AppColors.textSecondary)
                if settings.earnedAllowanceEnabled {
                    breakdownChip(title: "勉強で", minutes: ledger.earnedAllowanceMinutes, color: AppColors.success, showsPlus: true)
                }
                if settings.goalBonusAllowanceMinutes > 0 {
                    breakdownChip(title: "達成", minutes: ledger.bonusAllowanceMinutes, color: AppColors.blue, showsPlus: true)
                }
                Spacer(minLength: 0)
            }
            if let hint = nextEarnHint(ledger: ledger) {
                Text(hint)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.success)
            }
        }
    }

    private func breakdownChip(title: String, minutes: Int, color: Color, showsPlus: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
            Text("\(showsPlus ? "+" : "")\(minutes)分")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }

    /// 次の +1分まであと何分勉強すればよいか。稼ぐ動機を具体的に見せる。
    private func nextEarnHint(ledger: ScreenTimeTicketLedger) -> String? {
        guard settings.earnedAllowanceEnabled,
              settings.studyMinutesPerEarnedMinute > 0,
              ledger.earnedAllowanceMinutes < settings.earnedAllowanceCapMinutes else {
            return nil
        }
        let rate = settings.studyMinutesPerEarnedMinute
        let remainder = ledger.studyMinutes % rate
        let needed = remainder == 0 ? rate : rate - remainder
        return "あと\(needed)分勉強すると持ち時間が1分増えます"
    }

    private var allowanceFooterText: String {
        let resolution = focusController.usageResolutionMinutes
        var text = "使用時間はiOSから届く到達通知をもとにした目安です"
        if resolution > 0 {
            text += "（最大\(resolution)分ほど少なく出ます）"
        }
        text += "。増やす変更は翌日から、減らす変更はすぐ反映されます。"
        return text
    }

    // MARK: - 実績

    private var reportCard: some View {
        ScreenTimeUsageReportCard(
            summary: focusController.usageSummary,
            resolutionMinutes: focusController.usageResolutionMinutes,
            isBudgetRuleEnabled: settings.budgetRestrictionEnabled
        )
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
                        title: "次に使えるまで",
                        value: nextTicketText(at: context.date),
                        color: AppColors.textPrimary
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

    private func nextTicketText(at date: Date) -> String {
        if let remaining = activeTicketRemainingText(at: date) {
            return "利用中 \(remaining)"
        }
        guard let ledger = focusController.ticketLedger,
              let available = ledger.nextTicketAvailableDate(at: date, settings: settings),
              available > date else {
            return ticketRemainingCount(at: date) > 0 ? "いま使える" : "—"
        }
        let seconds = max(Int(ceil(available.timeIntervalSince(date))), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func isTicketCoolingDown(at date: Date) -> Bool {
        focusController.ticketLedger?.isInTicketCooldown(at: date, settings: settings) == true
    }

    private func ticketCanStart(at date: Date) -> Bool {
        guard focusController.isAuthorized,
              ticketRemainingCount(at: date) > 0,
              !isTicketCoolingDown(at: date),
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
        if isTicketCoolingDown(at: date) {
            return "次のチケットまで待機中"
        }
        if focusController.policyDecision?.canStartTicket != true {
            return "いまは使えません"
        }
        return "チケット1枚で\(ScreenTimeFocusSettings.ticketDurationMinutes)分使う"
    }

    private func ticketButtonIcon(at date: Date) -> String {
        if focusController.ticketLedger?.hasActiveTicket(at: date) == true { return "hourglass" }
        if isTicketCoolingDown(at: date) { return "clock.badge.exclamationmark" }
        return "play.fill"
    }

    private func ticketFooterText(at date: Date) -> String {
        if focusController.ticketLedger?.hasActiveTicket(at: date) == true {
            return "チケットの時間は使用禁止時間帯に入っても止まりません。"
        }
        if isTicketCoolingDown(at: date), let ledger = focusController.ticketLedger {
            return "続けて使えないよう\(ledger.cooldownMinutes(settings: settings))分の間隔をあけています。"
        }
        switch focusController.policyDecision?.reason {
        case .budgetExhausted:
            return "持ち時間の使い切りはチケットでは開けられません。\(earnHintText)"
        case .lockedSchedule:
            return "いまは「解除不可」の時間帯なので、チケットは使えません。"
        case .lockedLocation:
            return "いまは「解除不可」の場所なので、チケットは使えません。"
        case .dailyGoalPending:
            return "チケット1枚で、目標未達成の制限を\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ解除できます。"
        case .studyTimer:
            return "チケット1枚で、勉強タイマー中の制限を\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ解除できます。"
        case .blockedSchedule:
            if let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart {
                return "使用禁止の時間帯です。次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))。"
            }
            return "チケット1枚で、使用禁止時間帯の制限を\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ解除できます。"
        case .blockedLocation:
            return "チケット1枚で、この場所の制限を\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ解除できます。"
        case .allowedSchedule:
            return "無料開放の時間帯なので、チケットは消費されません。"
        case .dailyGoalReached:
            return "目標未達成による制限は解除されています。"
        default:
            return "1枚で開始から\(ScreenTimeFocusSettings.ticketDurationMinutes)分間、壁を開けられます。使っていない時間も進みます。"
        }
    }

    private var ticketConfirmationMessage: String {
        var text = "開始すると\(ScreenTimeFocusSettings.ticketDurationMinutes)分間利用できます。途中で停止できず、使っていない時間も進みます。"
        if let ledger = focusController.ticketLedger {
            let nextCooldown = max(settings.ticketCooldownMinutes, 0)
                + max(settings.ticketCooldownEscalationMinutes, 0) * ledger.usedTicketCount
            if nextCooldown > 0 {
                text += "\n終了後は\(nextCooldown)分あけないと次のチケットを使えません。"
            }
        }
        return text
    }

    // MARK: - 使いすぎ防止（持ち時間ルール）

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("使いすぎ防止")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("対象アプリを「1日に何分まで」で区切ります")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.leading, 11)

            VStack(spacing: 0) {
                ruleRow(
                    icon: "hourglass",
                    title: "時間を決めて使う",
                    detail: settings.budgetRestrictionEnabled
                        ? "1日の上限に達したら、選んだアプリを閉じます"
                        : "アプリごとに1日の使用時間を決めます",
                    isOn: Binding(
                        get: { settings.budgetRestrictionEnabled },
                        set: { enabled in
                            applyFocusSettings { $0.budgetRestrictionEnabled = enabled }
                        }
                    )
                )

                if settings.budgetRestrictionEnabled {
                    subRowDivider
                    budgetTargetRow
                    subRowDivider
                    minutesRow(
                        icon: "clock",
                        title: "1日の上限",
                        detail: "毎日0時にリセット",
                        selectionTitle: "上限を選択",
                        value: Binding(
                            get: { settings.baseAllowanceMinutes },
                            set: { minutes in
                                applyFocusSettings { $0.baseAllowanceMinutes = minutes }
                            }
                        )
                    )
                    subRowDivider
                    allowanceBoostRows
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
            .disabled(!canEditSettings)
            .opacity(settings.isEnabled ? 1 : 0.55)

            groupFooter(budgetFooterText)
        }
    }

    private var budgetFooterText: String {
        if !settings.isEnabled {
            return "集中制限がオフの間は、どのルールも動きません。"
        }
        if !canEditSettings {
            return "厳格ロック中のため変更できません。"
        }
        // 増やす手段が実際に有効なときだけ「増やせる」と言う。
        if settings.earnedAllowanceEnabled || settings.goalBonusAllowanceMinutes > 0 {
            return "このルールはチケットでは開けられません。増やす手段は勉強と目標達成だけです。"
        }
        return "このルールはチケットでは開けられません。使い切ると翌日まで開けられません。"
    }

    private var budgetTargetRow: some View {
        Button {
            showActivityPicker(for: .dailyBudget)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: settings.hasBudgetSelection ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(settings.hasBudgetSelection ? AppColors.success : AppColors.danger)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("対象のアプリ・Webサイト")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(budgetSelectionSummary)
                        .font(.caption2)
                        .foregroundStyle(settings.hasBudgetSelection ? AppColors.textSecondary : AppColors.danger)
                }

                Spacer(minLength: 8)

                Text(settings.hasBudgetSelection ? "変更" : "選択")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.success)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.leading, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var budgetSelectionSummary: String {
        let apps = focusController.budgetApplicationCount
        let categories = focusController.budgetCategoryCount
        let webs = focusController.budgetWebDomainCount
        guard apps > 0 || categories > 0 || webs > 0 else {
            return "未選択（使用時間が測れません）"
        }
        var parts: [String] = []
        if categories > 0 { parts.append("カテゴリ \(categories)件") }
        if apps > 0 { parts.append("アプリ \(apps)件") }
        if webs > 0 { parts.append("Webサイト \(webs)件") }
        return parts.joined(separator: "・")
    }

    private var earnRuleRows: some View {
        VStack(spacing: 0) {
            ruleRow(
                icon: "arrow.up.circle",
                title: "勉強した分だけ増やす",
                detail: "勉強時間に応じて持ち時間がたまります",
                indented: true,
                isOn: Binding(
                    get: { settings.earnedAllowanceEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.earnedAllowanceEnabled = enabled }
                    }
                )
            )

            if settings.earnedAllowanceEnabled {
                subRowDivider
                subRow(
                    icon: "arrow.left.arrow.right",
                    title: "交換レート",
                    detail: "勉強\(settings.studyMinutesPerEarnedMinute)分で持ち時間1分"
                ) {
                    Stepper(
                        value: Binding(
                            get: { settings.studyMinutesPerEarnedMinute },
                            set: { rate in
                                applyFocusSettings { $0.studyMinutesPerEarnedMinute = rate }
                            }
                        ),
                        in: 1...ScreenTimeFocusSettings.maximumStudyMinutesPerEarnedMinute
                    ) {
                        Text("\(settings.studyMinutesPerEarnedMinute):1")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                }
                subRowDivider
                minutesRow(
                    icon: "arrow.up.to.line",
                    title: "稼げる上限",
                    detail: "1日にこれ以上は増えません",
                    selectionTitle: "上限を選択",
                    value: Binding(
                        get: { settings.earnedAllowanceCapMinutes },
                        set: { minutes in
                            applyFocusSettings { $0.earnedAllowanceCapMinutes = minutes }
                        }
                    )
                )
            }
        }
    }

    private var allowanceBoostRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("上限を増やすルール")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .textCase(.uppercase)
                .padding(.leading, 58)
                .padding(.top, 12)
                .padding(.bottom, 4)

            earnRuleRows

            subRowDivider
            minutesRow(
                icon: "trophy",
                title: "目標達成ボーナス",
                detail: "今日の学習目標を達成したら追加",
                selectionTitle: "ボーナスを選択",
                value: Binding(
                    get: { settings.goalBonusAllowanceMinutes },
                    set: { minutes in
                        applyFocusSettings { $0.goalBonusAllowanceMinutes = minutes }
                    }
                )
            )
        }
    }

    // MARK: - 壁のルール

    private var wallRulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("壁のルール")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("許可したアプリ以外を止めます。複数を同時にオンにできます")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.leading, 11)

            VStack(spacing: 0) {
                scheduleRuleRows
                Divider()
                locationRuleRow
                Divider()
                timerRuleRow
                Divider()
                goalRuleRows
                Divider()
                alwaysRuleRow
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
            } else {
                groupFooter("同時に成り立ったときは、いちばん強い理由が画面に表示されます。")
            }
        }
    }

    private var scheduleRuleRows: some View {
        ruleRow(
            icon: "calendar.badge.clock",
            title: "決めた時間帯",
            detail: scheduleRuleDetailText,
            isOn: Binding(
                get: { settings.scheduledRestrictionEnabled },
                set: { enabled in
                    applyFocusSettings { $0.scheduledRestrictionEnabled = enabled }
                }
            )
        )
    }

    /// 時間帯の役割は「常に制限」の状態で変わる。オンなら壁に穴を開ける側、
    /// オフなら壁を立てる側になるので、説明もそれに合わせる。
    private var scheduleRuleDetailText: String {
        settings.alwaysRestrictEnabled
            ? "曜日と時刻ごとに、無料開放する時間を決めます"
            : "曜日と時刻ごとに、使用禁止／無料開放を切り替えます"
    }

    private var locationRuleRow: some View {
        ruleRow(
            icon: "mappin.and.ellipse",
            title: "決めた場所",
            detail: "指定した場所にいるあいだ制限します。場所は端末ごとに設定します",
            isOn: Binding(
                get: { settings.locationRestrictionEnabled },
                set: { enabled in
                    setLocationRestrictionEnabled(enabled)
                }
            )
        )
    }

    private var timerRuleRow: some View {
        ruleRow(
            icon: "timer",
            title: "勉強タイマー中",
            detail: "タイマーを開始している間だけ制限します",
            isOn: Binding(
                get: { settings.timerRestrictionEnabled },
                set: { enabled in
                    applyFocusSettings { $0.timerRestrictionEnabled = enabled }
                }
            )
        )
    }

    private var goalRuleRows: some View {
        VStack(spacing: 0) {
            ruleRow(
                icon: "target",
                title: "目標未達成の間は制限",
                detail: "達成するとこの制限だけ解除され、ボーナスが入ります",
                isOn: Binding(
                    get: { settings.goalRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.goalRestrictionEnabled = enabled }
                    }
                )
            )

            if settings.goalRestrictionEnabled {
                subRowDivider
                subRow(icon: "chart.line.uptrend.xyaxis", title: "今日の進み具合", detail: goalProgressStatusText) {
                    Text(goalProgressText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(goalProgress?.hasReachedTarget == true ? AppColors.success : AppColors.textPrimary)
                }

                Text("達成しても他のルールは動き続けます（手動で追加した学習記録は進み具合に含みません）。")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 46)
                    .padding(.bottom, 10)
            }
        }
    }

    private var alwaysRuleRow: some View {
        ruleRow(
            icon: "lock",
            title: "常に制限",
            detail: "いつでも制限します。無料開放の時間帯とチケットだけが開けます",
            isOn: Binding(
                get: { settings.alwaysRestrictEnabled },
                set: { enabled in
                    applyFocusSettings { $0.alwaysRestrictEnabled = enabled }
                }
            )
        )
    }

    // MARK: - チケットの設定

    private var ticketRuleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("チケット")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("壁を\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ開ける鍵です。持ち時間は減りません")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.leading, 11)

            VStack(spacing: 0) {
                ruleRow(
                    icon: "ticket",
                    title: "チケットを使えるようにする",
                    detail: "壁のルールを一時的に開けられます",
                    isOn: Binding(
                        get: { settings.ticketsEnabled },
                        set: { enabled in
                            applyFocusSettings { $0.ticketsEnabled = enabled }
                        }
                    )
                )

                if settings.ticketsEnabled {
                    subRowDivider
                    subRow(
                        icon: "number",
                        title: "1日の枚数",
                        detail: "最大\(settings.dailyTicketCount * ScreenTimeFocusSettings.ticketDurationMinutes)分ぶん"
                    ) {
                        Stepper(
                            value: Binding(
                                get: { settings.dailyTicketCount },
                                set: { count in
                                    applyFocusSettings { $0.dailyTicketCount = count }
                                }
                            ),
                            in: 0...ScreenTimeFocusSettings.maximumDailyTicketCount
                        ) {
                            Text("\(settings.dailyTicketCount)枚")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }
                    subRowDivider
                    subRow(
                        icon: "clock.arrow.circlepath",
                        title: "次に使えるまでの間隔",
                        detail: "続けて使えないようにします"
                    ) {
                        Stepper(
                            value: Binding(
                                get: { settings.ticketCooldownMinutes },
                                set: { minutes in
                                    applyFocusSettings { $0.ticketCooldownMinutes = minutes }
                                }
                            ),
                            in: 0...ScreenTimeFocusSettings.maximumTicketCooldownMinutes,
                            step: 5
                        ) {
                            Text("\(settings.ticketCooldownMinutes)分")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }
                    subRowDivider
                    subRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "使うほど間隔を伸ばす",
                        detail: cooldownEscalationDetail
                    ) {
                        Stepper(
                            value: Binding(
                                get: { settings.ticketCooldownEscalationMinutes },
                                set: { minutes in
                                    applyFocusSettings { $0.ticketCooldownEscalationMinutes = minutes }
                                }
                            ),
                            in: 0...ScreenTimeFocusSettings.maximumTicketCooldownMinutes,
                            step: 5
                        ) {
                            Text("+\(settings.ticketCooldownEscalationMinutes)分")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(minWidth: 48, alignment: .trailing)
                        }
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
            .disabled(!canEditSettings)
            .opacity(settings.isEnabled ? 1 : 0.55)

            groupFooter("「解除不可」に指定した時間帯と、持ち時間の使い切りはチケットでも開けられません。")
        }
    }

    private var cooldownEscalationDetail: String {
        guard settings.ticketCooldownEscalationMinutes > 0 else {
            return "1枚ごとに間隔を増やしません"
        }
        let base = settings.ticketCooldownMinutes
        let step = settings.ticketCooldownEscalationMinutes
        return "1枚目\(base)分 → 2枚目\(base + step)分 → 3枚目\(base + step * 2)分"
    }

    // MARK: - 行の共通レイアウト

    private func ruleRow(
        icon: String,
        title: String,
        detail: String,
        indented: Bool = false,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.success)
                .frame(width: 30, height: 30)
                .background(AppColors.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
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
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.leading, 16)
        .padding(.vertical, 9)
    }

    /// 分数の設定行。現在値と増減操作をひとまとまりにし、よく使う値はメニューへ集約する。
    /// 横一列の小さなプリセット群と Stepper の重複を避け、どの画面幅でも44ptの操作領域を保つ。
    private func minutesRow(
        icon: String,
        title: String,
        detail: String,
        selectionTitle: String,
        value: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

                Text("\(value.wrappedValue)分")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                minuteAdjustmentButton(
                    systemImage: "minus",
                    accessibilityLabel: "\(title)を\(ScreenTimeFocusSettings.allowanceStepMinutes)分減らす",
                    isDisabled: value.wrappedValue == 0
                ) {
                    value.wrappedValue = max(0, value.wrappedValue - ScreenTimeFocusSettings.allowanceStepMinutes)
                }

                Menu {
                    ForEach(Self.minutePresets, id: \.self) { preset in
                        Button {
                            value.wrappedValue = preset
                        } label: {
                            if value.wrappedValue == preset {
                                Label("\(preset)分", systemImage: "checkmark")
                            } else {
                                Text("\(preset)分")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectionTitle)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColors.subtleBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                minuteAdjustmentButton(
                    systemImage: "plus",
                    accessibilityLabel: "\(title)を\(ScreenTimeFocusSettings.allowanceStepMinutes)分増やす",
                    isDisabled: value.wrappedValue == ScreenTimeFocusSettings.maximumAllowanceMinutes
                ) {
                    value.wrappedValue = min(
                        ScreenTimeFocusSettings.maximumAllowanceMinutes,
                        value.wrappedValue + ScreenTimeFocusSettings.allowanceStepMinutes
                    )
                }
            }
            .padding(.leading, 42)
        }
        .padding(.leading, 16)
        .padding(.vertical, 12)
    }

    private static let minutePresets = [0, 15, 30, 45, 60, 90, 120]

    private func minuteAdjustmentButton(
        systemImage: String,
        accessibilityLabel: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isDisabled ? AppColors.textSecondary : AppColors.success)
                .frame(width: 48, height: 44)
                .background(AppColors.subtleBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
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

    // MARK: - 場所

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("場所")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(enabledLocationCountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
            .padding(.horizontal, 11)

            VStack(spacing: 0) {
                if settings.locationZones.isEmpty {
                    Text("まだ登録されていません。学校や図書館など、制限したい場所を追加してください。場所は端末ごとに設定します。")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(settings.locationZones.enumerated()), id: \.element.id) { index, zone in
                        if index > 0 {
                            Divider()
                        }
                        locationZoneRow(zone)
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
                addLocationZone()
            } label: {
                Label("場所を追加", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(canAddLocationZone ? AppColors.success : AppColors.textSecondary)
                    .background(
                        canAddLocationZone ? AppColors.greenSoft : AppColors.subtleBackground,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAddLocationZone)
        }
    }

    private var canAddLocationZone: Bool {
        canEditSettings &&
            settings.locationZones.filter(\.isEnabled).count < ScreenTimeFocusSettings.maximumEnabledLocationZones
    }

    private var enabledLocationCountText: String {
        let zones = settings.locationZones
        guard !zones.isEmpty else { return "未登録" }
        return "\(zones.filter(\.isEnabled).count) / \(zones.count) オン"
    }

    private func locationZoneRow(_ zone: FocusLocationZone) -> some View {
        HStack(spacing: 11) {
            Button {
                editingZone = LocationEditorTarget(id: zone.id)
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 30, height: 30)
                        .background(AppColors.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(zone.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                            if zone.isNonNegotiableBlock {
                                Text("解除不可")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.danger)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.danger.opacity(0.14), in: Capsule())
                            }
                        }
                        Text(locationZoneDetail(zone))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("有効", isOn: Binding(
                get: { zone.isEnabled },
                set: { enabled in
                    updateLocationZone(id: zone.id) { $0.isEnabled = enabled }
                }
            ))
            .labelsHidden()
            .tint(AppColors.success)
            .disabled(!canEditSettings)
        }
        .padding(.vertical, 10)
    }

    private func locationZoneDetail(_ zone: FocusLocationZone) -> String {
        if !zone.coordinateWasSet {
            return "位置が未指定"
        }
        return "半径\(zone.radiusMeters)m"
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
                        HStack(spacing: 6) {
                            Text(ScreenTimeFormat.timeRangeText(slot))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppColors.textPrimary)
                            if slot.isNonNegotiableBlock {
                                Text("解除不可")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.danger)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.danger.opacity(0.14), in: Capsule())
                            }
                            if isRedundantBlockSlot(slot) {
                                Text("効果なし")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.warning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.warning.opacity(0.14), in: Capsule())
                            }
                        }
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
                showActivityPicker(for: .allowedDuringRestriction)
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
            .disabled(!canEditSettings && !focusController.requiresRestoredActivitySelection)
        } footer: {
            Text("壁のルールが動いているとき、ここで選んだものだけ開けます。1つも選ばないと壁そのものが立ちません。")
        }
    }

    private var allowedSelectionSummary: String {
        let appCount = focusController.allowedApplicationCount
        let webCount = focusController.allowedWebDomainCount
        if appCount == 0, webCount == 0 {
            return "未選択（壁が立ちません）"
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
            Text("一度オンにすると期限まで解除できません。iOSの設定アプリからScreen Timeの許可を取り消すことはできますが、その場合は制限が外れた記録が残ります。")
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

        var candidate = settings
        update(&candidate)

        if candidate.requiresBudgetSelection, !candidate.hasBudgetSelection {
            pendingSettings = candidate
            showActivityPicker(for: .dailyBudget)
            return
        }

        if candidate.requiresAllowedSelection, !hasAllowedSelection(candidate) {
            pendingSettings = candidate
            showActivityPicker(for: .allowedDuringRestriction)
            return
        }

        commitFocusSettings { $0 = candidate }
    }

    @discardableResult
    private func commitFocusSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) -> Bool {
        guard canEditSettings else { return false }
        do {
            try focusController.updateSettings(update)
            Task { await refreshGoalProgress(reason: "screen-time-settings") }
            return true
        } catch {
            app.present(error)
            return false
        }
    }

    private func applyPreset(_ preset: ScreenTimeFocusPreset) {
        applyFocusSettings { settings in
            preset.apply(&settings)
        }
    }

    private func updateScheduleSlot(id: String, update: (inout FocusScheduleSlot) -> Void) {
        applyFocusSettings { settings in
            guard let index = settings.scheduleSlots.firstIndex(where: { $0.id == id }) else { return }
            update(&settings.scheduleSlots[index])
        }
    }

    private func addScheduleSlot() {
        applyFocusSettings { settings in
            let nextIndex = settings.scheduleSlots.count + 1
            settings.scheduleSlots.append(
                FocusScheduleSlot(title: "時間帯 \(nextIndex)")
            )
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

    private func setLocationRestrictionEnabled(_ enabled: Bool) {
        if enabled {
            Task { await enableLocationRestriction() }
            return
        }
        applyFocusSettings { $0.locationRestrictionEnabled = false }
    }

    @MainActor
    private func enableLocationRestriction() async {
        do {
            try await focusController.requestLocationAuthorization()
            applyFocusSettings { $0.locationRestrictionEnabled = true }
        } catch {
            app.present(error)
        }
    }

    private func updateLocationZone(id: String, update: (inout FocusLocationZone) -> Void) {
        applyFocusSettings { settings in
            guard let index = settings.locationZones.firstIndex(where: { $0.id == id }) else { return }
            update(&settings.locationZones[index])
        }
    }

    private func addLocationZone() {
        var createdID: String?
        applyFocusSettings { settings in
            let nextIndex = settings.locationZones.count + 1
            let zone = FocusLocationZone(title: "場所 \(nextIndex)", isEnabled: false)
            createdID = zone.id
            settings.locationZones.append(zone)
        }
        if let createdID {
            editingZone = LocationEditorTarget(id: createdID)
        }
    }

    private func removeLocationZone(id: String) {
        do {
            if editingZone?.id == id {
                editingZone = nil
            }
            try focusController.removeLocationZone(id: id)
            Task { await refreshGoalProgress(reason: "screen-time-remove-location") }
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

    private func requestLocationAuthorization() {
        Task {
            do {
                try await focusController.requestLocationAuthorization()
                await refreshGoalProgress(reason: "screen-time-location-authorization")
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

    private struct LocationEditorTarget: Identifiable, Equatable {
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
                 ? "この時間は許可したアプリ以外を制限します。"
                 : "この時間は壁のルールを解除し、チケットも消費しません。")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if slot.behavior == .block {
                Divider()
                    .padding(.vertical, 8)

                Toggle(isOn: Binding(
                    get: { !slot.allowsTicketBypass },
                    set: { locked in
                        onUpdate(slot.id) { $0.allowsTicketBypass = !locked }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("チケットでも開けられない")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("就寝時間のように、交渉の余地をなくしたい時間帯に使います。")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppColors.danger)
                .frame(minHeight: 44)
            }
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
                .foregroundStyle(isSelected ? Color.white : AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    isSelected ? AppColors.success : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func weekdayChip(_ slot: FocusScheduleSlot, weekday: Int) -> some View {
        let isSelected = slot.weekdays.contains(weekday)
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
                .foregroundStyle(isSelected ? Color.white : AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    isSelected ? AppColors.success : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ScreenTimeFormat.weekdayShortTitle(weekday))曜日")
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("この時間帯を削除", systemImage: "trash")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(AppColors.danger)
                .background(AppColors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func timeBinding(_ slot: FocusScheduleSlot, endpoint: TimeEndpoint) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let hour = endpoint == .start ? slot.startHour : slot.endHour
                let minute = endpoint == .start ? slot.startMinute : slot.endMinute
                return calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: calendar.startOfDay(for: Date())
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
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
