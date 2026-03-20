import SwiftUI
import UniformTypeIdentifiers
import UIKit
#if canImport(Charts)
import Charts
#endif
#if canImport(VisionKit)
import VisionKit
#endif

struct RootView: View {
    @StateObject private var store = StudyAppStore()

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )
    }

    var body: some View {
        Group {
            if !store.isLoaded {
                ProgressView("読み込み中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if store.onboardingCompleted {
                MainTabView()
                    .environmentObject(store)
            } else {
                OnboardingScreen()
                    .environmentObject(store)
            }
        }
        .preferredColorScheme(store.selectedThemeMode.colorScheme)
        .tint(store.selectedColorTheme.primaryColor)
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeScreen()
            }
            .tabItem {
                Label("ホーム", systemImage: "house.fill")
            }

            NavigationStack {
                TimerScreen()
            }
            .tabItem {
                Label("タイマー", systemImage: "timer")
            }

            NavigationStack {
                MaterialsScreen()
            }
            .tabItem {
                Label("教材", systemImage: "book.closed.fill")
            }

            NavigationStack {
                CalendarScreen()
            }
            .tabItem {
                Label("カレンダー", systemImage: "calendar")
            }

            NavigationStack {
                ReportsScreen()
            }
            .tabItem {
                Label("レポート", systemImage: "chart.bar.fill")
            }
        }
    }
}

private struct OnboardingScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var selection = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "学習時間を記録",
            description: "タイマーを使って学習時間を簡単に記録できます。\n手動入力にも対応しています。",
            systemImage: "alarm.fill",
            color: Color(hex: 0x4CAF50)
        ),
        OnboardingPage(
            title: "教材を管理",
            description: "参考書や問題集を登録して、\n学習進捗を可視化しましょう。",
            systemImage: "doc.text.fill",
            color: Color(hex: 0x2196F3)
        ),
        OnboardingPage(
            title: "目標を設定",
            description: "1日の目標や週間目標を設定して、\nモチベーションを維持しましょう。",
            systemImage: "star.fill",
            color: Color(hex: 0xFF9800)
        ),
        OnboardingPage(
            title: "学習を分析",
            description: "グラフで学習時間を可視化し、\n自分の学習傾向を把握しましょう。",
            systemImage: "chart.xyaxis.line",
            color: Color(hex: 0x9C27B0)
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [store.selectedColorTheme.primaryColor.opacity(0.25), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Image(systemName: page.systemImage)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 120, height: 120)
                                .background(page.color, in: Circle())

                            Text(page.title)
                                .font(.largeTitle.bold())

                            Text(page.description)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == selection ? AnyShapeStyle(store.selectedColorTheme.primaryColor) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                            .frame(width: index == selection ? 12 : 8, height: index == selection ? 12 : 8)
                    }
                }

                if selection < pages.count - 1 {
                    HStack(spacing: 12) {
                        Button("スキップ") {
                            store.completeOnboarding()
                        }
                        .buttonStyle(.bordered)

                        Button("次へ") {
                            withAnimation {
                                selection = min(selection + 1, pages.count - 1)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button {
                        store.completeOnboarding()
                    } label: {
                        Label("始める", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 40)
        }
    }
}

private struct HomeScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var sheet: HomeSheet?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StudySectionCard(title: "今日の学習", systemImage: "clock.fill") {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(store.todayStudyMinutes())")
                                .font(.system(size: 42, weight: .bold))
                            Text("分")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.recentSessions(), id: \.id) { session in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.subjectName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(session.durationJapaneseText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if store.recentSessions().isEmpty {
                                Text("まだ記録がありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                StudySectionCard(title: "週間目標", systemImage: "flag.fill") {
                    if let weeklyGoal = store.activeWeeklyGoal {
                        let weeklyMinutes = store.weeklyStudyMinutes()
                        let progress = min(Double(weeklyMinutes) / Double(max(weeklyGoal.targetMinutes, 1)), 1)
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(store.selectedColorTheme.primaryColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(progress * 100))%")
                                    .font(.headline)
                            }
                            .frame(width: 88, height: 88)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(Goal.format(minutes: weeklyMinutes)) / \(weeklyGoal.targetFormatted)")
                                    .font(.headline)
                                Text(progress >= 1 ? "目標達成！" : "あと\(Goal.format(minutes: max(weeklyGoal.targetMinutes - weeklyMinutes, 0)))")
                                    .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)
                            }
                        }
                    } else {
                        Text("目標が未設定です")
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.upcomingExams(limit: 3).isEmpty {
                    StudySectionCard(title: "今後のテスト", systemImage: "calendar.badge.clock") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.upcomingExams(limit: 3), id: \.id) { exam in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exam.name)
                                            .font(.headline)
                                        Text(exam.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    let remaining = exam.daysRemaining()
                                    Text(remaining == 0 ? "今日" : "あと\(remaining)日")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(remaining <= 7 ? Color.red : store.selectedColorTheme.primaryColor)
                                }
                            }
                        }
                    }
                }

                StudySectionCard(title: "クイックアクション", systemImage: "sparkles") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        QuickActionButton(title: "タイマーで学習開始", systemImage: "timer") {
                            sheet = .timerTip
                        }
                        QuickActionButton(title: "教材を追加", systemImage: "plus.rectangle.on.folder") {
                            sheet = .materials
                        }
                        QuickActionButton(title: "目標を確認", systemImage: "flag") {
                            sheet = .goals
                        }
                        QuickActionButton(title: "テストを管理", systemImage: "calendar") {
                            sheet = .exams
                        }
                        QuickActionButton(title: "学習計画を確認", systemImage: "list.bullet.rectangle.portrait") {
                            sheet = .plan
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("ホーム")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    sheet = .history
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }

                Button {
                    sheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .history:
                    HistoryScreen()
                case .settings:
                    SettingsScreen()
                case .goals:
                    GoalsScreen()
                case .exams:
                    ExamsScreen()
                case .plan:
                    PlanScreen()
                case .materials:
                    MaterialsScreen()
                case .timerTip:
                    TimerTipSheet()
                }
            }
            .environmentObject(store)
        }
    }
}

private struct TimerScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var selectedSubjectId: Int64?
    @State private var selectedMaterialId: Int64?
    @State private var isPresentingManualEntry = false

    private var isRunning: Bool {
        store.snapshot.activeTimer?.isRunning ?? false
    }

    var body: some View {
        Form {
            Section("学習対象") {
                Picker("科目", selection: Binding(
                    get: { selectedSubjectId ?? store.snapshot.activeTimer?.subjectId ?? store.subjects.first?.id ?? 0 },
                    set: { value in
                        selectedSubjectId = value
                        if let firstMaterial = store.materials(for: value).first {
                            selectedMaterialId = firstMaterial.id
                        } else {
                            selectedMaterialId = nil
                        }
                    }
                )) {
                    ForEach(store.subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }

                Picker("教材", selection: Binding(
                    get: {
                        selectedMaterialId ?? store.snapshot.activeTimer?.materialId ?? 0
                    },
                    set: { selectedMaterialId = $0 == 0 ? nil : $0 }
                )) {
                    Text("なし").tag(Int64(0))
                    ForEach(store.materials(for: selectedSubjectId ?? store.snapshot.activeTimer?.subjectId ?? -1)) { material in
                        Text(material.name).tag(material.id)
                    }
                }
            }

            Section("タイマー") {
                VStack(spacing: 16) {
                    Text(durationString(store.elapsedTime))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)

                    if isRunning {
                        Text("学習中")
                            .foregroundStyle(store.selectedColorTheme.primaryColor)
                    }

                    HStack(spacing: 16) {
                        if !isRunning {
                            Button {
                                if let subjectId = selectedSubjectId ?? store.snapshot.activeTimer?.subjectId ?? store.subjects.first?.id {
                                    store.startTimer(
                                        subjectId: subjectId,
                                        materialId: selectedMaterialId ?? store.snapshot.activeTimer?.materialId
                                    )
                                }
                            } label: {
                                Label(store.elapsedTime > 0 ? "再開" : "開始", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button {
                                store.pauseTimer()
                            } label: {
                                Label("一時停止", systemImage: "pause.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if store.elapsedTime > 0 {
                            Button(role: .destructive) {
                                store.stopTimer()
                            } label: {
                                Label("停止", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if !store.recentMaterials().isEmpty {
                Section("最近使用した教材") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.recentMaterials(), id: \.0.id) { material, subject in
                                Button {
                                    selectedSubjectId = subject.id
                                    selectedMaterialId = material.id
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: subject.color))
                                            .frame(width: 10, height: 10)
                                        Text(material.name)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("タイマー")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingManualEntry = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $isPresentingManualEntry) {
            ManualEntrySheet(
                subjects: store.subjects,
                materials: store.materials,
                onSave: { subjectId, materialId, minutes, note in
                    store.saveManualSession(subjectId: subjectId, materialId: materialId, durationMinutes: minutes, note: note)
                }
            )
        }
        .onAppear {
            if selectedSubjectId == nil {
                selectedSubjectId = store.snapshot.activeTimer?.subjectId ?? store.subjects.first?.id
            }
            if selectedMaterialId == nil {
                selectedMaterialId = store.snapshot.activeTimer?.materialId
            }
        }
    }
}

private struct MaterialsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var draft = MaterialDraft()
    @State private var isPresentingEditor = false
    @State private var editingMaterial: Material?
    @State private var progressTarget: Material?
    @State private var deleteTarget: Material?
    @State private var isPresentingSubjects = false
    @State private var isPresentingIsbnLookup = false

    var body: some View {
        List {
            if store.materials.isEmpty {
                EmptyStateView(
                    systemImage: "book.closed",
                    title: "教材が登録されていません",
                    message: "＋ボタンで追加してください"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.materials) { material in
                    MaterialRow(material: material)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            progressTarget = material
                        }
                        .swipeActions(edge: .trailing) {
                            Button("削除", role: .destructive) {
                                deleteTarget = material
                            }
                            Button("編集") {
                                editingMaterial = material
                                draft = MaterialDraft(material: material)
                                isPresentingEditor = true
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("教材")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingIsbnLookup = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }

                Button("科目") {
                    isPresentingSubjects = true
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    draft = MaterialDraft()
                    editingMaterial = nil
                    isPresentingEditor = true
                } label: {
                    Label("教材を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                MaterialEditorSheet(
                    draft: $draft,
                    subjects: store.subjects,
                    isEditing: editingMaterial != nil
                ) {
                    if let material = editingMaterial {
                        store.updateMaterial(draft.makeMaterial(id: material.id, currentPage: material.currentPage))
                    } else {
                        let material = draft.makeMaterial()
                        store.addMaterial(
                            name: material.name,
                            subjectId: material.subjectId,
                            totalPages: material.totalPages,
                            color: material.color,
                            note: material.note
                        )
                    }
                    isPresentingEditor = false
                }
            }
        }
        .sheet(isPresented: $isPresentingSubjects) {
            NavigationStack {
                SubjectsScreen()
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $isPresentingIsbnLookup) {
            NavigationStack {
                ISBNLookupSheet()
            }
            .environmentObject(store)
        }
        .sheet(item: $progressTarget) { material in
            ProgressEditSheet(material: material) { newPage in
                store.updateMaterialProgress(materialId: material.id, page: newPage)
            }
        }
        .alert("教材を削除", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { material in
            Button("削除", role: .destructive) {
                store.deleteMaterial(material)
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { material in
            Text("「\(material.name)」を削除しますか？")
        }
    }
}

private struct CalendarScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?

    private var calendar: Calendar { .current }

    private var monthMap: [Int: Int] {
        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)
        return store.monthlyStudyMap(year: year, month: month)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month())
    }

    private var days: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let numberOfDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        let placeholders = Array(repeating: CalendarDay.placeholder, count: max(firstWeekday - 1, 0))
        let dates = (1...numberOfDays).compactMap { day -> CalendarDay? in
            var components = calendar.dateComponents([.year, .month], from: displayedMonth)
            components.day = day
            guard let date = calendar.date(from: components) else { return nil }
            return CalendarDay(date: date, day: day)
        }
        return placeholders + dates
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StudySectionCard(title: "カレンダー", systemImage: "calendar") {
                    HStack {
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                            selectedDate = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 30, height: 30)
                        }
                        Spacer()
                        Text(monthTitle)
                            .font(.headline)
                        Spacer()
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                            selectedDate = nil
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 30, height: 30)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(days) { day in
                            if let date = day.date {
                                let minutes = monthMap[day.day] ?? 0
                                Button {
                                    selectedDate = date
                                } label: {
                                    Text("\(day.day)")
                                        .fontWeight(selectedDate.map { calendar.isDate($0, inSameDayAs: date) } == true || calendar.isDateInToday(date) ? .bold : .regular)
                                        .frame(maxWidth: .infinity, minHeight: 38)
                                        .background(backgroundColor(for: minutes, date: date), in: Circle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 38)
                            }
                        }
                    }
                }

                if let selectedDate {
                    StudySectionCard(title: selectedDate.formatted(.dateTime.month().day().weekday(.abbreviated)), systemImage: "clock") {
                        let minutes = store.sessions(on: selectedDate).reduce(0) { $0 + $1.durationMinutes }
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(minutes)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(store.selectedColorTheme.primaryColor)
                            Text("分")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("カレンダー")
    }

    private func backgroundColor(for minutes: Int, date: Date) -> Color {
        if selectedDate.map({ calendar.isDate($0, inSameDayAs: date) }) == true || calendar.isDateInToday(date) {
            return store.selectedColorTheme.primaryColor.opacity(0.9)
        }
        if minutes > 180 { return store.selectedColorTheme.primaryColor.opacity(0.45) }
        if minutes > 60 { return store.selectedColorTheme.primaryColor.opacity(0.3) }
        if minutes > 0 { return store.selectedColorTheme.primaryColor.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }
}

private struct ReportsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var tab: ReportsTab = .overview

    private var totalMinutes: Int {
        store.sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var averageMinutes: Int {
        let daily = store.reportDailyData()
        guard !daily.isEmpty else { return 0 }
        return daily.reduce(0) { $0 + $1.minutes } / daily.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("レポート", selection: $tab) {
                    ForEach(ReportsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .overview:
                    ReportsOverview(totalMinutes: totalMinutes, averageMinutes: averageMinutes)
                case .daily:
                    DailyReportView(data: store.reportDailyData())
                case .weekly:
                    WeeklyReportView(data: store.reportWeeklyData())
                case .monthly:
                    MonthlyReportView(data: store.reportMonthlyData())
                case .subject:
                    SubjectReportView(data: store.subjectBreakdown())
                }
            }
            .padding()
        }
        .navigationTitle("レポート")
    }

    @ViewBuilder
    private func ReportsOverview(totalMinutes: Int, averageMinutes: Int) -> some View {
        StudySectionCard(title: "概要", systemImage: "chart.bar.doc.horizontal") {
            VStack(spacing: 12) {
                HStack {
                    MetricBadge(title: "総学習時間", value: Goal.format(minutes: totalMinutes))
                    MetricBadge(title: "平均", value: Goal.format(minutes: averageMinutes))
                }
                HStack {
                    MetricBadge(title: "連続日数", value: "\(store.streakDays())日")
                    MetricBadge(title: "最長連続", value: "\(store.bestStreak())日")
                }
            }
        }

        DailyReportView(data: store.reportDailyData())

        if !store.subjectBreakdown().isEmpty {
            SubjectReportView(data: store.subjectBreakdown())
        }
    }
}

private struct ExamsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var draft = ExamDraft()
    @State private var isPresentingEditor = false
    @State private var editingExam: Exam?
    @State private var deleteTarget: Exam?

    var body: some View {
        List {
            if store.exams.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "テスト予定がありません",
                    message: "＋ボタンで追加してください"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.exams) { exam in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exam.name)
                                    .font(.headline)
                                Text(exam.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(statusText(for: exam))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(statusColor(for: exam))
                        }

                        if let note = exam.note, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingExam = exam
                        draft = ExamDraft(exam: exam)
                        isPresentingEditor = true
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            deleteTarget = exam
                        }
                        Button("編集") {
                            editingExam = exam
                            draft = ExamDraft(exam: exam)
                            isPresentingEditor = true
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("テスト管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingExam = nil
                    draft = ExamDraft()
                    isPresentingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                ExamEditorSheet(draft: $draft, isEditing: editingExam != nil) {
                    if let editingExam {
                        store.updateExam(draft.makeExam(id: editingExam.id))
                    } else {
                        store.addExam(name: draft.name, date: draft.date, note: draft.note)
                    }
                    isPresentingEditor = false
                }
            }
        }
        .alert("テストを削除", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { exam in
            Button("削除", role: .destructive) {
                store.deleteExam(exam)
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { exam in
            Text("「\(exam.name)」を削除しますか？")
        }
    }

    private func statusText(for exam: Exam) -> String {
        let remaining = exam.daysRemaining()
        if remaining < 0 { return "終了" }
        if remaining == 0 { return "今日" }
        return "あと \(remaining)日"
    }

    private func statusColor(for exam: Exam) -> Color {
        let remaining = exam.daysRemaining()
        if remaining <= 0 { return .red }
        if remaining <= 7 { return .red }
        if remaining <= 14 { return .orange }
        return store.selectedColorTheme.primaryColor
    }
}

private struct GoalsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var editingGoalType: GoalType?
    @State private var minutes = 60

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GoalCard(
                    title: "1日の目標",
                    currentMinutes: store.todayStudyMinutes(),
                    goal: store.activeDailyGoal,
                    onEdit: {
                        minutes = store.activeDailyGoal?.targetMinutes ?? 60
                        editingGoalType = .daily
                    }
                )

                GoalCard(
                    title: "週間目標",
                    currentMinutes: store.weeklyStudyMinutes(),
                    goal: store.activeWeeklyGoal,
                    onEdit: {
                        minutes = store.activeWeeklyGoal?.targetMinutes ?? 300
                        editingGoalType = .weekly
                    }
                )
            }
            .padding()
        }
        .navigationTitle("目標設定")
        .sheet(item: $editingGoalType) { type in
            GoalEditorSheet(
                type: type,
                initialMinutes: minutes
            ) { targetMinutes in
                store.updateGoal(type: type, targetMinutes: targetMinutes)
                editingGoalType = nil
            }
        }
    }
}

private struct HistoryScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var filterSubjectId: Int64?
    @State private var editTarget: StudySession?
    @State private var deleteTarget: StudySession?

    private var filteredSessions: [StudySession] {
        if let filterSubjectId {
            return store.sessions.filter { $0.subjectId == filterSubjectId }
        }
        return store.sessions
    }

    var body: some View {
        List {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "すべて", isSelected: filterSubjectId == nil) {
                        filterSubjectId = nil
                    }
                    ForEach(store.subjects) { subject in
                        FilterChip(title: subject.name, isSelected: filterSubjectId == subject.id) {
                            filterSubjectId = subject.id
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if filteredSessions.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "学習履歴がありません",
                    message: "タイマーで学習を記録しましょう"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredSessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.subjectName + (session.materialName.isEmpty ? "" : " - \(session.materialName)"))
                            .font(.headline)
                        Text(session.startTime.formatted(date: .abbreviated, time: .shortened) + " - " + session.endTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.durationJapaneseText)
                            .foregroundStyle(store.selectedColorTheme.primaryColor)
                        if let note = session.note, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            deleteTarget = session
                        }
                        Button("編集") {
                            editTarget = session
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("学習履歴")
        .sheet(item: $editTarget) { session in
            SessionEditorSheet(session: session) { durationMinutes, note in
                store.updateSession(id: session.id, durationMinutes: durationMinutes, note: note)
                editTarget = nil
            }
        }
        .alert("学習記録を削除", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { session in
            Button("削除", role: .destructive) {
                store.deleteSession(session)
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { _ in
            Text("この学習記録を削除しますか？")
        }
    }
}

private struct PlanScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var isPresentingCreate = false
    @State private var isPresentingAddItem = false
    @State private var editingItem: PlanItem?
    @State private var deleteItem: PlanItem?

    var body: some View {
        List {
            if let activePlan = store.activePlan {
                let summary = store.weeklyPlanSummary(for: activePlan)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activePlan.name)
                            .font(.title3.bold())
                        Text("目標 \(Goal.format(minutes: summary.totalTargetMinutes)) / 実績 \(Goal.format(minutes: summary.totalActualMinutes))")
                            .foregroundStyle(.secondary)
                        ProgressView(value: store.completionRate(for: activePlan))
                        Text("達成率 \(Int(store.completionRate(for: activePlan) * 100))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.selectedColorTheme.primaryColor)
                    }
                }

                ForEach(StudyWeekday.allCases) { weekday in
                    Section(weekday.japaneseTitle) {
                        let items = store.weeklySchedule(for: activePlan)[weekday] ?? []
                        if items.isEmpty {
                            Text("予定はありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.subject.name)
                                        .font(.headline)
                                    HStack {
                                        Text("目標 \(Goal.format(minutes: item.item.targetMinutes))")
                                        Spacer()
                                        Text("実績 \(Goal.format(minutes: item.item.actualMinutes))")
                                            .foregroundStyle(store.selectedColorTheme.primaryColor)
                                    }
                                    .font(.subheadline)
                                    if let timeSlot = item.item.timeSlot, !timeSlot.isEmpty {
                                        Text(timeSlot)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button("削除", role: .destructive) {
                                        deleteItem = item.item
                                    }
                                    Button("編集") {
                                        editingItem = item.item
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "学習計画がありません",
                    message: "作成ボタンから週間計画を追加してください"
                )
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("学習計画")
        .toolbar {
            if store.activePlan == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        isPresentingCreate = true
                    }
                }
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button(role: .destructive) {
                        store.deleteActivePlan()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            NavigationStack {
                PlanEditorSheet(subjects: store.subjects) { name, startDate, endDate, items in
                    store.createPlan(name: name, startDate: startDate, endDate: endDate, items: items)
                    isPresentingCreate = false
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            NavigationStack {
                PlanItemEditorSheet(subjects: store.subjects, item: nil) { item in
                    store.addPlanItem(
                        subjectId: item.subjectId,
                        dayOfWeek: item.dayOfWeek,
                        targetMinutes: item.targetMinutes,
                        timeSlot: item.timeSlot
                    )
                    isPresentingAddItem = false
                }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                PlanItemEditorSheet(subjects: store.subjects, item: item) { updatedItem in
                    store.updatePlanItem(updatedItem)
                    editingItem = nil
                }
            }
        }
        .alert("計画項目を削除", isPresented: Binding(
            get: { deleteItem != nil },
            set: { if !$0 { deleteItem = nil } }
        ), presenting: deleteItem) { item in
            Button("削除", role: .destructive) {
                store.deletePlanItem(item)
                deleteItem = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteItem = nil
            }
        } message: { _ in
            Text("この項目を削除しますか？")
        }
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var isPresentingExportOptions = false
    @State private var shareURL: URL?
    @State private var isPresentingShareSheet = false
    @State private var isPresentingImporter = false
    @State private var isDeleting = false

    private var totalSessions: Int {
        store.sessions.count
    }

    private var totalMinutes: Int {
        store.sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        Form {
            Section("テーマ設定") {
                Picker("カラーテーマ", selection: Binding(
                    get: { store.selectedColorTheme },
                    set: { store.setColorTheme($0) }
                )) {
                    ForEach(ColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Picker("テーマモード", selection: Binding(
                    get: { store.selectedThemeMode },
                    set: { store.setThemeMode($0) }
                )) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("通知") {
                Toggle("リマインダー通知", isOn: Binding(
                    get: { store.reminderEnabled },
                    set: { enabled in
                        Task { await store.setReminderEnabled(enabled) }
                    }
                ))

                DatePicker(
                    "リマインダー時刻",
                    selection: Binding(
                        get: {
                            Calendar.current.date(from: DateComponents(hour: store.reminderHour, minute: store.reminderMinute)) ?? Date()
                        },
                        set: { newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            Task { await store.setReminderTime(hour: components.hour ?? 19, minute: components.minute ?? 0) }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!store.reminderEnabled)
            }

            Section("学習データ") {
                LabeledContent("総セッション数", value: "\(totalSessions)")
                LabeledContent("総学習時間", value: Goal.format(minutes: totalMinutes))

                Button("エクスポート") {
                    isPresentingExportOptions = true
                }

                Button("インポート") {
                    isPresentingImporter = true
                }

                Button("データを削除", role: .destructive) {
                    isDeleting = true
                }
            }

            Section("アプリ情報") {
                LabeledContent("バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Text("Android版の学習管理機能をiOSに移植したローカル保存アプリです。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
        .confirmationDialog("エクスポート形式", isPresented: $isPresentingExportOptions) {
            ForEach(ExportFormat.allCases) { format in
                Button(format.title) {
                    Task {
                        shareURL = await store.exportFile(format: format)
                        isPresentingShareSheet = shareURL != nil
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    await store.importBackup(from: url)
                }
            }
        }
        .sheet(isPresented: $isPresentingShareSheet, onDismiss: {
            shareURL = nil
        }) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .alert("データを削除", isPresented: $isDeleting) {
            Button("削除", role: .destructive) {
                store.deleteAllData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("学習データをすべて削除しますか？")
        }
    }
}

private struct ReportsOverviewPlaceholder: View {
    var body: some View { EmptyView() }
}

private struct DailyReportView: View {
    let data: [DailyStudyData]

    var body: some View {
        StudySectionCard(title: "日別", systemImage: "chart.bar.xaxis") {
            if data.isEmpty {
                Text("データがありません").foregroundStyle(.secondary)
            } else {
                DailyChart(data: data)
            }
        }
    }
}

private struct WeeklyReportView: View {
    let data: [WeeklyStudyData]

    var body: some View {
        StudySectionCard(title: "週別", systemImage: "calendar.badge.clock") {
            if data.isEmpty {
                Text("データがありません").foregroundStyle(.secondary)
            } else {
                WeeklyChart(data: data)
            }
        }
    }
}

private struct MonthlyReportView: View {
    let data: [MonthlyStudyData]

    var body: some View {
        StudySectionCard(title: "月別", systemImage: "calendar") {
            if data.isEmpty {
                Text("データがありません").foregroundStyle(.secondary)
            } else {
                MonthlyChart(data: data)
            }
        }
    }
}

private struct SubjectReportView: View {
    let data: [SubjectStudyData]

    var body: some View {
        StudySectionCard(title: "科目別", systemImage: "chart.pie.fill") {
            if data.isEmpty {
                Text("データがありません").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    SubjectPieChart(data: data)
                    ForEach(data) { item in
                        HStack {
                            Circle()
                                .fill(Color(hex: item.color))
                                .frame(width: 12, height: 12)
                            Text(item.subjectName)
                            Spacer()
                            Text("\(item.hours)時間\(item.minutes)分")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct MaterialRow: View {
    @EnvironmentObject private var store: StudyAppStore
    let material: Material

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name)
                        .font(.headline)
                    Text(store.subject(for: material.subjectId)?.name ?? "未分類")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if material.totalPages > 0 {
                HStack {
                    Text("ページ \(material.currentPage) / \(material.totalPages)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(material.progressPercent)%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.selectedColorTheme.primaryColor)
                }
                ProgressView(value: material.progress)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GoalCard: View {
    let title: String
    let currentMinutes: Int
    let goal: Goal?
    let onEdit: () -> Void

    var body: some View {
        StudySectionCard(title: title, systemImage: "flag.fill") {
            if let goal {
                let progress = min(Double(currentMinutes) / Double(max(goal.targetMinutes, 1)), 1)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(Goal.format(minutes: currentMinutes))
                            .font(.title2.bold())
                            .foregroundStyle(progress >= 1 ? Color.green : .primary)
                        Spacer()
                        Button("編集", action: onEdit)
                    }

                    Text("目標: \(goal.targetFormatted)")
                        .foregroundStyle(.secondary)

                    ProgressView(value: progress)
                    Text(progress >= 1 ? "目標達成！" : "達成率 \(Int(progress * 100))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress >= 1 ? Color.green : .secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("目標が未設定です")
                        .foregroundStyle(.secondary)
                    Button("設定する", action: onEdit)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct TimerTipSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("タイマータブからすぐに学習を開始できます。")
                .multilineTextAlignment(.center)
            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [Subject]
    let materials: [Material]
    let onSave: (Int64, Int64?, Int, String?) -> Void

    @State private var subjectId: Int64 = 0
    @State private var materialId: Int64 = 0
    @State private var durationMinutes = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("科目", selection: $subjectId) {
                    ForEach(subjects) { subject in
                        Text(subject.name).tag(subject.id)
                    }
                }

                Picker("教材", selection: $materialId) {
                    Text("なし").tag(Int64(0))
                    ForEach(materials.filter { $0.subjectId == subjectId }) { material in
                        Text(material.name).tag(material.id)
                    }
                }

                TextField("学習時間（分）", text: $durationMinutes)
                    .keyboardType(.numberPad)
                TextField("メモ", text: $note, axis: .vertical)
            }
            .navigationTitle("手動入力")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(subjectId, materialId == 0 ? nil : materialId, Int(durationMinutes) ?? 0, note.nilIfBlank)
                        dismiss()
                    }
                    .disabled(subjectId == 0 || (Int(durationMinutes) ?? 0) <= 0)
                }
            }
        }
        .onAppear {
            subjectId = subjects.first?.id ?? 0
        }
    }
}

private struct MaterialEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: MaterialDraft
    let subjects: [Subject]
    let isEditing: Bool
    let onSave: () -> Void

    var body: some View {
        Form {
            TextField("教材名", text: $draft.name)

            Picker("科目", selection: $draft.subjectId) {
                ForEach(subjects) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }

            TextField("総ページ数", text: $draft.totalPages)
                .keyboardType(.numberPad)

            TextField("メモ", text: $draft.note, axis: .vertical)
        }
        .navigationTitle(isEditing ? "教材を編集" : "教材を追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave()
                    dismiss()
                }
            }
        }
        .onAppear {
            if draft.subjectId == 0 {
                draft.subjectId = subjects.first?.id ?? 0
            }
        }
    }
}

private struct ProgressEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let material: Material
    let onSave: (Int) -> Void
    @State private var page: String

    init(material: Material, onSave: @escaping (Int) -> Void) {
        self.material = material
        self.onSave = onSave
        _page = State(initialValue: "\(material.currentPage)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("総ページ数: \(material.totalPages)")
                TextField("現在のページ", text: $page)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("進捗を更新")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(Int(page) ?? material.currentPage)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ISBNLookupSheet: View {
    @EnvironmentObject private var store: StudyAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var isbn = ""
    @State private var selectedSubjectId: Int64 = 0
    @State private var isPresentingScanner = false

    var body: some View {
        Form {
            Section("ISBN検索") {
                TextField("ISBN", text: $isbn)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("検索") {
                    Task { await store.searchBookByIsbn(isbn) }
                }

                Button("バーコードを読み取る") {
                    isPresentingScanner = true
                }
            }

            if let result = store.bookSearchResult {
                Section("検索結果") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title)
                            .font(.headline)
                        if !result.authors.isEmpty {
                            Text("著者: \(result.authors.joined(separator: ", "))")
                                .font(.subheadline)
                        }
                        if let publisher = result.publisher {
                            Text("出版社: \(publisher)")
                                .font(.subheadline)
                        }
                        if let pageCount = result.pageCount {
                            Text("ページ数: \(pageCount)")
                                .font(.subheadline)
                        }
                    }

                    Picker("科目", selection: $selectedSubjectId) {
                        ForEach(store.subjects) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }

                    Button("教材として追加") {
                        store.addMaterial(from: result, subjectId: selectedSubjectId)
                        dismiss()
                    }
                    .disabled(store.subjects.isEmpty || selectedSubjectId == 0)
                }
            }
        }
        .navigationTitle("ISBN検索")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    store.clearSearchResult()
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedSubjectId = store.subjects.first?.id ?? 0
        }
        .sheet(isPresented: $isPresentingScanner) {
            BarcodeScannerSheet { code in
                isbn = code
                Task { await store.searchBookByIsbn(code) }
            }
        }
    }
}

private struct ExamEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: ExamDraft
    let isEditing: Bool
    let onSave: () -> Void

    var body: some View {
        Form {
            TextField("テスト名", text: $draft.name)
            DatePicker("日付", selection: $draft.date, displayedComponents: .date)
            TextField("メモ", text: $draft.note, axis: .vertical)
        }
        .navigationTitle(isEditing ? "テストを編集" : "テストを追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

private struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let type: GoalType
    @State private var hours: String
    @State private var minutes: String
    let onSave: (Int) -> Void

    init(type: GoalType, initialMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.type = type
        self.onSave = onSave
        _hours = State(initialValue: "\(initialMinutes / 60)")
        _minutes = State(initialValue: "\(initialMinutes % 60)")
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    TextField("時間", text: $hours)
                        .keyboardType(.numberPad)
                    Text("時間")
                    TextField("分", text: $minutes)
                        .keyboardType(.numberPad)
                    Text("分")
                }
            }
            .navigationTitle(type.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let total = (Int(hours) ?? 0) * 60 + (Int(minutes) ?? 0)
                        onSave(total)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SessionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: StudySession
    let onSave: (Int, String?) -> Void
    @State private var durationMinutes: String
    @State private var note: String

    init(session: StudySession, onSave: @escaping (Int, String?) -> Void) {
        self.session = session
        self.onSave = onSave
        _durationMinutes = State(initialValue: "\(session.durationMinutes)")
        _note = State(initialValue: session.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("学習時間（分）", text: $durationMinutes)
                    .keyboardType(.numberPad)
                TextField("メモ", text: $note, axis: .vertical)
            }
            .navigationTitle("履歴を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(Int(durationMinutes) ?? session.durationMinutes, note.nilIfBlank)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [Subject]
    let onSave: (String, Date, Date, [PlanItem]) -> Void
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var items: [PlanItemDraft] = [PlanItemDraft()]

    var body: some View {
        Form {
            TextField("プラン名", text: $name)
            DatePicker("開始日", selection: $startDate, displayedComponents: .date)
            DatePicker("終了日", selection: $endDate, displayedComponents: .date)

            Section("学習項目") {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("科目", selection: $item.subjectId) {
                            ForEach(subjects) { subject in
                                Text(subject.name).tag(subject.id)
                            }
                        }
                        Picker("曜日", selection: $item.dayOfWeek) {
                            ForEach(StudyWeekday.allCases) { day in
                                Text(day.japaneseTitle).tag(day)
                            }
                        }
                        TextField("目標（分）", text: $item.targetMinutes)
                            .keyboardType(.numberPad)
                        TextField("時間帯", text: $item.timeSlot)
                    }
                }

                Button("項目を追加") {
                    items.append(PlanItemDraft(subjectId: subjects.first?.id ?? 0))
                }
            }
        }
        .navigationTitle("計画を作成")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("作成") {
                    let planItems = items.compactMap { draft -> PlanItem? in
                        guard let minutes = Int(draft.targetMinutes), minutes > 0 else { return nil }
                        return PlanItem(
                            id: 0,
                            planId: 0,
                            subjectId: draft.subjectId,
                            dayOfWeek: draft.dayOfWeek,
                            targetMinutes: minutes,
                            actualMinutes: 0,
                            timeSlot: draft.timeSlot.nilIfBlank
                        )
                    }
                    onSave(name, startDate, endDate, planItems)
                    dismiss()
                }
            }
        }
        .onAppear {
            if items.first?.subjectId == 0 {
                items[0].subjectId = subjects.first?.id ?? 0
            }
        }
    }
}

private struct PlanItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [Subject]
    let item: PlanItem?
    let onSave: (PlanItem) -> Void
    @State private var draft: PlanItemDraft

    init(subjects: [Subject], item: PlanItem?, onSave: @escaping (PlanItem) -> Void) {
        self.subjects = subjects
        self.item = item
        self.onSave = onSave
        _draft = State(initialValue: PlanItemDraft(item: item, fallbackSubjectId: subjects.first?.id ?? 0))
    }

    var body: some View {
        Form {
            Picker("科目", selection: $draft.subjectId) {
                ForEach(subjects) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }

            Picker("曜日", selection: $draft.dayOfWeek) {
                ForEach(StudyWeekday.allCases) { day in
                    Text(day.japaneseTitle).tag(day)
                }
            }

            TextField("目標（分）", text: $draft.targetMinutes)
                .keyboardType(.numberPad)
            TextField("時間帯", text: $draft.timeSlot)
        }
        .navigationTitle(item == nil ? "計画項目を追加" : "計画項目を編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard let minutes = Int(draft.targetMinutes), minutes > 0 else { return }
                    onSave(
                        PlanItem(
                            id: item?.id ?? 0,
                            planId: item?.planId ?? 0,
                            subjectId: draft.subjectId,
                            dayOfWeek: draft.dayOfWeek,
                            targetMinutes: minutes,
                            actualMinutes: item?.actualMinutes ?? 0,
                            timeSlot: draft.timeSlot.nilIfBlank
                        )
                    )
                    dismiss()
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct BarcodeScannerSheet: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BarcodeScannerView { code in
                    onCodeScanned(code)
                    dismiss()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("バーコードスキャン")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct BarcodeScannerView: View {
    let onCodeScanned: (String) -> Void

    var body: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            ScannerRepresentable(onCodeScanned: onCodeScanned)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40))
                Text("この端末ではバーコードスキャンを利用できません。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        #else
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
            Text("この環境ではバーコードスキャンを利用できません。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        #endif
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCodeScanned: (String) -> Void

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let first = addedItems.first else { return }
            switch first {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    onCodeScanned(payload)
                }
            default:
                break
            }
        }
    }
}
#endif

private struct OnboardingPage {
    let title: String
    let description: String
    let systemImage: String
    let color: Color
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let day: Int

    static let placeholder = CalendarDay(date: nil, day: 0)
}

private enum HomeSheet: String, Identifiable {
    case history
    case settings
    case goals
    case exams
    case plan
    case materials
    case timerTip

    var id: String { rawValue }
}

private enum ReportsTab: String, CaseIterable, Identifiable {
    case overview
    case daily
    case weekly
    case monthly
    case subject

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "概要"
        case .daily: return "日別"
        case .weekly: return "週別"
        case .monthly: return "月別"
        case .subject: return "科目別"
        }
    }
}

private struct MaterialDraft {
    var name = ""
    var subjectId: Int64 = 0
    var totalPages = ""
    var note = ""

    init(material: Material? = nil) {
        if let material {
            name = material.name
            subjectId = material.subjectId
            totalPages = "\(material.totalPages)"
            note = material.note ?? ""
        }
    }

    func makeMaterial(id: Int64 = 0, currentPage: Int = 0) -> Material {
        Material(
            id: id,
            name: name,
            subjectId: subjectId,
            totalPages: Int(totalPages) ?? 0,
            currentPage: currentPage,
            color: nil,
            note: note.nilIfBlank
        )
    }
}

private struct ExamDraft {
    var name = ""
    var date = Date()
    var note = ""

    init(exam: Exam? = nil) {
        if let exam {
            name = exam.name
            date = exam.date
            note = exam.note ?? ""
        }
    }

    func makeExam(id: Int64) -> Exam {
        Exam(id: id, name: name, date: date, note: note.nilIfBlank)
    }
}

private struct PlanItemDraft: Identifiable {
    let id = UUID()
    var subjectId: Int64
    var dayOfWeek: StudyWeekday = .monday
    var targetMinutes = ""
    var timeSlot = ""

    init(subjectId: Int64 = 0) {
        self.subjectId = subjectId
    }

    init(item: PlanItem?, fallbackSubjectId: Int64) {
        if let item {
            subjectId = item.subjectId
            dayOfWeek = item.dayOfWeek
            targetMinutes = "\(item.targetMinutes)"
            timeSlot = item.timeSlot ?? ""
        } else {
            subjectId = fallbackSubjectId
        }
    }
}

private func durationString(_ duration: TimeInterval) -> String {
    let seconds = Int(duration.rounded())
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

#if canImport(Charts)
private struct DailyChart: View {
    let data: [DailyStudyData]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("日付", item.dateLabel),
                y: .value("分", item.minutes)
            )
            .foregroundStyle(item.minutes >= 120 ? Color(hex: 0x4CAF50) : item.minutes >= 60 ? Color(hex: 0x2196F3) : Color(hex: 0xFF9800))
        }
        .frame(height: 220)
    }
}

private struct WeeklyChart: View {
    let data: [WeeklyStudyData]

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("週", item.weekLabel),
                y: .value("時間", item.hours * 60 + item.minutes)
            )
            .foregroundStyle(.tint)
        }
        .frame(height: 220)
    }
}

private struct MonthlyChart: View {
    let data: [MonthlyStudyData]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("月", item.monthLabel),
                y: .value("時間", item.totalHours)
            )
            .foregroundStyle(.tint)
        }
        .frame(height: 220)
    }
}

private struct SubjectPieChart: View {
    let data: [SubjectStudyData]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("科目", item.subjectName),
                y: .value("時間", item.hours * 60 + item.minutes)
            )
            .foregroundStyle(Color(hex: item.color))
        }
        .frame(height: 220)
    }
}
#else
private struct DailyChart: View {
    let data: [DailyStudyData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data) { item in
                HStack {
                    Text(item.dateLabel)
                    Spacer()
                    Text("\(item.minutes)分")
                }
            }
        }
    }
}

private struct WeeklyChart: View {
    let data: [WeeklyStudyData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data) { item in
                HStack {
                    Text(item.weekLabel)
                    Spacer()
                    Text("\(item.hours)時間\(item.minutes)分")
                }
            }
        }
    }
}

private struct MonthlyChart: View {
    let data: [MonthlyStudyData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data) { item in
                HStack {
                    Text(item.monthLabel)
                    Spacer()
                    Text("\(item.totalHours)時間")
                }
            }
        }
    }
}

private struct SubjectPieChart: View {
    let data: [SubjectStudyData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data) { item in
                HStack {
                    Circle()
                        .fill(Color(hex: item.color))
                        .frame(width: 12, height: 12)
                    Text(item.subjectName)
                    Spacer()
                    Text("\(item.hours)時間\(item.minutes)分")
                }
            }
        }
    }
}
#endif

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
