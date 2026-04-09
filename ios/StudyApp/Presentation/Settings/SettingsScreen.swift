import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var isImporting = false
    @State private var isShowingExportOptions = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingAuthSheet = false
    @State private var isShowingDebugLogs = false
    @State private var versionTapCount = 0
    @State private var isDebugLogUnlocked = false
    @State private var copyConfirmationMessage: String?

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app))
    }

    var body: some View {
        Form {
            // Theme Settings
            Section {
                Picker("テーマ", selection: Binding(get: { viewModel.app.preferences.selectedThemeMode }, set: { viewModel.app.setThemeMode($0) })) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("カラー", selection: Binding(get: { viewModel.app.preferences.selectedColorTheme }, set: { viewModel.app.setColorTheme($0) })) {
                    ForEach(ColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            } header: {
                Label("テーマ設定", systemImage: "paintbrush.fill")
            }

            // Notifications
            Section {
                Toggle("毎日のリマインダー", isOn: Binding(get: { viewModel.app.preferences.reminderEnabled }, set: { enabled in
                    Task { await viewModel.app.setReminderEnabled(enabled) }
                }))
                DatePicker(
                    "通知時刻",
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
                )
                .disabled(!viewModel.app.preferences.reminderEnabled)
            } header: {
                Label("通知", systemImage: "bell.fill")
            }

            Section {
                if liveActivityFeatureIncludedInBuild, liveActivitySettingsAvailable {
                    Toggle(
                        "ライブアクティビティを使用",
                        isOn: Binding(
                            get: { viewModel.app.preferences.liveActivityEnabled },
                            set: { viewModel.app.setLiveActivityEnabled($0) }
                        )
                    )

                    Picker(
                        "表示プリセット",
                        selection: Binding(
                            get: { viewModel.app.preferences.liveActivityDisplayPreset },
                            set: { viewModel.app.setLiveActivityDisplayPreset($0) }
                        )
                    ) {
                        ForEach(LiveActivityDisplayPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .disabled(!viewModel.app.preferences.liveActivityEnabled)

                    ForEach(LiveActivityDisplayPreset.allCases) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(preset.title)
                                    .font(.subheadline.weight(.semibold))
                                if preset == viewModel.app.preferences.liveActivityDisplayPreset {
                                    Spacer()
                                    Text("選択中")
                                        .font(.caption.bold())
                                        .foregroundStyle(.tint)
                                }
                            }
                            Text(preset.settingsDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } else if liveActivityFeatureIncludedInBuild {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("iOS 18以降で利用できます")
                            .font(.subheadline.weight(.semibold))
                        Text("この端末ではライブアクティビティ設定を変更できません。タイマー機能はそのまま利用できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("このビルドでは Live Activity を含めていません")
                            .font(.subheadline.weight(.semibold))
                        Text("署名切り分け用の検証版です。通常版では Live Activity を利用できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Label("Live Activity", systemImage: "bolt.badge.clock")
            }

            // Data Summary
            Section {
                HStack {
                    Text("学習記録数")
                    Spacer()
                    Text("\(viewModel.summary.totalSessions)件")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("総学習時間")
                    Spacer()
                    Text("\(viewModel.summary.totalStudyMinutes / 60)時間\(viewModel.summary.totalStudyMinutes % 60)分")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("データ概要", systemImage: "chart.pie.fill")
            }

            // Cloud Sync
            Section {
                if viewModel.app.syncStatus.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.success)
                        Text("接続中")
                        Spacer()
                        Text(viewModel.app.syncStatus.email ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("最終同期")
                        Spacer()
                        Text(viewModel.app.syncStatus.lastSyncAt.map { Date(epochMilliseconds: $0).formatted(date: .abbreviated, time: .shortened) } ?? "未同期")
                            .foregroundStyle(.secondary)
                    }
                    Button(viewModel.app.syncStatus.isSyncing ? "同期中..." : "今すぐ同期") {
                        viewModel.syncNow()
                    }
                    .disabled(viewModel.app.syncStatus.isSyncing)
                    Button("ローカルデータをアップロード") {
                        viewModel.importLocalDataToCloud()
                    }
                    .disabled(viewModel.app.syncStatus.isSyncing)
                    Button("サインアウト", role: .destructive) {
                        viewModel.signOutOfSync()
                    }
                } else {
                    Button {
                        isShowingAuthSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.tint)
                            Text("サインイン / アカウント作成")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                if let error = viewModel.app.syncStatus.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Label("クラウド同期", systemImage: "icloud.fill")
            }

            // Backup
            Section {
                Button {
                    isShowingExportOptions = true
                } label: {
                    Label("エクスポート", systemImage: "square.and.arrow.up")
                }
                Button {
                    isImporting = true
                } label: {
                    Label("インポート", systemImage: "square.and.arrow.down")
                }
                if let url = viewModel.exportURL {
                    ShareLink(item: url) {
                        Label("直近のファイルを共有", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Label("バックアップ", systemImage: "externaldrive.fill")
            }

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.danger)
                        Text("全データを削除")
                            .foregroundStyle(AppColors.danger)
                    }
                }
            } header: {
                Label("危険な操作", systemImage: "exclamationmark.shield.fill")
                    .foregroundStyle(AppColors.danger)
            }

            // App Info
            Section {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(appVersionDescription)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    versionTapCount += 1
                    if versionTapCount >= 5 {
                        isDebugLogUnlocked = true
                    }
                }
                HStack {
                    Text("ビルド種別")
                    Spacer()
                    Text(liveActivityBuildLabel)
                        .foregroundStyle(liveActivityFeatureIncludedInBuild ? .green : .orange)
                }
            } header: {
                Label("アプリ情報", systemImage: "info.circle.fill")
            }

            if AppLogger.isDebugToolsEnabled && isDebugLogUnlocked {
                Section {
                    Button {
                        viewModel.refreshDebugLogs()
                        isShowingDebugLogs = true
                    } label: {
                        Label("デバッグログを開く", systemImage: "ladybug.fill")
                    }

                    Button {
                        viewModel.exportDebugLogs()
                    } label: {
                        Label("デバッグログを共有", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        viewModel.copyDebugLogs()
                        copyConfirmationMessage = "デバッグログをコピーしました"
                    } label: {
                        Label("デバッグログをコピー", systemImage: "doc.on.doc")
                    }

                    Button("デバッグログをクリア", role: .destructive) {
                        viewModel.clearDebugLogs()
                    }

                    HStack {
                        Text("保存件数")
                        Spacer()
                        Text("\(viewModel.debugLogEntries.count)件")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("デバッグログ", systemImage: "ladybug.fill")
                }
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $isShowingAuthSheet) {
            NavigationStack {
                AuthSheet(viewModel: viewModel, isPresented: $isShowingAuthSheet)
            }
        }
        .sheet(isPresented: $isShowingDebugLogs) {
            NavigationStack {
                DebugLogSheet(viewModel: viewModel)
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                viewModel.importBackup(from: url)
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private func reminderDate(hour: Int, minute: Int) -> Date {
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
        if #available(iOS 18.0, *) {
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

private struct DebugLogSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copyConfirmationMessage: String?

    var body: some View {
        List {
            if viewModel.debugLogEntries.isEmpty {
                Text("ログはまだありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.debugLogEntries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.level.rawValue.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(color(for: entry.level))
                        }
                        Text(entry.message)
                            .font(.headline)
                        Text(entry.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let details = entry.details, !details.isEmpty {
                            Text(details)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
                            Text(errorDescription)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("デバッグログ")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("共有") {
                    viewModel.exportDebugLogs()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("コピー") {
                    viewModel.copyDebugLogs()
                    copyConfirmationMessage = "デバッグログをコピーしました"
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("更新") {
                    viewModel.refreshDebugLogs()
                }
            }
        }
        .alert("デバッグログ", isPresented: Binding(get: { copyConfirmationMessage != nil }, set: { if !$0 { copyConfirmationMessage = nil } })) {
            Button("OK", role: .cancel) {
                copyConfirmationMessage = nil
            }
        } message: {
            Text(copyConfirmationMessage ?? "")
        }
        .onAppear {
            viewModel.refreshDebugLogs()
        }
    }

    private func color(for level: DebugLogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct AuthSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section {
                TextField("メールアドレス", text: $viewModel.syncEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("パスワード", text: $viewModel.syncPassword)
            }

            Section {
                Button {
                    viewModel.signInToSync()
                    isPresented = false
                } label: {
                    HStack {
                        Spacer()
                        Text("サインイン")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)

                Button {
                    viewModel.createSyncAccount()
                    isPresented = false
                } label: {
                    HStack {
                        Spacer()
                        Text("アカウント作成")
                        Spacer()
                    }
                }
                .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
            }
        }
        .navigationTitle("クラウド同期")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { isPresented = false }
            }
        }
    }
}
