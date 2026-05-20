import FamilyControls
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var focusController: ScreenTimeFocusController
    @State private var isImporting = false
    @State private var isShowingExportOptions = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingAccountDeletionConfirmation = false
    @State private var isShowingAuthSheet = false
    @State private var isShowingDebugLogs = false
    @State private var isShowingAllowedAppsPicker = false
    @State private var focusPickerSelection = FamilyActivitySelection()
    @State private var versionTapCount = 0
    @State private var isDebugLogUnlocked = false
    @State private var copyConfirmationMessage: String?

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app))
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    var body: some View {
        settingsScrollView
            .strictScreen()
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingAuthSheet) {
                NavigationStack {
                    AuthSheet(viewModel: viewModel, isPresented: $isShowingAuthSheet)
                }
            }
            .sheet(isPresented: $isShowingDebugLogs) {
                NavigationStack {
                    DebugLogSheet(viewModel: viewModel, isClearUnlocked: true)
                }
            }
            .alert("デバッグログ", isPresented: Binding(get: { copyConfirmationMessage != nil }, set: { if !$0 { copyConfirmationMessage = nil } })) {
                Button("OK", role: .cancel) {
                    copyConfirmationMessage = nil
                }
            } message: {
                Text(copyConfirmationMessage ?? "")
            }
            .confirmationDialog("エクスポート形式", isPresented: $isShowingExportOptions, titleVisibility: .visible) {
                Button("JSON") {
                    viewModel.export(format: .json)
                }
                Button("CSV") {
                    viewModel.export(format: .csv)
                }
            }
            .confirmationDialog("全データを削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    viewModel.deleteAllData()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("学習記録、教材、科目、試験、計画データが削除されます。設定は保持します。")
            }
            .alert("アカウントを削除しますか？", isPresented: $isShowingAccountDeletionConfirmation) {
                SecureField("現在のパスワード", text: $viewModel.accountDeletionPassword)
                Button("削除する", role: .destructive) {
                    viewModel.deleteSyncAccount()
                }
                Button("キャンセル", role: .cancel) {
                    viewModel.accountDeletionPassword = ""
                }
            } message: {
                Text("クラウド同期アカウント、クラウド上の同期データ、この端末の学習データを削除します。この操作は元に戻せません。")
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    viewModel.importBackup(from: url)
                }
            }
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
            .task(id: viewModel.app.dataVersion) {
                await viewModel.load()
            }
            .onAppear {
                focusController.refresh()
                focusPickerSelection = focusController.settings.activitySelection
            }
    }

    private var settingsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appearanceGroup
                timerVisualGroup
                screenTimeFocusGroup
                reminderGroup
                landscapeTimerGroup
                liveActivityGroup
                dashboardCards
                debugLogCard
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }

    private var screenTimeFocusGroup: some View {
        settingsGroup(title: "集中制限") {
            if focusController.isAvailable {
                compactInfoRow(
                    icon: "hourglass.badge.shield",
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
                        } catch {
                            viewModel.app.present(error)
                        }
                    }
                }

                Divider()

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

                actionLine(
                    icon: "apps.iphone",
                    title: focusAllowedSelectionTitle,
                    color: AppColors.success
                ) {
                    focusPickerSelection = focusController.settings.activitySelection
                    isShowingAllowedAppsPicker = true
                }
                .disabled(!focusController.settings.isEnabled)

                if focusController.settings.scheduledRestrictionEnabled {
                    Divider()
                    scheduleSlotList
                }
            } else {
                Text("iOS 16以降で利用できます")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        } footer: {
            Text("許可したアプリとWebサイト以外は、タイマー実行中または指定時間帯にScreen Timeで制限されます。Safari内のWebサイトも対象です。")
        }
    }

    private var focusAllowedSelectionTitle: String {
        let appCount = focusController.allowedApplicationCount
        let webCount = focusController.allowedWebDomainCount
        if webCount > 0 {
            return "許可するアプリ・Webサイト（アプリ\(appCount)件 / Web\(webCount)件）"
        }
        return "許可するアプリ・Webサイト（アプリ\(appCount)件）"
    }

    private var scheduleSlotList: some View {
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
                } catch {
                    viewModel.app.present(error)
                }
            }
        }
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
                    } catch {
                        viewModel.app.present(error)
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

    private var appearanceGroup: some View {
        settingsGroup(title: "テーマ設定") {
            Menu {
                ForEach(ThemeMode.allCases) { mode in
                    Button(mode.title) {
                        viewModel.app.setThemeMode(mode)
                    }
                }
            } label: {
                settingsRow(icon: "paintbrush", title: "テーマ", value: viewModel.app.preferences.selectedThemeMode.title)
            }

            Divider()

            Menu {
                ForEach(ColorTheme.allCases) { theme in
                    Button(theme.title) {
                        viewModel.app.setColorTheme(theme)
                    }
                }
            } label: {
                settingsRow(icon: "paintpalette", title: "カラー", value: viewModel.app.preferences.selectedColorTheme.title, color: viewModel.app.preferences.selectedColorTheme.primaryColor)
            }
        }
    }

    private var reminderGroup: some View {
        settingsGroup(title: "通知") {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "bell")
                Text("毎日のリマインダー")
                    .font(.body.weight(.semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { viewModel.app.preferences.reminderEnabled }, set: { enabled in
                    Task { await viewModel.app.setReminderEnabled(enabled) }
                }))
                .labelsHidden()
                .tint(AppColors.success)
            }
            .frame(minHeight: 44)

            Divider()

            DatePicker(
                selection: Binding(
                    get: { reminderDate(hour: viewModel.app.preferences.reminderHour, minute: viewModel.app.preferences.reminderMinute) },
                    set: { newValue in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        Task {
                            await viewModel.app.setReminderTime(
                                hour: components.hour ?? viewModel.app.preferences.reminderHour,
                                minute: components.minute ?? viewModel.app.preferences.reminderMinute
                            )
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            ) {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "clock")
                    Text("通知時刻")
                        .font(.body.weight(.semibold))
                }
            }
            .disabled(!viewModel.app.preferences.reminderEnabled)
        } footer: {
            Text("※時間割の未復習が48時間を超えた場合に通知します")
        }
    }

    private var timerVisualGroup: some View {
        settingsGroup(title: "タイマー表示") {
            ForEach(Array(TimerVisualMode.allCases.enumerated()), id: \.element.id) { index, mode in
                Button {
                    viewModel.app.setTimerVisualMode(mode)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: timerVisualIcon(for: mode))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(mode.settingsDescription)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if mode == viewModel.app.preferences.timerVisualMode {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < TimerVisualMode.allCases.count - 1 {
                    Divider()
                }
            }
        } footer: {
            Text("自動では現在地の天気と日の出・日の入りを使って、朝・昼・夜を切り替えます。")
        }
    }

    private var landscapeTimerGroup: some View {
        settingsGroup(title: "横向きタイマーの表示") {
            ForEach(Array(LandscapeTimerDisplayPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                Button {
                    viewModel.app.setLandscapeTimerDisplayPreset(preset)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: preset == .problemProgress ? "square.grid.3x3" : "timer")
                        Text(settingsTitle(for: preset))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        if preset == viewModel.app.preferences.landscapeTimerDisplayPreset {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < LandscapeTimerDisplayPreset.allCases.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var dashboardCards: some View {
        VStack(alignment: .leading, spacing: 18) {
            dataSummaryCard
            cloudSyncCard
            backupCard
            dangerCard
        }
    }

    private var liveActivityGroup: some View {
        settingsGroup(title: "Live Activity") {
            if liveActivityFeatureIncludedInBuild, liveActivitySettingsAvailable {
                Toggle(isOn: Binding(get: { viewModel.app.preferences.liveActivityEnabled }, set: { viewModel.app.setLiveActivityEnabled($0) })) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "waveform")
                        Text("Live Activityを使用")
                            .font(.body.weight(.semibold))
                    }
                }
                .tint(AppColors.success)
                Divider()
                Menu {
                    ForEach(LiveActivityDisplayPreset.allCases) { preset in
                        Button(preset.title) {
                            viewModel.app.setLiveActivityDisplayPreset(preset)
                        }
                    }
                } label: {
                    settingsRow(icon: "list.bullet", title: "表示プリセット", value: settingsTitle(for: viewModel.app.preferences.liveActivityDisplayPreset))
                }
                .disabled(!viewModel.app.preferences.liveActivityEnabled)
            } else {
                Text(liveActivityFeatureIncludedInBuild ? "iOS 16.2以降で利用できます" : "このビルドでは Live Activity を含めていません")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var dataSummaryCard: some View {
        settingsGroup(title: "データ概要") {
            compactInfoRow(icon: "chart.bar", title: "学習記録数", value: "\(formattedCount(viewModel.summary.totalSessions)) 件")
            Divider()
            compactInfoRow(icon: "clock", title: "総学習時間", value: totalStudyTimeText)
        }
    }

    private var cloudSyncCard: some View {
        settingsGroup(title: "クラウド同期") {
            if viewModel.app.syncStatus.isAuthenticated {
                compactInfoRow(icon: "cloud", title: "接続中", value: "接続中", color: AppColors.success, showsStatusDot: true)
                Divider()
                compactInfoRow(icon: "person", title: "メールアドレス", value: viewModel.app.syncStatus.email ?? "-")
                Divider()
                compactInfoRow(icon: "clock", title: "最終同期", value: viewModel.app.syncStatus.lastSyncAt.map { StudyFormatters.slashTimestamp.string(from: Date(epochMilliseconds: $0)) } ?? "未同期")
                Divider()
                actionLine(icon: "arrow.triangle.2.circlepath", title: viewModel.app.syncStatus.isSyncing ? "同期中..." : "今すぐ同期", color: AppColors.success) {
                    viewModel.syncNow()
                }
                .disabled(viewModel.app.syncStatus.isSyncing)
                Divider()
                actionLine(icon: "icloud.and.arrow.up", title: "ローカルデータをアップロード", color: AppColors.success) {
                    viewModel.importLocalDataToCloud()
                }
                .disabled(viewModel.app.syncStatus.isSyncing)
                Divider()
                actionLine(icon: "rectangle.portrait.and.arrow.right", title: "サインアウト", color: AppColors.danger) {
                    viewModel.signOutOfSync()
                }
                Divider()
                actionLine(icon: "person.crop.circle.badge.xmark", title: "アカウントを削除", color: AppColors.danger) {
                    isShowingAccountDeletionConfirmation = true
                }
            } else if let unavailableMessage = FirebaseBootstrap.status.unavailableMessage {
                compactInfoRow(icon: "exclamationmark.triangle", title: "利用できません", value: "設定未完了", color: AppColors.warning)
                Divider()
                Text(unavailableMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            } else {
                Button {
                    isShowingAuthSheet = true
                } label: {
                    settingsRow(icon: "person.circle", title: "サインイン / アカウント作成", value: "")
                }
                .buttonStyle(.plain)
            }
            if let error = viewModel.app.syncStatus.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(AppColors.danger)
                    .padding(.top, 6)
            }
        }
    }

    private var dangerCard: some View {
        settingsGroup(title: "危険な操作") {
            actionLine(icon: "trash", title: "全データを削除", color: AppColors.danger) {
                isShowingDeleteConfirmation = true
            }
        }
    }

    private var backupCard: some View {
        settingsGroup(title: "バックアップ") {
            actionLine(icon: "square.and.arrow.down", title: "エクスポート", color: AppColors.success) {
                isShowingExportOptions = true
            }
            Divider()
            actionLine(icon: "square.and.arrow.up", title: "インポート", color: AppColors.success) {
                isImporting = true
            }
            if let url = viewModel.exportURL {
                Divider()
                ShareLink(item: url) {
                    settingsRow(icon: "doc.badge.arrow.up", title: "直近のファイルを共有", value: "", titleColor: AppColors.success)
                }
            }
        }
    }

    private var debugLogCard: some View {
        settingsGroup(title: "診断ログ") {
            actionLine(icon: "doc.on.doc", title: "診断ログをコピー", color: AppColors.success) {
                viewModel.copyDebugLogs()
                copyConfirmationMessage = "診断ログをコピーしました"
            }
            Divider()
            actionLine(icon: "square.and.arrow.up", title: "診断ログを共有", color: AppColors.success) {
                viewModel.exportDebugLogs()
            }
            Divider()
            actionLine(icon: "folder", title: "診断ログを開く", color: AppColors.success) {
                viewModel.refreshDebugLogs()
                isShowingDebugLogs = true
            }
            Divider()
            actionLine(icon: "trash", title: "診断ログをクリア", color: AppColors.danger) {
                viewModel.clearDebugLogs()
            }
        }
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
        } catch {
            viewModel.app.present(error)
        }
    }

    private func updateScheduleSlot(id: String, update: (inout FocusScheduleSlot) -> Void) {
        applyFocusSettings { settings in
            guard let index = settings.scheduleSlots.firstIndex(where: { $0.id == id }) else { return }
            update(&settings.scheduleSlots[index])
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

    private func settingsGroup<Content: View, Footer: View>(title: String, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            settingsGroup(title: title, content: content)
            footer()
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 18)
        }
    }

    private func settingsRow(icon: String, title: String, value: String, color: Color = AppColors.success, titleColor: Color = AppColors.textPrimary) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            Spacer()
            if title == "カラー" {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            if !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            Image(systemName: "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(minHeight: 46)
        .contentShape(Rectangle())
    }

    private func compactInfoRow(icon: String, title: String, value: String, color: Color = AppColors.textSecondary, showsStatusDot: Bool = false) -> some View {
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

    private func settingsTitle(for preset: LandscapeTimerDisplayPreset) -> String {
        switch preset {
        case .problemProgress:
            return "問題集つき（推奨）"
        case .clockOnly:
            return "時計のみ"
        }
    }

    private func timerVisualIcon(for mode: TimerVisualMode) -> String {
        switch mode {
        case .auto:
            return "location.fill"
        case .morning:
            return "sunrise.fill"
        case .day:
            return "sun.max.fill"
        case .night:
            return "moon.stars.fill"
        }
    }

    private func settingsTitle(for preset: LiveActivityDisplayPreset) -> String {
        switch preset {
        case .standard:
            return "シンプル"
        case .focus:
            return "集中"
        case .progress:
            return "進捗"
        case .subjectDetail:
            return "科目詳細"
        }
    }

    private var totalStudyTimeText: String {
        let hours = viewModel.summary.totalStudyMinutes / 60
        let minutes = viewModel.summary.totalStudyMinutes % 60
        return "\(formattedCount(hours)) 時間 \(minutes) 分"
    }

    private func formattedCount(_ value: Int) -> String {
        Self.integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    private func reminderDate(hour: Int, minute: Int) -> Date {
        let now = Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private func scheduleDate(hour: Int, minute: Int) -> Date {
        let now = Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    private var appVersionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private var liveActivitySettingsAvailable: Bool {
        if #available(iOS 16.2, *) {
            return true
        }
        return false
    }

    private var liveActivityFeatureIncludedInBuild: Bool {
        #if LIVE_ACTIVITY_DISABLED
        return false
        #else
        return true
        #endif
    }

    private var liveActivityBuildLabel: String {
        liveActivityFeatureIncludedInBuild ? "Live Activity ON" : "Live Activity OFF"
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
