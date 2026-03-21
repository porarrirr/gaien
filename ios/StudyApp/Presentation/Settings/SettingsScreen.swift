import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var isImporting = false
    @State private var isShowingExportOptions = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingAuthSheet = false

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
            } header: {
                Label("アプリ情報", systemImage: "info.circle.fill")
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $isShowingAuthSheet) {
            NavigationStack {
                AuthSheet(viewModel: viewModel, isPresented: $isShowingAuthSheet)
            }
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
