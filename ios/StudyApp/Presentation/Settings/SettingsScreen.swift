import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

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
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    viewModel.importBackup(from: url)
                }
            }
            .task(id: viewModel.app.dataVersion) {
                await viewModel.load()
            }
    }

    private var settingsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appearanceGroup
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

    private var landscapeTimerGroup: some View {
        settingsGroup(title: "タイマー横向き表示") {
            ForEach(Array(LandscapeTimerDisplayPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                Button {
                    viewModel.app.setLandscapeTimerDisplayPreset(preset)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: preset == .problemProgress ? "iphone.landscape" : "arrow.triangle.2.circlepath")
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
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                if index < LandscapeTimerDisplayPreset.allCases.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var dashboardCards: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .top, spacing: 16) {
            dataSummaryCard
            cloudSyncCard
            dangerCard
            backupCard
        }
    }

    private var liveActivityGroup: some View {
        settingsGroup(title: "Live Activity") {
            if liveActivityFeatureIncludedInBuild, liveActivitySettingsAvailable {
                Toggle(isOn: Binding(get: { viewModel.app.preferences.liveActivityEnabled }, set: { viewModel.app.setLiveActivityEnabled($0) })) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "waveform")
                        Text("タイプアクティビティを使用")
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
                Text(liveActivityFeatureIncludedInBuild ? "iOS 18以降で利用できます" : "このビルドでは Live Activity を含めていません")
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
        .frame(minHeight: 164, alignment: .top)
    }

    private var cloudSyncCard: some View {
        settingsGroup(title: "クラウド同期") {
            if viewModel.app.syncStatus.isAuthenticated {
                compactInfoRow(icon: "cloud", title: "接続中", value: "接続中", color: AppColors.success, showsStatusDot: true)
                Divider()
                compactInfoRow(icon: "person", title: "メールアドレス", value: viewModel.app.syncStatus.email ?? "-")
                Divider()
                compactInfoRow(icon: "clock", title: "最終同期", value: viewModel.app.syncStatus.lastSyncAt.map { Self.syncDateFormatter.string(from: Date(epochMilliseconds: $0)) } ?? "未同期")
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
        .frame(minHeight: 126, alignment: .top)
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
        .frame(minHeight: 126, alignment: .top)
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
                    .minimumScaleFactor(0.75)
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
                .minimumScaleFactor(0.65)
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
            return "タイマー固定（推奨）"
        case .clockOnly:
            return "自動回転（全画面対応）"
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

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

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

private struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 28, height: 28)
    }
}

private struct DebugLogSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let isClearUnlocked: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var copyConfirmationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DebugLogSummaryCard(
                    count: displayedEntries.count,
                    lastUpdatedText: lastUpdatedText
                )

                debugLogList

                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(height: 1)
                    .padding(.top, 2)

                HStack(spacing: 9) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("ロックを解除すると操作できます")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)

                VStack(spacing: 6) {
                    DebugLogActionRow(title: "診断ログをコピー", systemImage: "doc.text", color: AppColors.success) {
                        copyLogs()
                    }
                    DebugLogActionRow(title: "診断ログを共有", systemImage: "square.and.arrow.up", color: AppColors.success) {
                        viewModel.exportDebugLogs()
                    }
                    DebugLogActionRow(title: "診断ログをクリア", systemImage: "trash", color: AppColors.danger) {
                        viewModel.clearDebugLogs()
                    }
                    .disabled(!isClearUnlocked)
                    .opacity(isClearUnlocked ? 1 : 0.72)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .strictScreen()
        .navigationTitle("デバッグログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.refreshDebugLogs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button {
                    copyLogs()
                } label: {
                    Image(systemName: "doc.text")
                }
                Button {
                    viewModel.exportDebugLogs()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .tint(AppColors.success)
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

    @ViewBuilder
    private var debugLogList: some View {
        if displayedEntries.isEmpty {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("ログはまだありません")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("アプリの動作記録と診断情報がここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { index, entry in
                    DebugLogRow(entry: entry, categoryColor: color(for: entry))
                    if index < displayedEntries.count - 1 {
                        Divider()
                            .padding(.leading, 214)
                    }
                }
            }
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    private var lastUpdatedText: String {
        guard let latest = displayedEntries.first?.timestamp else {
            return "--:--:--"
        }
        return Self.timeFormatter.string(from: latest)
    }

    private var displayedEntries: [DebugLogEntry] {
        Array(viewModel.debugLogEntries.prefix(200))
    }

    private func copyLogs() {
        viewModel.copyDebugLogs()
        copyConfirmationMessage = "デバッグログをコピーしました"
    }

    private func color(for entry: DebugLogEntry) -> Color {
        switch entry.level {
        case .warning:
            return AppColors.warning
        case .error:
            return AppColors.danger
        case .debug, .info:
            switch entry.category {
            case .sync:
                return AppColors.success
            case .barcode:
                return AppColors.blue
            case .app, .auth, .ui:
                return AppColors.blue
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct DebugLogSummaryCard: View {
    let count: Int
    let lastUpdatedText: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 62, height: 62)
                Image(systemName: "doc.text")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("デバッグログ")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("アプリの動作記録と診断情報を表示します。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("最新 200 件を表示しています。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 16) {
                Text("最終更新: \(lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(count)件")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 26)
        .frame(minHeight: 112)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct DebugLogRow: View {
    let entry: DebugLogEntry
    let categoryColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Self.timestampFormatter.string(from: entry.timestamp))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(dayLabel)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(width: 170, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 12) {
                    Text(entry.category.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(categoryColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(entry.message)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(detailText)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 84)
        .contentShape(Rectangle())
    }

    private var detailText: String {
        if let details = entry.details, !details.isEmpty {
            return "詳細: \(details)"
        }
        if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
            return "詳細: \(errorDescription)"
        }
        return "詳細: -"
    }

    private var dayLabel: String {
        Calendar.current.isDateInToday(entry.timestamp) ? "今日" : Self.dayFormatter.string(from: entry.timestamp)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd  HH:mm:ss"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

private struct DebugLogActionRow: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Image(systemName: systemImage)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(height: 54)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AuthSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @State private var isSignInPasswordVisible = false
    @State private var isCreatePasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 22) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 66, weight: .regular))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 150, alignment: .center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("クラウド同期（オプション）")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Firebase を使用してデータを安全に同期します。\n同期はいつでも設定からオン／オフできます。")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("サインイン")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                        Text("既存のアカウントでサインインしてデータを同期します。")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AuthInputField(
                        title: "メールアドレス",
                        placeholder: "メールアドレスを入力",
                        text: $viewModel.syncEmail,
                        keyboardType: .emailAddress
                    )
                    AuthPasswordField(
                        title: "パスワード",
                        placeholder: "パスワードを入力",
                        text: $viewModel.syncPassword,
                        isVisible: $isSignInPasswordVisible
                    )
                    Text("パスワードをお忘れですか？")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.success)

                    Button {
                        viewModel.signInToSync()
                    } label: {
                        Text("サインイン")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppColors.success, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                }
                .authCard()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("アカウント作成")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                        Text("新しいアカウントを作成してクラウド同期を利用します。")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AuthInputField(
                        title: "メールアドレス",
                        placeholder: "メールアドレスを入力",
                        text: $viewModel.syncEmail,
                        keyboardType: .emailAddress
                    )
                    AuthPasswordField(
                        title: "パスワード",
                        placeholder: "パスワードを入力",
                        text: $viewModel.syncPassword,
                        isVisible: $isCreatePasswordVisible
                    )
                    Text("※ 8文字以上のパスワードを設定してください。")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)

                    Button {
                        viewModel.createSyncAccount()
                    } label: {
                        Text("アカウント作成")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppColors.success, lineWidth: 1.5)
                            }
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                }
                .authCard()

                if let error = viewModel.app.syncStatus.errorMessage {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.red)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("同期エラー")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.red)
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("通信は暗号化され、安全に保護されています。")
                        .font(.system(size: 14))
                }
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("クラウド同期")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { isPresented = false }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
        }
    }
}

private struct AuthInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            TextField(placeholder, text: $text)
                .font(.system(size: 18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                }
        }
    }
}

private struct AuthPasswordField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .frame(height: 54)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            }
        }
    }
}

private extension View {
    func authCard() -> some View {
        self
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}
