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
    @State private var isLockSetupExpanded = false

    init(app: StudyAppContainer) {
        _app = ObservedObject(wrappedValue: app)
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statusOverview
                if focusController.settings.ticketRestrictionEnabled {
                    ticketAccessSection
                }
                restrictionMethodsSection
                allowedAppsSection
                goalUnlockSection
                if focusController.settings.scheduledRestrictionEnabled {
                    scheduleGroup
                }
                safetyLockSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 36)
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

    private var statusOverview: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: overviewIcon)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(overviewColor)
                        .frame(width: 48, height: 48)
                        .background(overviewColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(overviewTitle(at: context.date))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(overviewSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if focusController.isAuthorized {
                        Toggle(
                            "集中制限を使用",
                            isOn: Binding(
                                get: { focusController.settings.isEnabled },
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
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(Color.white)
                            .background(AppColors.success, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if focusController.isAuthorized {
                    HStack(spacing: 8) {
                        statusPill(
                            icon: "checkmark.circle.fill",
                            text: "許可済み",
                            color: AppColors.success
                        )
                        if focusController.isSettingsLocked {
                            statusPill(
                                icon: "lock.fill",
                                text: "設定を固定中",
                                color: AppColors.warning
                            )
                        }
                        Spacer(minLength: 0)
                        Button("許可を更新") {
                            requestScreenTimeAuthorization()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(18)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(overviewColor.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private var ticketAccessSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                screenTimeSectionHeader(
                    number: nil,
                    title: "10分だけ使う",
                    subtitle: "必要なときだけチケットを1枚使います"
                )

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        ticketMetric(
                            title: "残り",
                            value: ticketCountText(at: context.date),
                            color: ticketRemainingCount(at: context.date) > 0
                                ? AppColors.success
                                : AppColors.textSecondary
                        )

                        Rectangle()
                            .fill(AppColors.cardBorder)
                            .frame(width: 1, height: 44)

                        ticketMetric(
                            title: "いま",
                            value: ticketCurrentStatusText(at: context.date),
                            color: focusController.ticketLedger?.hasActiveTicket(at: context.date) == true
                                ? AppColors.success
                                : AppColors.textPrimary
                        )
                    }

                    Button {
                        isShowingTicketConfirmation = true
                    } label: {
                        Label(ticketButtonTitle(at: context.date), systemImage: ticketButtonIcon(at: context.date))
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(ticketCanStart(at: context.date) ? Color.white : AppColors.textSecondary)
                            .background(
                                ticketCanStart(at: context.date)
                                    ? AppColors.success
                                    : AppColors.subtleBackground,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!ticketCanStart(at: context.date))

                    Text(ticketFooterText(at: context.date))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .screenTimePanel()
            }
            .onChange(of: Calendar.current.startOfDay(for: context.date)) { _ in
                Task {
                    await refreshGoalProgress(reason: "screen-time-ticket-day-changed")
                }
            }
        }
    }

    private var restrictionMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            screenTimeSectionHeader(
                number: "1",
                title: "いつ制限する？",
                subtitle: "使いたいルールだけオンにしてください"
            )

            VStack(spacing: 0) {
                focusOptionRow(
                    icon: "timer",
                    title: "勉強タイマー中",
                    detail: "タイマーを開始すると自動で制限",
                    isOn: Binding(
                        get: { focusController.settings.timerRestrictionEnabled },
                        set: { enabled in
                            applyFocusSettings { $0.timerRestrictionEnabled = enabled }
                        }
                    )
                )

                sectionDivider

                focusOptionRow(
                    icon: "ticket",
                    title: "チケットを使うまで",
                    detail: "10分ごとに1枚使って一時解除",
                    isOn: Binding(
                        get: { focusController.settings.ticketRestrictionEnabled },
                        set: { enabled in
                            applyFocusSettings { $0.ticketRestrictionEnabled = enabled }
                        }
                    )
                )

                if focusController.settings.ticketRestrictionEnabled {
                    sectionDivider

                    HStack(spacing: 13) {
                        optionIcon(systemName: "clock.badge.checkmark")
                        VStack(alignment: .leading, spacing: 3) {
                            Text("1日に使える時間")
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
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(minWidth: 64, alignment: .trailing)
                        }
                        .labelsHidden()
                    }
                    .padding(.vertical, 13)
                }

                sectionDivider

                focusOptionRow(
                    icon: "calendar.badge.clock",
                    title: "決めた時間帯",
                    detail: "曜日と時刻を指定して自動で切り替え",
                    isOn: Binding(
                        get: { focusController.settings.scheduledRestrictionEnabled },
                        set: { enabled in
                            applyFocusSettings { $0.scheduledRestrictionEnabled = enabled }
                        }
                    )
                )

                if focusController.settings.scheduledRestrictionEnabled,
                   !focusController.settings.ticketRestrictionEnabled {
                    sectionDivider

                    focusOptionRow(
                        icon: "clock.badge.xmark",
                        title: "時間帯の外も制限",
                        detail: "無料開放に指定した時間だけ使えます",
                        isOn: Binding(
                            get: { focusController.settings.restrictOutsideScheduleWhenTicketsDisabled },
                            set: { enabled in
                                applyFocusSettings {
                                    $0.restrictOutsideScheduleWhenTicketsDisabled = enabled
                                }
                            }
                        )
                    )
                }
            }
            .padding(.horizontal, 16)
            .screenTimePanel()
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            if !focusController.settings.isEnabled {
                disabledSectionHint
            }
        }
    }

    private var allowedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            screenTimeSectionHeader(
                number: "2",
                title: "制限中も使えるもの",
                subtitle: "連絡や調べものに必要なものを選びます"
            )

            Button {
                focusPickerSelection = focusController.settings.activitySelection
                isShowingAllowedAppsPicker = true
            } label: {
                HStack(spacing: 14) {
                    optionIcon(systemName: "apps.iphone")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("アプリとWebサイト")
                            .font(.body.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(allowedSelectionSummary)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("選ぶ")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.success)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(16)
                .screenTimePanel()
            }
            .buttonStyle(.plain)
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            Text("ここで選んだものだけ、集中制限中も開けます。")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 4)

            if !focusController.settings.isEnabled {
                disabledSectionHint
            }
        }
    }

    private var goalUnlockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            screenTimeSectionHeader(
                number: "3",
                title: "勉強できたら解除",
                subtitle: "今日の学習目標を達成した日に自動で開放します"
            )

            VStack(spacing: 0) {
                focusOptionRow(
                    icon: "target",
                    title: "目標達成で終日解除",
                    detail: "手動で追加した学習記録は含みません",
                    isOn: Binding(
                        get: { focusController.settings.unlockRestrictionsWhenDailyGoalReached },
                        set: { enabled in
                            applyFocusSettings { $0.unlockRestrictionsWhenDailyGoalReached = enabled }
                        }
                    )
                )

                if focusController.settings.unlockRestrictionsWhenDailyGoalReached {
                    sectionDivider

                    HStack(spacing: 13) {
                        optionIcon(systemName: "chart.line.uptrend.xyaxis")
                        VStack(alignment: .leading, spacing: 3) {
                            Text("今日の進み具合")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(goalProgress?.hasReachedTarget == true ? "目標を達成しました" : "目標まであと少し")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Text(goalProgressText)
                            .font(.callout.weight(.bold).monospacedDigit())
                            .foregroundStyle(
                                goalProgress?.hasReachedTarget == true
                                    ? AppColors.success
                                    : AppColors.textPrimary
                            )
                    }
                    .padding(.vertical, 13)
                }
            }
            .padding(.horizontal, 16)
            .screenTimePanel()
            .disabled(!canEditSettings || !focusController.settings.isEnabled)

            if !focusController.settings.isEnabled {
                disabledSectionHint
            }
        }
    }

    private var safetyLockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            screenTimeSectionHeader(
                number: nil,
                title: "設定を固定",
                subtitle: "自分で途中変更できないようにします"
            )

            VStack(spacing: 0) {
                if focusController.isSettingsLocked, let expiryDate = focusController.settingsLockExpiryDate {
                    HStack(spacing: 13) {
                        optionIcon(systemName: "lock.fill", color: AppColors.warning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("厳格ロック中")
                                .font(.body.weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(lockDateText(expiryDate))まで変更できません")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Text(lockRemainingText(until: expiryDate))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.warning)
                    }
                    .padding(.vertical, 16)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLockSetupExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 13) {
                            optionIcon(systemName: "lock.shield", color: AppColors.warning)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("厳格ロック")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("設定した期間が終わるまで変更を防ぎます")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isLockSetupExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    if isLockSetupExpanded {
                        sectionDivider

                        lockDurationStepper(
                            title: "か月",
                            value: $lockMonths,
                            range: 0...24
                        )

                        sectionDivider

                        lockDurationStepper(
                            title: "日",
                            value: $lockDays,
                            range: 0...31
                        )

                        sectionDivider

                        HStack(spacing: 13) {
                            optionIcon(systemName: "calendar")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("変更できる日")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(proposedLockExpiryText)
                                    .font(.caption)
                                    .foregroundStyle(
                                        proposedLockExpiryDate == nil
                                            ? AppColors.danger
                                            : AppColors.textSecondary
                                    )
                            }
                            Spacer()
                        }
                        .padding(.vertical, 13)

                        Text("一度オンにすると期限まで解除できません。iOSの設定アプリからScreen Timeの許可を取り消すことはできます。")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)

                        Button {
                            isShowingLockConfirmation = true
                        } label: {
                            Label("この期間で固定する", systemImage: "lock.fill")
                                .font(.body.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Color.white)
                                .background(
                                    proposedLockExpiryDate == nil
                                        ? AppColors.textSecondary
                                        : AppColors.warning,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(proposedLockExpiryDate == nil)
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .screenTimePanel()
        }
    }

    private var overviewIcon: String {
        if !focusController.isAvailable || !focusController.isAuthorized {
            return "shield.slash.fill"
        }
        if focusController.isSettingsLocked {
            return "lock.shield.fill"
        }
        return focusController.settings.isEnabled ? "checkmark.shield.fill" : "shield.fill"
    }

    private var overviewColor: Color {
        if !focusController.isAvailable || !focusController.isAuthorized {
            return AppColors.warning
        }
        if focusController.isSettingsLocked {
            return AppColors.warning
        }
        return focusController.settings.isEnabled ? AppColors.success : AppColors.textSecondary
    }

    private func overviewTitle(at date: Date) -> String {
        guard focusController.isAvailable else {
            return "この端末では使えません"
        }
        guard focusController.isAuthorized else {
            return "最初に使用を許可"
        }
        guard focusController.settings.isEnabled else {
            return "集中制限はオフ"
        }
        return ticketCurrentStatusText(at: date)
    }

    private var overviewSubtitle: String {
        guard focusController.isAvailable else {
            return "Screen TimeはiOS 16以降で利用できます。"
        }
        guard focusController.isAuthorized else {
            return "iPhoneのScreen Time機能を使って、勉強中の寄り道を防ぎます。"
        }
        guard focusController.settings.isEnabled else {
            return "右のスイッチをオンにすると、下のルールが有効になります。"
        }

        let activeMethodCount = [
            focusController.settings.timerRestrictionEnabled,
            focusController.settings.ticketRestrictionEnabled,
            focusController.settings.scheduledRestrictionEnabled
        ]
        .filter { $0 }
        .count

        if activeMethodCount == 0 {
            return "制限するタイミングを下から1つ以上選んでください。"
        }
        return "\(activeMethodCount)個のルールで自動的に切り替えます。"
    }

    private var allowedSelectionSummary: String {
        let appCount = focusController.allowedApplicationCount
        let webCount = focusController.allowedWebDomainCount
        if appCount == 0, webCount == 0 {
            return "まだ選択していません"
        }
        if webCount == 0 {
            return "アプリ \(appCount)件"
        }
        return "アプリ \(appCount)件・Webサイト \(webCount)件"
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.leading, 57)
    }

    private var disabledSectionHint: some View {
        Label("上の「集中制限」をオンにすると設定できます", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 4)
    }

    private func screenTimeSectionHeader(
        number: String?,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let number {
                Text(number)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(AppColors.success, in: Circle())
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }

    private func statusPill(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func ticketMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func ticketButtonTitle(at date: Date) -> String {
        if focusController.ticketLedger?.hasActiveTicket(at: date) == true {
            return "チケットを使用中"
        }
        if ticketRemainingCount(at: date) == 0 {
            return "今日のチケットは終了"
        }
        return "チケット1枚で10分使う"
    }

    private func ticketButtonIcon(at date: Date) -> String {
        focusController.ticketLedger?.hasActiveTicket(at: date) == true
            ? "hourglass"
            : "play.fill"
    }

    private func focusOptionRow(
        icon: String,
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 13) {
            optionIcon(systemName: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColors.success)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func optionIcon(
        systemName: String,
        color: Color = AppColors.success
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
            optionIcon(systemName: "calendar", color: AppColors.warning)
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

private struct ScreenTimePanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

private extension View {
    func screenTimePanel() -> some View {
        modifier(ScreenTimePanelModifier())
    }
}
