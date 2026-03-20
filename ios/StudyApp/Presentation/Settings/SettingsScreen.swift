import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var isImporting = false
    @State private var isShowingExportOptions = false
    @State private var isShowingDeleteConfirmation = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app))
    }

    var body: some View {
        Form {
            Section("テーマ設定") {
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
            }

            Section("通知") {
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
            }

            Section("データ概要") {
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
            }

            Section("クラウド同期") {
                if viewModel.app.syncStatus.isAuthenticated {
                    HStack {
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
                    TextField("メールアドレス", text: $viewModel.syncEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("パスワード", text: $viewModel.syncPassword)
                    Button("サインイン") {
                        viewModel.signInToSync()
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                    Button("アカウント作成") {
                        viewModel.createSyncAccount()
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                }
                if let error = viewModel.app.syncStatus.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("バックアップ") {
                Button("エクスポート") {
                    isShowingExportOptions = true
                }
                Button("インポート") {
                    isImporting = true
                }
                if let url = viewModel.exportURL {
                    ShareLink(item: url) {
                        Label("直近のファイルを共有", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section("危険な操作") {
                Button("全データを削除", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("設定")
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
}
