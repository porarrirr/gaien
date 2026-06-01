import FamilyControls
import SwiftUI

struct ScreenTimeSettingsScreen: View {
    @ObservedObject private var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController
    @State private var isShowingAllowedAppsPicker = false
    @State private var focusPickerSelection = FamilyActivitySelection()
    @State private var goalProgress: ScreenTimeDailyGoalProgress?

    init(app: StudyAppContainer) {
        _app = ObservedObject(wrappedValue: app)
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                permissionGroup
                restrictionGroup
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
            .disabled(!focusController.settings.isEnabled)

            Divider()

            focusToggleRow(
                icon: "calendar.badge.clock",
                title: "時間指定で制限",
                isOn: Binding(
                    get: { focusController.settings.scheduledRestrictionEnabled },
                    set: { enabled in
                        applyFocusSettings { $0.scheduledRestrictionEnabled = enabled }
                    }
                )
            )
            .disabled(!focusController.settings.isEnabled)

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
            .disabled(!focusController.settings.isEnabled)

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
            Text("今日の1日目標に到達した日は、タイマー中と時間指定のScreen Time制限を解除します。翌日は再び制限対象になります。")
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
            .disabled(!focusController.settings.isEnabled)
        } footer: {
            Text("選択したアプリとWebサイトだけを制限中も開けるようにします。Safari内のWebサイトも対象です。")
        }
    }

    private var scheduleGroup: some View {
        settingsGroup(title: "時間指定") {
            VStack(spacing: 0) {
                ForEach(focusController.settings.scheduleSlots) { slot in
                    scheduleSlotRow(slot)
                    if slot.id != focusController.settings.scheduleSlots.last?.id {
                        Divider()
                    }
                }

                if !focusController.settings.scheduleSlots.isEmpty {
                    Divider()
                }

                actionLine(icon: "plus.circle", title: "時間帯を追加", color: AppColors.success) {
                    do {
                        try focusController.addScheduleSlot()
                        Task { await refreshGoalProgress(reason: "screen-time-add-schedule") }
                    } catch {
                        app.present(error)
                    }
                }
            }
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

    private func scheduleSlotRow(_ slot: FocusScheduleSlot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SettingsIcon(systemName: "clock.badge")
                Text(slot.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { slot.isEnabled },
                    set: { enabled in
                        updateScheduleSlot(id: slot.id) { $0.isEnabled = enabled }
                    }
                ))
                .labelsHidden()
                .tint(AppColors.success)
                Button(role: .destructive) {
                    do {
                        try focusController.removeScheduleSlot(id: slot.id)
                        Task { await refreshGoalProgress(reason: "screen-time-remove-schedule") }
                    } catch {
                        app.present(error)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                scheduleDatePicker(
                    title: "開始",
                    date: Binding(
                        get: { scheduleDate(hour: slot.startHour, minute: slot.startMinute) },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                            updateScheduleSlot(id: slot.id) {
                                $0.startHour = components.hour ?? slot.startHour
                                $0.startMinute = components.minute ?? slot.startMinute
                            }
                        }
                    )
                )
                scheduleDatePicker(
                    title: "終了",
                    date: Binding(
                        get: { scheduleDate(hour: slot.endHour, minute: slot.endMinute) },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                            updateScheduleSlot(id: slot.id) {
                                $0.endHour = components.hour ?? slot.endHour
                                $0.endMinute = components.minute ?? slot.endMinute
                            }
                        }
                    )
                )
            }
        }
        .padding(.vertical, 8)
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

    private func scheduleDatePicker(title: String, date: Binding<Date>) -> some View {
        DatePicker(selection: date, displayedComponents: .hourAndMinute) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .datePickerStyle(.compact)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .offset(y: -10)
        }
        .padding(.top, 8)
    }

    private func applyFocusSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) {
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
