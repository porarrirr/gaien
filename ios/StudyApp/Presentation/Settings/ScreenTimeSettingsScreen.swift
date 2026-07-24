import FamilyControls
import SwiftUI

struct ScreenTimeSettingsScreen: View {
    @ObservedObject private var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController
    @State private var isShowingAllowedAppsPicker = false
    @State private var focusPickerSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var goalProgress: ScreenTimeDailyGoalProgress?
    @State private var lockMonths = 0
    @State private var lockDays = 1
    @State private var isShowingLockConfirmation = false
    @State private var isShowingTicketConfirmation = false
    @State private var expandedScheduleTimePicker: ScheduleTimePickerTarget?

    init(app: StudyAppContainer) {
        _app = ObservedObject(wrappedValue: app)
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                permissionGroup
                if focusController.settings.ticketRestrictionEnabled {
                    ticketDashboardGroup
                }
                restrictionGroup
                if focusController.settings.ticketRestrictionEnabled {
                    ticketSettingsGroup
                }
                strictLockGroup
                allowedSelectionGroup
                if focusController.settings.scheduledRestrictionEnabled {
                    scheduleGroup
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .strictScreen()
        .navigationTitle("Screen Time")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            headerText: "集中制限中も使えるアプリとWebサイトを選択してください",
            footerText: "選択されていないアプリとWebサイトは集中制限中に開けなくなります。",
            isPresented: $isShowingAllowedAppsPicker,
            selection: $focusPickerSelection
        )
        .onChange(of: focusPickerSelection) { selection in
            guard canEditSettings else { return }
            applyFocusSettings { settings in
                settings.activitySelection = selection
            }
        }
        .task(id: app.dataVersion) {
            await refreshGoalProgress(reason: "screen-time-settings-data")
        }
        .onAppear {
            focusController.refresh()
            focusPickerSelection = focusController.settings.activitySelection
        }
        .confirmationDialog(
            "厳格ロックを有効にしますか？",
            isPresented: $isShowingLockConfirmation,
            titleVisibility: .visible
        ) {
            Button("ロックする", role: .destructive) {
                activateStrictLock()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(strictLockConfirmationMessage)
        }
        .confirmationDialog(
            "10分チケットを使いますか？",
            isPresented: $isShowingTicketConfirmation,
            titleVisibility: .visible
        ) {
            Button("10分使う") {
                startTicket()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("開始後は使っていない時間も進み、0時をまたぐ場合は0時に終了します。")
        }
        .task(id: focusController.ticketLedger?.activeTicketEndsAt) {
            guard let expiry = focusController.ticketLedger?.activeTicketEndDate else { return }
            let delay = max(expiry.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await refreshGoalProgress(reason: "screen-time-ticket-expired")
        }
    }

    private var canEditSettings: Bool {
        !focusController.isSettingsLocked
    }

    private var permissionGroup: some View {
        settingsGroup(title: "利用状態") {
            if focusController.isAvailable {
                compactInfoRow(
                    icon: "hourglass",
                    title: "Screen Time",
                    value: focusController.authorizationStatusText,
                    color: focusController.isAuthorized ? AppColors.success : AppColors.warning,
                    showsStatusDot: true
                )

                Divider()

                actionLine(
                    icon: focusController.isAuthorized ? "checkmark.shield" : "shield",
                    title: focusController.isAuthorized ? "許可を更新" : "Screen Timeを許可",
                    color: AppColors.success
                ) {
                    Task {
                        do {
                            try await focusController.requestAuthorization()
                            await refreshGoalProgress(reason: "screen-time-authorization")
                        } catch {
                            app.present(error)
                        }
                    }
                }
            } else {
                Text("iOS 16以降で利用できます")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var restrictionGroup: some View {
        settingsGroup(title: "集中制限") {
            focusToggleRow(
                icon: "lock.shield",
                title: "集中制限を使用",
                isOn: Binding(
                    get: { focusController.settings.isEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.isEnabled = enabled }
                    }
                )
            )
            .disabled(!canEditSettings)

            Divider()

            focusToggleRow(
                icon: "timer",
                title: "タイマー実行中に制限",
                isOn: Binding(
                    get: { focusController.settings.timerRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.timerRestrictionEnabled = enabled }
                    }
                )
            )
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            Divider()

            focusToggleRow(
                icon: "ticket",
                title: "10分チケット制",
                isOn: Binding(
                    get: { focusController.settings.ticketRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.ticketRestrictionEnabled = enabled }
                    }
                )
            )
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            Divider()

            focusToggleRow(
                icon: "calendar.badge.clock",
                title: "時間帯ルール",
                isOn: Binding(
                    get: { focusController.settings.scheduledRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.scheduledRestrictionEnabled = enabled }
                    }
                )
            )
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            if focusController.settings.scheduledRestrictionEnabled,
               !focusController.settings.ticketRestrictionEnabled {
                Divider()

                focusToggleRow(
                    icon: "clock.badge.xmark",
                    title: "時間帯外も使用禁止",
                    isOn: Binding(
                        get: { focusController.settings.restrictOutsideScheduleWhenTicketsDisabled },
                        set: { enabled in
                            applyFocusSettings {
                                $0.restrictOutsideScheduleWhenTicketsDisabled = enabled
                            }
                        }
                    )
                )
                .disabled(!canEditSettings || !focusController.settings.isEnabled)
            }

            Divider()

            focusToggleRow(
                icon: "target",
                title: "今日の目標達成で解除",
                isOn: Binding(
                    get: { focusController.settings.unlockRestrictionsWhenDailyGoalReached },
                    set: { enabled in
                        applyFocusSettings { $0.unlockRestrictionsWhenDailyGoalReached = enabled }
                    }
                )
            )
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            if focusController.settings.unlockRestrictionsWhenDailyGoalReached {
                Divider()
                compactInfoRow(
                    icon: "target",
                    title: "今日の目標",
                    value: goalProgressText,
                    color: goalProgress?.hasReachedTarget == true ? AppColors.success : AppColors.textSecondary,
                    showsStatusDot: goalProgress?.hasReachedTarget == true
                )
            }
        } footer: {
            Text("今日の1日目標に到達した日は、チケット・タイマー・時間帯によるScreen Time制限を終日解除します。手動記録は解除判定に含めません。")
        }
    }

    private var ticketDashboardGroup: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            settingsGroup(title: "今日のチケット") {
                compactInfoRow(
                    icon: "ticket.fill",
                    title: "残り",
                    value: ticketCountText(at: context.date),
                    color: ticketRemainingCount(at: context.date) > 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                    showsStatusDot: ticketRemainingCount(at: context.date) > 0
                )

                Divider()

                compactInfoRow(
                    icon: "clock",
                    title: "現在の状態",
                    value: ticketCurrentStatusText(at: context.date),
                    color: focusController.ticketLedger?.hasActiveTicket(at: context.date) == true
                        ? AppColors.success
                        : AppColors.textSecondary
                )

                Divider()

                Button {
                    isShowingTicketConfirmation = true
                } label: {
                    Label("10分チケットを使う", systemImage: "play.fill")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(Color.white)
                        .background(
                            ticketCanStart(at: context.date)
                                ? AppColors.success
                                : AppColors.textSecondary,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
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

    private var ticketSettingsGroup: some View {
        settingsGroup(title: "チケット設定") {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "clock.badge.checkmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("1日の利用時間")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(ticketSettingsApplyTimingText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Stepper(
                    value: Binding(
                        get: { focusController.settings.dailyTicketMinutes },
                        set: { minutes in
                            applyFocusSettings { $0.dailyTicketMinutes = minutes }
                        }
                    ),
                    in: ScreenTimeFocusSettings.minimumDailyTicketMinutes...ScreenTimeFocusSettings.maximumDailyTicketMinutes,
                    step: ScreenTimeFocusSettings.ticketDurationMinutes
                ) {
                    Text("\(focusController.settings.dailyTicketMinutes)分")
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(minWidth: 72, alignment: .trailing)
                }
                .labelsHidden()
            }
            .frame(minHeight: 52)
            .disabled(!canEditSettings)

            Divider()

            compactInfoRow(
                icon: "ticket",
                title: "発行枚数",
                value: "\(focusController.settings.dailyTicketMinutes / ScreenTimeFocusSettings.ticketDurationMinutes)枚",
                color: AppColors.textSecondary
            )
        } footer: {
            Text(ticketSettingsFooterText)
        }
    }

    private var strictLockGroup: some View {
        settingsGroup(title: "厳格ロック") {
            if focusController.isSettingsLocked, let expiryDate = focusController.settingsLockExpiryDate {
                compactInfoRow(
                    icon: "lock.fill",
                    title: "ロック中",
                    value: lockDateText(expiryDate),
                    color: AppColors.warning,
                    showsStatusDot: true
                )

                Divider()

                compactInfoRow(
                    icon: "clock",
                    title: "残り期間",
                    value: lockRemainingText(until: expiryDate),
                    color: AppColors.textSecondary
                )
            } else {
                lockDurationStepper(
                    title: "か月",
                    value: $lockMonths,
                    range: 0...24
                )

                Divider()

                lockDurationStepper(
                    title: "日",
                    value: $lockDays,
                    range: 0...31
                )

                Divider()

                compactInfoRow(
                    icon: "calendar",
                    title: "変更可能日",
                    value: proposedLockExpiryText,
                    color: proposedLockExpiryDate == nil ? AppColors.danger : AppColors.textSecondary
                )

                Divider()

                actionLine(
                    icon: "lock.shield.fill",
                    title: "厳格ロックを有効にする",
                    color: proposedLockExpiryDate == nil ? AppColors.textSecondary : AppColors.warning
                ) {
                    isShowingLockConfirmation = true
                }
                .disabled(proposedLockExpiryDate == nil)
            }
        } footer: {
            if focusController.isSettingsLocked {
                Text("ロック中も10分チケットは使用できます。設定変更はできず、今日の目標達成による解除はロック開始時に有効だった場合のみ適用されます。")
            } else {
                Text("有効にすると、指定した期間が過ぎるまでScreen Time設定を変更できなくなります。チケットの使用は可能です。iOSの設定アプリからScreen Time許可を取り消すことは可能です。")
            }
        }
    }

    private var allowedSelectionGroup: some View {
        settingsGroup(title: "許可する対象") {
            actionLine(
                icon: "apps.iphone",
                title: focusAllowedSelectionTitle,
                color: AppColors.success
            ) {
                focusPickerSelection = focusController.settings.activitySelection
                isShowingAllowedAppsPicker = true
            }
            .disabled(!canEditSettings || !focusController.settings.isEnabled)
        } footer: {
            Text("選択したアプリとWebサイトだけを制限中も開けるようにします。Safari内のWebサイトも対象です。")
        }
    }

    private var scheduleGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("時間指定")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("無料開放または使用禁止の時間を登録します")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(enabledScheduleCountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.greenSoft, in: Capsule())
            }
            .padding(.horizontal, 4)

            if focusController.settings.scheduleSlots.isEmpty {
                scheduleEmptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(focusController.settings.scheduleSlots) { slot in
                        scheduleSlotCard(slot)
                    }
                }
            }

            addScheduleButton
        }
    }

    private var proposedLockExpiryDate: Date? {
        ScreenTimeFocusSettings.lockExpiryDate(from: Date(), months: lockMonths, days: lockDays)
    }

    private var proposedLockExpiryText: String {
        guard let proposedLockExpiryDate else { return "1日以上を指定" }
        return lockDateText(proposedLockExpiryDate)
    }

    private var strictLockConfirmationMessage: String {
        guard let proposedLockExpiryDate else {
            return "ロック期間は1日以上を指定してください。"
        }
        return "\(lockDurationSummary)後の\(lockDateText(proposedLockExpiryDate))まで、Screen Time設定を変更できなくなります。"
    }

    private var lockDurationSummary: String {
        switch (lockMonths, lockDays) {
        case (0, let days):
            return "\(days)日"
        case (let months, 0):
            return "\(months)か月"
        case (let months, let days):
            return "\(months)か月\(days)日"
        }
    }

    private var focusAllowedSelectionTitle: String {
        let appCount = focusController.allowedApplicationCount
        let webCount = focusController.allowedWebDomainCount
        if webCount > 0 {
            return "アプリ・Webサイト（アプリ\(appCount)件 / Web\(webCount)件）"
        }
        return "アプリ・Webサイト（アプリ\(appCount)件）"
    }

    private var goalProgressText: String {
        guard let goalProgress else { return "読み込み中" }
        guard goalProgress.hasTarget else { return "1日の目標未設定" }
        return "\(Goal.format(minutes: goalProgress.studyMinutes)) / \(Goal.format(minutes: goalProgress.targetMinutes))"
    }

    private func ticketRemainingCount(at date: Date) -> Int {
        guard let ledger = focusController.ticketLedger,
              ledger.isForDay(containing: date) else {
            return 0
        }
        return ledger.remainingTicketCount
    }

    private var canUpdateTodayTicketCount: Bool {
        guard let ledger = focusController.ticketLedger else {
            return true
        }
        return ledger.canUpdateIssuedTicketCount(at: Date())
    }

    private var ticketSettingsApplyTimingText: String {
        canUpdateTodayTicketCount ? "今日からすぐ反映" : "次の0時から反映"
    }

    private var ticketSettingsFooterText: String {
        if canUpdateTodayTicketCount {
            return "今日まだチケットを使っていないため、設定した枚数をすぐ利用できます。"
        }
        return "今日はすでにチケットを使用しているため、変更は次の0時から反映されます。"
    }

    private func ticketCountText(at date: Date) -> String {
        guard let ledger = focusController.ticketLedger,
              ledger.isForDay(containing: date) else {
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

    private func ticketCurrentStatusText(at date: Date) -> String {
        if let expiry = focusController.ticketLedger?.activeTicketEndDate,
           focusController.ticketLedger?.hasActiveTicket(at: date) == true {
            let seconds = max(Int(ceil(expiry.timeIntervalSince(date))), 0)
            return String(format: "利用中 %d:%02d", seconds / 60, seconds % 60)
        }
        switch focusController.policyDecision?.reason {
        case .dailyGoalReached:
            return "目標達成で終日開放"
        case .studyTimer:
            return "学習タイマーで制限中"
        case .blockedSchedule:
            return "使用禁止時間帯"
        case .allowedSchedule:
            return "無料開放時間帯"
        case .ticketRequired:
            return "チケット待ち"
        case .outsideScheduleBlocked:
            return "時間帯外のため制限中"
        case .masterDisabled:
            return "集中制限オフ"
        case .activeTicket:
            return "チケット利用中"
        case .unrestricted, .none:
            return "使用できます"
        }
    }

    private func ticketFooterText(at date: Date) -> String {
        if focusController.ticketLedger?.hasActiveTicket(at: date) == true {
            return "チケットの時間は使用禁止時間帯に入っても停止しません。"
        }
        switch focusController.policyDecision?.reason {
        case .studyTimer:
            return "学習タイマー中はチケットを使えません。"
        case .blockedSchedule:
            if let nextStart = focusController.accessSnapshot?.nextAllowedScheduleStart {
                return "使用禁止時間帯です。次の無料開放は\(Self.shortDateTimeFormatter.string(from: nextStart))です。"
            }
            return "使用禁止時間帯はチケットを使えません。"
        case .allowedSchedule:
            return "無料開放時間帯のため、チケットは消費されません。"
        case .dailyGoalReached:
            return "今日の学習目標を達成したため、終日開放されています。"
        default:
            return "1枚で開始から10分間利用できます。使用中に次の券は使えません。"
        }
    }

    private var enabledScheduleCountText: String {
        let slots = focusController.settings.scheduleSlots
        guard !slots.isEmpty else { return "未登録" }
        let enabledCount = slots.filter(\.isEnabled).count
        return "\(enabledCount) / \(slots.count) オン"
    }

    private var scheduleEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppColors.success)
                .frame(width: 52, height: 52)
                .background(AppColors.greenSoft, in: Circle())
            Text("時間帯はまだありません")
                .font(.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text("無料開放または使用禁止にする時間を追加できます。")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var addScheduleButton: some View {
        Button {
            do {
                try focusController.addScheduleSlot()
                Task { await refreshGoalProgress(reason: "screen-time-add-schedule") }
            } catch {
                app.present(error)
            }
        } label: {
            Label("時間帯を追加", systemImage: "plus")
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Color.white)
                .background(AppColors.success, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(
            !canEditSettings ||
            focusController.settings.enabledScheduleSlots.count >=
                focusController.settings.maximumEnabledSlotsForCurrentConfiguration
        )
        .accessibilityHint("新しい集中時間を追加します")
    }

    private func scheduleSlotCard(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduleSlotHeader(slot)

            Divider()
                .padding(.vertical, 14)

            scheduleBehaviorSelector(slot)

            Divider()
                .padding(.vertical, 14)

            scheduleTimeRange(slot)

            if expandedScheduleTimePicker?.slotID == slot.id {
                inlineScheduleTimePicker(slot)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .padding(.vertical, 14)

            weekdaySelector(slot)

            if let validationMessage = scheduleValidationMessage(slot) {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.danger)
                    .padding(.top, 12)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    slot.isEnabled ? AppColors.success.opacity(0.32) : AppColors.cardBorder,
                    lineWidth: slot.isEnabled ? 1.5 : 1
                )
        }
        .disabled(!canEditSettings)
    }

    private func scheduleSlotHeader(_ slot: FocusScheduleSlot) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(slot.isEnabled ? AppColors.success : AppColors.textSecondary)
                .frame(width: 38, height: 38)
                .background(
                    slot.isEnabled ? AppColors.greenSoft : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(
                    slot.isEnabled
                        ? "\(slot.behavior.title)としてオン"
                        : "この時間帯はオフです"
                )
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { slot.isEnabled },
                set: { enabled in
                    updateScheduleSlot(id: slot.id) { $0.isEnabled = enabled }
                }
            ))
            .labelsHidden()
            .tint(AppColors.success)
            .accessibilityLabel("\(slot.title)を有効にする")

            Menu {
                Button(role: .destructive) {
                    removeScheduleSlot(slot)
                } label: {
                    Label("この時間帯を削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.subtleBackground, in: Circle())
            }
            .accessibilityLabel("\(slot.title)のその他の操作")
        }
    }

    private func scheduleBehaviorSelector(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("この時間帯の動作", systemImage: "switch.2")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            Picker(
                "この時間帯の動作",
                selection: Binding(
                    get: { slot.behavior },
                    set: { behavior in
                        updateScheduleSlot(id: slot.id) { $0.behavior = behavior }
                    }
                )
            ) {
                ForEach(FocusScheduleBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func scheduleTimeRange(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("時刻", systemImage: "clock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(scheduleDurationText(slot))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.success)
            }

            HStack(spacing: 9) {
                scheduleTimeButton(
                    title: "開始",
                    hour: slot.startHour,
                    minute: slot.startMinute,
                    target: ScheduleTimePickerTarget(slotID: slot.id, endpoint: .start)
                )

                Image(systemName: "arrow.right")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)

                scheduleTimeButton(
                    title: crossesMidnight(slot) ? "終了・翌日" : "終了",
                    hour: slot.endHour,
                    minute: slot.endMinute,
                    target: ScheduleTimePickerTarget(slotID: slot.id, endpoint: .end)
                )
            }
        }
    }

    private func scheduleTimeButton(
        title: String,
        hour: Int,
        minute: Int,
        target: ScheduleTimePickerTarget
    ) -> some View {
        let isExpanded = expandedScheduleTimePicker == target
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedScheduleTimePicker = isExpanded ? nil : target
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 5) {
                    Text(Self.timeText(hour: hour, minute: minute))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.success)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(
                isExpanded ? AppColors.greenSoft : AppColors.subtleBackground,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isExpanded ? AppColors.success.opacity(0.55) : AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)時刻、\(Self.timeText(hour: hour, minute: minute))")
        .accessibilityHint("タップして時刻を変更します")
    }

    @ViewBuilder
    private func inlineScheduleTimePicker(_ slot: FocusScheduleSlot) -> some View {
        if let target = expandedScheduleTimePicker, target.slotID == slot.id {
            let title = target.endpoint == .start ? "開始時刻" : "終了時刻"
            VStack(spacing: 4) {
                HStack {
                    Text(title)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button("完了") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedScheduleTimePicker = nil
                        }
                    }
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.success)
                }

                DatePicker(
                    title,
                    selection: scheduleTimeBinding(slot: slot, endpoint: target.endpoint),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipped()
            }
            .padding(12)
            .background(AppColors.subtleBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func scheduleTimeBinding(slot: FocusScheduleSlot, endpoint: ScheduleTimeEndpoint) -> Binding<Date> {
        Binding(
            get: {
                switch endpoint {
                case .start:
                    return scheduleDate(hour: slot.startHour, minute: slot.startMinute)
                case .end:
                    return scheduleDate(hour: slot.endHour, minute: slot.endMinute)
                }
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                updateScheduleSlot(id: slot.id) {
                    switch endpoint {
                    case .start:
                        $0.startHour = components.hour ?? slot.startHour
                        $0.startMinute = components.minute ?? slot.startMinute
                    case .end:
                        $0.endHour = components.hour ?? slot.endHour
                        $0.endMinute = components.minute ?? slot.endMinute
                    }
                }
            }
        )
    }

    private func removeScheduleSlot(_ slot: FocusScheduleSlot) {
        do {
            if expandedScheduleTimePicker?.slotID == slot.id {
                expandedScheduleTimePicker = nil
            }
            try focusController.removeScheduleSlot(id: slot.id)
            Task { await refreshGoalProgress(reason: "screen-time-remove-schedule") }
        } catch {
            app.present(error)
        }
    }

    private func scheduleValidationMessage(_ slot: FocusScheduleSlot) -> String? {
        guard slot.isEnabled else { return nil }
        if slot.startHour == slot.endHour, slot.startMinute == slot.endMinute {
            return "開始と終了を異なる時刻にしてください"
        }
        if !slot.hasSelectedWeekday {
            return "繰り返す曜日を1日以上選択してください"
        }
        return nil
    }

    private func scheduleDurationText(_ slot: FocusScheduleSlot) -> String {
        let start = slot.startHour * 60 + slot.startMinute
        let end = slot.endHour * 60 + slot.endMinute
        guard start != end else { return "時刻を確認" }
        let duration = end > start ? end - start : 24 * 60 - start + end
        let hours = duration / 60
        let minutes = duration % 60
        let durationText: String
        switch (hours, minutes) {
        case (0, let minutes):
            durationText = "\(minutes)分"
        case (let hours, 0):
            durationText = "\(hours)時間"
        case (let hours, let minutes):
            durationText = "\(hours)時間\(minutes)分"
        }
        return end < start ? "翌日まで・\(durationText)" : durationText
    }

    private func crossesMidnight(_ slot: FocusScheduleSlot) -> Bool {
        let start = slot.startHour * 60 + slot.startMinute
        let end = slot.endHour * 60 + slot.endMinute
        return end < start
    }

    private func weekdaySelector(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("繰り返し", systemImage: "repeat")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(weekdaysSummary(slot))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slot.hasSelectedWeekday ? AppColors.textSecondary : AppColors.danger)
            }

            HStack(spacing: 7) {
                scheduleWeekdayPreset(slot: slot, title: "毎日", weekdays: FocusScheduleSlot.allWeekdays)
                scheduleWeekdayPreset(slot: slot, title: "平日", weekdays: [2, 3, 4, 5, 6])
                scheduleWeekdayPreset(slot: slot, title: "週末", weekdays: [1, 7])
            }

            HStack(spacing: 6) {
                ForEach(Self.orderedWeekdays, id: \.self) { weekday in
                    weekdayChip(slot: slot, weekday: weekday)
                }
            }
        }
    }

    private func scheduleWeekdayPreset(
        slot: FocusScheduleSlot,
        title: String,
        weekdays: Set<Int>
    ) -> some View {
        let isSelected = slot.weekdays == weekdays
        return Button {
            updateScheduleSlot(id: slot.id) { $0.weekdays = weekdays }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? AppColors.success : AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    isSelected ? AppColors.greenSoft : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSelected ? AppColors.success.opacity(0.4) : AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func weekdayChip(slot: FocusScheduleSlot, weekday: Int) -> some View {
        let isOn = slot.weekdays.contains(weekday)
        return Button {
            updateScheduleSlot(id: slot.id) { current in
                if current.weekdays.contains(weekday) {
                    current.weekdays.remove(weekday)
                } else {
                    current.weekdays.insert(weekday)
                }
            }
        } label: {
            Text(Self.weekdayShortTitle(weekday))
                .font(.caption.weight(.bold))
                .foregroundStyle(isOn ? Color.white : Self.weekdayColor(weekday))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    isOn ? AppColors.success : AppColors.subtleBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isOn ? AppColors.success : AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.weekdayLongTitle(weekday))曜日")
        .accessibilityValue(isOn ? "選択中" : "未選択")
    }

    private func weekdaysSummary(_ slot: FocusScheduleSlot) -> String {
        let selected = slot.weekdays
        if selected.isEmpty {
            return "曜日を選択"
        }
        if selected == FocusScheduleSlot.allWeekdays {
            return "毎日"
        }
        if selected == [2, 3, 4, 5, 6] {
            return "平日"
        }
        if selected == [1, 7] {
            return "週末"
        }
        return Self.orderedWeekdays
            .filter { selected.contains($0) }
            .map { Self.weekdayShortTitle($0) }
            .joined(separator: "・")
    }

    private func lockDurationStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: "calendar")
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)\(title)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(minWidth: 72, alignment: .trailing)
            }
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private func focusToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.success)
        }
        .frame(minHeight: 44)
    }

    private func applyFocusSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) {
        guard canEditSettings else { return }
        do {
            try focusController.updateSettings(update)
            Task { await refreshGoalProgress(reason: "screen-time-settings") }
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

    private func activateStrictLock() {
        do {
            try focusController.activateSettingsLock(months: lockMonths, days: lockDays)
            Task { await refreshGoalProgress(reason: "screen-time-strict-lock") }
        } catch {
            app.present(error)
        }
    }

    private func lockDateText(_ date: Date) -> String {
        Self.lockDateFormatter.string(from: date)
    }

    private func lockRemainingText(until expiryDate: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let dayCount = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day ?? 0
        if dayCount <= 0 {
            return "まもなく解除"
        }
        return "約\(dayCount)日"
    }

    private func updateScheduleSlot(id: String, update: (inout FocusScheduleSlot) -> Void) {
        applyFocusSettings { settings in
            guard let index = settings.scheduleSlots.firstIndex(where: { $0.id == id }) else { return }
            update(&settings.scheduleSlots[index])
        }
    }

    @MainActor
    private func refreshGoalProgress(reason: String) async {
        if let progress = await app.refreshScreenTimeFocusState(reason: reason) {
            goalProgress = progress
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
                .padding(.horizontal, 18)
        }
    }

    private func compactInfoRow(
        icon: String,
        title: String,
        value: String,
        color: Color = AppColors.textSecondary,
        showsStatusDot: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 24)
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            Spacer()
            if showsStatusDot {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(value)
                .font(.callout)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: 210, alignment: .trailing)
        }
        .frame(minHeight: 40)
    }

    private func actionLine(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
    }

    private func scheduleDate(hour: Int, minute: Int) -> Date {
        let now = Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private enum ScheduleTimeEndpoint {
        case start
        case end
    }

    private struct ScheduleTimePickerTarget: Equatable {
        let slotID: String
        let endpoint: ScheduleTimeEndpoint
    }

    /// Calendar weekday order shown in the picker: Sunday first, matching the app's other
    /// weekday views.
    private static let orderedWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    private static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func weekdayShortTitle(_ weekday: Int) -> String {
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

    private static func weekdayLongTitle(_ weekday: Int) -> String {
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

    private static func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return AppColors.danger
        case 7: return AppColors.blue
        default: return AppColors.textPrimary
        }
    }

    private static let lockDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d H:mm"
        return formatter
    }()
}

private struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 28, height: 28)
    }
}
