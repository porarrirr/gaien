import SwiftUI

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
                    viewModel.saveManualSession(
                        subjectId: subjectId,
                        materialId: viewModel.selectedMaterialId,
                        durationMinutes: Int(manualMinutes) ?? 0,
                        note: manualNote
                    )
                    manualMinutes = ""
                    manualNote = ""
                }
            }
        }
        .navigationTitle("タイマー")
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedSubjectId) { _ in
            if let materialId = viewModel.selectedMaterialId,
               !viewModel.materialsForSelectedSubject().contains(where: { $0.id == materialId }) {
                viewModel.selectedMaterialId = nil
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

private struct GoalsScreen: View {
    @StateObject private var viewModel: GoalsViewModel
    @State private var dailyMinutes = ""
    @State private var weeklyMinutes = ""
    @State private var hasLoadedInitialValues = false

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
            if !hasLoadedInitialValues {
                dailyMinutes = "\(viewModel.dailyGoal?.targetMinutes ?? 0)"
                weeklyMinutes = "\(viewModel.weeklyGoal?.targetMinutes ?? 0)"
                hasLoadedInitialValues = true
            }
        }
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
