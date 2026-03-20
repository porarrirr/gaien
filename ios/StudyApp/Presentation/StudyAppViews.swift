import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var app = StudyAppContainer()

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.clearError() } }
        )
    }

    var body: some View {
        Group {
            if !app.isLoaded {
                ProgressView("読み込み中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if !app.preferences.onboardingCompleted {
                OnboardingScreen(app: app)
            } else {
                MainTabView(app: app)
            }
        }
        .preferredColorScheme(app.preferences.selectedThemeMode.colorScheme)
        .tint(app.preferences.selectedColorTheme.primaryColor)
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                app.clearError()
            }
        } message: {
            Text(app.errorMessage ?? "")
        }
    }
}

private struct MainTabView: View {
    let app: StudyAppContainer

    var body: some View {
        TabView {
            NavigationStack {
                HomeScreen(app: app)
            }
            .tabItem {
                Label("ホーム", systemImage: "house.fill")
            }

            NavigationStack {
                TimerScreen(app: app)
            }
            .tabItem {
                Label("タイマー", systemImage: "timer")
            }

            NavigationStack {
                MaterialsScreen(app: app)
            }
            .tabItem {
                Label("教材", systemImage: "book.closed.fill")
            }

            NavigationStack {
                CalendarScreen(app: app)
            }
            .tabItem {
                Label("カレンダー", systemImage: "calendar")
            }

            NavigationStack {
                ReportsScreen(app: app)
            }
            .tabItem {
                Label("レポート", systemImage: "chart.bar.fill")
            }
        }
    }
}

private struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel
    @State private var selection = 0

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "学習時間を記録", description: "タイマーと手動入力で学習履歴を残せます。", systemImage: "timer"),
        OnboardingPage(title: "教材を管理", description: "教材の進捗や関連する科目をまとめて管理できます。", systemImage: "books.vertical.fill"),
        OnboardingPage(title: "目標と計画", description: "日次・週次の目標と学習計画を Android と同じ考え方で扱います。", systemImage: "flag.fill")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 20) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 120, height: 120)
                            .background(viewModel.app.preferences.selectedColorTheme.primaryColor, in: Circle())
                        Text(page.title)
                            .font(.largeTitle.bold())
                        Text(page.description)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button(selection == pages.count - 1 ? "始める" : "スキップ") {
                viewModel.complete()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct HomeScreen: View {
    @StateObject private var viewModel: HomeViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(app: app))
    }

    var body: some View {
        List {
            Section("今日の学習") {
                Text("\(viewModel.homeData.todayStudyMinutes)分")
                    .font(.largeTitle.bold())
                if viewModel.homeData.todaySessions.isEmpty {
                    Text("まだ記録がありません").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.homeData.todaySessions) { session in
                        VStack(alignment: .leading) {
                            Text(session.subjectName).font(.headline)
                            Text("\(Int(session.duration / 60_000))分 ・ \(session.materialName)").foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("週間目標") {
                if let goal = viewModel.homeData.weeklyGoal {
                    Text("\(Goal.format(minutes: viewModel.homeData.weeklyStudyMinutes)) / \(goal.targetFormatted)")
                    ProgressView(value: Double(viewModel.homeData.weeklyStudyMinutes), total: Double(max(goal.targetMinutes, 1)))
                } else {
                    Text("目標が未設定です").foregroundStyle(.secondary)
                }
            }

            Section("今後のテスト") {
                if viewModel.homeData.upcomingExams.isEmpty {
                    Text("予定されたテストはありません").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.homeData.upcomingExams.prefix(3)) { exam in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exam.name)
                                Text(exam.dateValue.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("あと\(max(exam.daysRemaining(), 0))日")
                        }
                    }
                }
            }

            Section("最近使った教材") {
                if viewModel.recentMaterials.isEmpty {
                    Text("まだ教材利用履歴がありません").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.recentMaterials.enumerated()), id: \.offset) { _, pair in
                        let material = pair.0
                        let subject = pair.1
                        HStack {
                            Circle().fill(Color(hex: subject.color)).frame(width: 10, height: 10)
                            VStack(alignment: .leading) {
                                Text(material.name)
                                Text(subject.name).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("移動") {
                NavigationLink("試験管理") { ExamsScreen(app: viewModel.app) }
                NavigationLink("科目管理") { SubjectsScreen(app: viewModel.app) }
                NavigationLink("履歴") { HistoryScreen(app: viewModel.app) }
                NavigationLink("目標") { GoalsScreen(app: viewModel.app) }
                NavigationLink("計画") { PlanScreen(app: viewModel.app) }
                NavigationLink("設定") { SettingsScreen(app: viewModel.app) }
            }
        }
        .navigationTitle("ホーム")
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }
}

private struct TimerScreen: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var isPresentingManualEntry = false
    @State private var manualMinutes = ""
    @State private var manualNote = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimerViewModel(app: app))
    }

    var body: some View {
        Form {
            Section("学習対象") {
                Picker("科目", selection: Binding(get: { viewModel.selectedSubjectId ?? 0 }, set: { viewModel.selectedSubjectId = $0 })) {
                    ForEach(viewModel.subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }

                Picker("教材", selection: Binding(get: { viewModel.selectedMaterialId ?? 0 }, set: { viewModel.selectedMaterialId = $0 == 0 ? nil : $0 })) {
                    Text("なし").tag(Int64(0))
                    ForEach(viewModel.materialsForSelectedSubject()) { material in
                        Text(material.name).tag(material.id)
                    }
                }
            }

            Section("タイマー") {
                Text(durationString(milliseconds: viewModel.elapsedMilliseconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)

                HStack {
                    Button(viewModel.isRunning ? "一時停止" : "開始") {
                        viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("停止", role: .destructive) {
                        viewModel.stop()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.elapsedMilliseconds == 0)
                }
            }

            Section("手動入力") {
                TextField("学習時間（分）", text: $manualMinutes)
                    .keyboardType(.numberPad)
                TextField("メモ", text: $manualNote, axis: .vertical)
                Button("保存") {
                    guard let subjectId = viewModel.selectedSubjectId else { return }
                    viewModel.saveManualSession(subjectId: subjectId, materialId: viewModel.selectedMaterialId, durationMinutes: Int(manualMinutes) ?? 0, note: manualNote)
                    manualMinutes = ""
                    manualNote = ""
                }
            }
        }
        .navigationTitle("タイマー")
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }
}

private struct MaterialsScreen: View {
    @StateObject private var viewModel: MaterialsViewModel
    @State private var draft = MaterialDraft()

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: MaterialsViewModel(app: app))
    }

    var body: some View {
        List {
            Section("教材を追加") {
                TextField("教材名", text: $draft.name)
                Picker("科目", selection: $draft.subjectId) {
                    ForEach(viewModel.subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }
                TextField("総ページ数", text: $draft.totalPages).keyboardType(.numberPad)
                TextField("メモ", text: $draft.note, axis: .vertical)
                Button("追加") {
                    viewModel.saveMaterial(name: draft.name, subjectId: draft.subjectId, totalPages: Int(draft.totalPages) ?? 0, note: draft.note)
                    draft = MaterialDraft(subjectId: viewModel.subjects.first?.id ?? 0)
                }
            }

            Section("ISBN検索") {
                TextField("ISBN", text: $draft.isbn)
                Button("検索") {
                    viewModel.searchBook(isbn: draft.isbn)
                }
                if let book = viewModel.bookSearchResult {
                    VStack(alignment: .leading) {
                        Text(book.title).font(.headline)
                        Text(book.authors.joined(separator: ", ")).foregroundStyle(.secondary)
                        Button("教材として追加") {
                            viewModel.saveMaterial(
                                name: book.title,
                                subjectId: draft.subjectId,
                                totalPages: book.pageCount ?? 0,
                                note: [book.publisher, book.publishedDate].compactMap { $0 }.joined(separator: " / ")
                            )
                            viewModel.clearSearchResult()
                        }
                    }
                }
            }

            Section("教材一覧") {
                ForEach(viewModel.materials) { material in
                    VStack(alignment: .leading) {
                        Text(material.name)
                        ProgressView(value: material.progress)
                        Text("\(material.currentPage)/\(material.totalPages)ページ").foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteMaterial(material)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("教材")
        .task(id: viewModel.app.dataVersion) {
            if draft.subjectId == 0 {
                draft.subjectId = viewModel.app.preferences.activeTimer?.subjectId ?? 0
            }
            await viewModel.load()
            if draft.subjectId == 0 {
                draft.subjectId = viewModel.subjects.first?.id ?? 0
            }
        }
    }
}

private struct CalendarScreen: View {
    @StateObject private var viewModel: CalendarViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(app: app))
    }

    var body: some View {
        List {
            DatePicker("表示月", selection: $viewModel.displayedMonth, displayedComponents: .date)
            Section("月間学習日") {
                ForEach(viewModel.monthStudyMap.keys.sorted(), id: \.self) { day in
                    HStack {
                        Text("\(day)日")
                        Spacer()
                        Text("\(viewModel.monthStudyMap[day] ?? 0)分")
                    }
                }
            }
        }
        .navigationTitle("カレンダー")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
        .onChange(of: viewModel.displayedMonth) { _ in
            Task { await viewModel.load() }
        }
    }
}

private struct ReportsScreen: View {
    @StateObject private var viewModel: ReportsViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(app: app))
    }

    var body: some View {
        List {
            Section("継続") {
                Text("現在の連続記録: \(viewModel.reports.streakDays)日")
                Text("最長記録: \(viewModel.reports.bestStreak)日")
            }

            Section("日別") {
                ForEach(viewModel.reports.daily) { item in
                    HStack {
                        Text(item.dateLabel)
                        Spacer()
                        Text("\(item.minutes)分")
                    }
                }
            }

            Section("週別") {
                ForEach(viewModel.reports.weekly) { item in
                    HStack {
                        Text(item.weekLabel)
                        Spacer()
                        Text("\(item.hours)時間\(item.minutes)分")
                    }
                }
            }

            Section("科目別") {
                ForEach(viewModel.reports.bySubject) { item in
                    HStack {
                        Circle().fill(Color(hex: item.color)).frame(width: 10, height: 10)
                        Text(item.subjectName)
                        Spacer()
                        Text("\(item.hours)時間\(item.minutes)分")
                    }
                }
            }
        }
        .navigationTitle("レポート")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct ExamsScreen: View {
    @StateObject private var viewModel: ExamsViewModel
    @State private var name = ""
    @State private var date = Date()
    @State private var note = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ExamsViewModel(app: app))
    }

    var body: some View {
        List {
            Section("テストを追加") {
                TextField("テスト名", text: $name)
                DatePicker("日付", selection: $date, displayedComponents: .date)
                TextField("メモ", text: $note, axis: .vertical)
                Button("保存") {
                    viewModel.saveExam(name: name, date: date, note: note)
                    name = ""
                    note = ""
                }
            }

            Section("一覧") {
                ForEach(viewModel.exams) { exam in
                    VStack(alignment: .leading) {
                        Text(exam.name)
                        Text(exam.dateValue.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteExam(exam)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("試験")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(app: app))
    }

    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                VStack(alignment: .leading) {
                    Text(session.subjectName).font(.headline)
                    Text("\(session.durationJapaneseText) ・ \(session.startDate.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.deleteSession(session)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct GoalsScreen: View {
    @StateObject private var viewModel: GoalsViewModel
    @State private var dailyMinutes = ""
    @State private var weeklyMinutes = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: GoalsViewModel(app: app))
    }

    var body: some View {
        Form {
            Section("1日の目標") {
                TextField("分", text: $dailyMinutes).keyboardType(.numberPad)
                Button("保存") {
                    viewModel.updateGoal(type: .daily, targetMinutes: Int(dailyMinutes) ?? 0)
                }
                if let goal = viewModel.dailyGoal {
                    Text("現在: \(goal.targetFormatted)")
                }
            }

            Section("週間目標") {
                TextField("分", text: $weeklyMinutes).keyboardType(.numberPad)
                Button("保存") {
                    viewModel.updateGoal(type: .weekly, targetMinutes: Int(weeklyMinutes) ?? 0)
                }
                if let goal = viewModel.weeklyGoal {
                    Text("現在: \(goal.targetFormatted)")
                }
            }
        }
        .navigationTitle("目標")
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            dailyMinutes = "\(viewModel.dailyGoal?.targetMinutes ?? 0)"
            weeklyMinutes = "\(viewModel.weeklyGoal?.targetMinutes ?? 0)"
        }
    }
}

private struct PlanScreen: View {
    @StateObject private var viewModel: PlanViewModel
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: PlanViewModel(app: app))
    }

    var body: some View {
        List {
            Section("計画を作成") {
                TextField("プラン名", text: $name)
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                Button("今ある科目で作成") {
                    let items = viewModel.subjects.map {
                        PlanItem(planId: 0, subjectId: $0.id, dayOfWeek: .monday, targetMinutes: 60, actualMinutes: 0, timeSlot: nil)
                    }
                    viewModel.createPlan(name: name, startDate: startDate, endDate: endDate, items: items)
                }
            }

            if let activePlan = viewModel.activePlan {
                Section("アクティブプラン") {
                    Text(activePlan.name).font(.headline)
                    Text("\(activePlan.startDateValue.formatted(date: .abbreviated, time: .omitted)) - \(activePlan.endDateValue.formatted(date: .abbreviated, time: .omitted))")
                    ForEach(viewModel.planItems) { item in
                        Text("\(item.dayOfWeek.japaneseTitle) / \(item.targetMinutes)分")
                    }
                    Button("削除", role: .destructive) {
                        viewModel.deleteActivePlan()
                    }
                }
            }
        }
        .navigationTitle("計画")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var isImporting = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app))
    }

    var body: some View {
        Form {
            Section("外観") {
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
                Stepper("\(viewModel.app.preferences.reminderHour):\(String(format: "%02d", viewModel.app.preferences.reminderMinute))", value: Binding(get: { viewModel.app.preferences.reminderHour }, set: { hour in
                    Task { await viewModel.app.setReminderTime(hour: hour, minute: viewModel.app.preferences.reminderMinute) }
                }), in: 0...23)
            }

            Section("バックアップ") {
                Button("JSONを書き出し") { viewModel.export(format: .json) }
                Button("CSVを書き出し") { viewModel.export(format: .csv) }
                Button("JSONを読み込む") { isImporting = true }
                if let url = viewModel.exportURL {
                    ShareLink(item: url) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section("危険な操作") {
                Button("全データ削除", role: .destructive) {
                    viewModel.deleteAllData()
                }
            }
        }
        .navigationTitle("設定")
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                viewModel.importBackup(from: url)
            }
        }
    }
}

private struct MaterialDraft {
    var name = ""
    var subjectId: Int64 = 0
    var totalPages = ""
    var note = ""
    var isbn = ""

    init(subjectId: Int64 = 0) {
        self.subjectId = subjectId
    }
}

private struct OnboardingPage {
    var title: String
    var description: String
    var systemImage: String
}

private func durationString(milliseconds: Int64) -> String {
    let totalSeconds = Int(milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}
