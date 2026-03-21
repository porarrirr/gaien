import SwiftUI

// MARK: - Root

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
                LoadingSplash()
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

private struct LoadingSplash: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            Text("StudyApp")
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.subtleBackground)
        .onAppear { pulse = true }
    }
}

// MARK: - MainTabView

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

// MARK: - Onboarding

private struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel
    @State private var selection = 0

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "学習時間を記録", description: "タイマーと手動入力で学習履歴を残せます。", systemImage: "timer", gradient: [Color(hex: 0x4CAF50), Color(hex: 0x66BB6A)]),
        OnboardingPage(title: "教材を管理", description: "教材の進捗や関連する科目をまとめて管理できます。", systemImage: "books.vertical.fill", gradient: [Color(hex: 0x2196F3), Color(hex: 0x42A5F5)]),
        OnboardingPage(title: "目標と計画", description: "日次・週次の目標と学習計画を Android と同じ考え方で扱います。", systemImage: "flag.fill", gradient: [Color(hex: 0xFF9800), Color(hex: 0xFFA726)])
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        Image(systemName: page.systemImage)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 130, height: 130)
                            .background(
                                LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                            .shadow(color: page.gradient.first?.opacity(0.4) ?? .clear, radius: 16, y: 8)

                        Text(page.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppColors.textPrimary)

                        Text(page.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.xl)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicators
            HStack(spacing: 10) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == selection ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == selection ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: selection)
                }
            }
            .padding(.bottom, AppSpacing.lg)

            Button {
                viewModel.complete()
            } label: {
                Text(selection == pages.count - 1 ? "始める" : "スキップ")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.subtleBackground)
    }
}

// MARK: - HomeScreen

private struct HomeScreen: View {
    @StateObject private var viewModel: HomeViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(app: app))
    }

    private var dailyGoalMinutes: Int {
        60
    }

    private var todayProgress: Double {
        let target = max(dailyGoalMinutes, 1)
        return Double(viewModel.homeData.todayStudyMinutes) / Double(target)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Hero Section
                heroSection
                    .padding(.horizontal, AppSpacing.md)

                // Weekly Goal
                weeklyGoalSection
                    .padding(.horizontal, AppSpacing.md)

                // Today's Sessions
                todaySessionsSection
                    .padding(.horizontal, AppSpacing.md)

                // Upcoming Exams
                upcomingExamsSection
                    .padding(.horizontal, AppSpacing.md)

                // Recent Materials
                recentMaterialsSection
                    .padding(.horizontal, AppSpacing.md)

                // Quick Navigation
                quickNavSection
                    .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("ホーム")
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var heroSection: some View {
        GradientCard(colors: [
            viewModel.app.preferences.selectedColorTheme.primaryColor,
            viewModel.app.preferences.selectedColorTheme.primaryColor.opacity(0.7)
        ]) {
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("今日の学習")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(viewModel.homeData.todayStudyMinutes)分")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(Goal.format(minutes: viewModel.homeData.todayStudyMinutes))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                ProgressRing(
                    progress: todayProgress,
                    size: 100,
                    lineWidth: 10,
                    ringColor: .white,
                    trackColor: .white.opacity(0.25),
                    showPercentage: false
                )
                .overlay {
                    Text("\(Int(min(todayProgress, 1.0) * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var weeklyGoalSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "週間目標", icon: "target")
            if let goal = viewModel.homeData.weeklyGoal {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text(Goal.format(minutes: viewModel.homeData.weeklyStudyMinutes))
                            .font(.headline)
                        Spacer()
                        Text(goal.targetFormatted)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    AnimatedProgressBar(
                        value: Double(viewModel.homeData.weeklyStudyMinutes),
                        total: Double(max(goal.targetMinutes, 1)),
                        height: 10
                    )
                }
                .cardStyle()
            } else {
                Text("目標が未設定です")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            }
        }
    }

    private var todaySessionsSection: some View {
        Group {
            if !viewModel.homeData.todaySessions.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "今日のセッション", icon: "clock.fill")
                    ForEach(viewModel.homeData.todaySessions) { session in
                        HStack(spacing: AppSpacing.md) {
                            Circle()
                                .fill(.tint.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "book.fill")
                                        .foregroundStyle(.tint)
                                        .font(.subheadline)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.subjectName)
                                    .font(.subheadline.bold())
                                Text(session.materialName.isEmpty ? "" : session.materialName)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Text("\(Int(session.duration / 60_000))分")
                                .font(.subheadline.bold())
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .cardStyle()
                }
            }
        }
    }

    private var upcomingExamsSection: some View {
        Group {
            if !viewModel.homeData.upcomingExams.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "今後のテスト", icon: "doc.text.fill")
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.homeData.upcomingExams.prefix(3)) { exam in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exam.name)
                                        .font(.subheadline.bold())
                                    Text(exam.dateValue.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer()
                                UrgencyBadge(daysRemaining: max(exam.daysRemaining(), 0))
                            }
                            if exam.id != viewModel.homeData.upcomingExams.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                    .cardStyle()
                }
            }
        }
    }

    private var recentMaterialsSection: some View {
        Group {
            if !viewModel.recentMaterials.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "最近使った教材", icon: "book.closed.fill")
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(viewModel.recentMaterials.prefix(5).enumerated()), id: \.offset) { _, pair in
                            let material = pair.0
                            let subject = pair.1
                            HStack(spacing: AppSpacing.md) {
                                ColorDot(color: Color(hex: subject.color), size: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(material.name)
                                        .font(.subheadline)
                                    Text(subject.name)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer()
                                if material.totalPages > 0 {
                                    Text("\(material.progressPercent)%")
                                        .font(.caption.bold())
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    .cardStyle()
                }
            }
        }
    }

    private var quickNavSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "移動", icon: "square.grid.2x2.fill")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3), spacing: AppSpacing.sm) {
                QuickNavButton(icon: "doc.text.fill", label: "試験") {
                    ExamsScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "square.grid.2x2", label: "科目") {
                    SubjectsScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "clock.arrow.circlepath", label: "履歴") {
                    HistoryScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "target", label: "目標") {
                    GoalsScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "calendar.badge.plus", label: "計画") {
                    PlanScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "gearshape.fill", label: "設定") {
                    SettingsScreen(app: viewModel.app)
                }
            }
        }
    }
}

// MARK: - TimerScreen

private struct TimerScreen: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var showManualEntry = false
    @State private var manualMinutes = ""
    @State private var manualNote = ""
    @State private var pulseTimer = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimerViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Subject / Material selectors
                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.tint)
                            Picker("科目", selection: Binding(get: { viewModel.selectedSubjectId ?? 0 }, set: { viewModel.selectedSubjectId = $0 })) {
                                ForEach(viewModel.subjects) { subject in
                                    Text(subject.name).tag(subject.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.tint)
                            Picker("教材", selection: Binding(get: { viewModel.selectedMaterialId ?? 0 }, set: { viewModel.selectedMaterialId = $0 == 0 ? nil : $0 })) {
                                Text("なし").tag(Int64(0))
                                ForEach(viewModel.materialsForSelectedSubject()) { material in
                                    Text(material.name).tag(material.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Spacer().frame(height: AppSpacing.md)

                    // Main Timer Ring
                    ZStack {
                        ProgressRing(
                            progress: timerProgress,
                            size: 260,
                            lineWidth: 16,
                            ringColor: viewModel.isRunning ? Color.accentColor : Color.secondary.opacity(0.4),
                            showPercentage: false
                        )
                        .scaleEffect(pulseTimer && viewModel.isRunning ? 1.02 : 1.0)

                        VStack(spacing: AppSpacing.xs) {
                            Text(durationString(milliseconds: viewModel.elapsedMilliseconds))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                            if viewModel.isRunning {
                                Text("記録中")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tint)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(.tint.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseTimer)
                    .onChange(of: viewModel.isRunning) { running in
                        pulseTimer = running
                    }

                    Spacer().frame(height: AppSpacing.md)

                    // Control Buttons
                    HStack(spacing: AppSpacing.xl) {
                        // Stop Button
                        Button {
                            viewModel.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 64, height: 64)
                                .background(
                                    Circle().fill(viewModel.elapsedMilliseconds > 0 ? AppColors.danger : Color.secondary.opacity(0.3))
                                )
                        }
                        .disabled(viewModel.elapsedMilliseconds == 0)

                        // Play / Pause Button
                        Button {
                            viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                        } label: {
                            Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle().fill(.tint)
                                )
                                .shadow(color: .tint.opacity(0.4), radius: 12, y: 4)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }

            // Manual entry button at bottom
            Button {
                showManualEntry = true
            } label: {
                HStack {
                    Image(systemName: "pencil.line")
                    Text("手動入力")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("タイマー")
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                ManualEntrySheet(viewModel: viewModel, manualMinutes: $manualMinutes, manualNote: $manualNote, isPresented: $showManualEntry)
            }
        }
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

    private var timerProgress: Double {
        let targetMs: Double = 60 * 60 * 1000
        return min(Double(viewModel.elapsedMilliseconds) / targetMs, 1.0)
    }
}

private struct ManualEntrySheet: View {
    let viewModel: TimerViewModel
    @Binding var manualMinutes: String
    @Binding var manualNote: String
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("学習対象") {
                HStack {
                    Text("科目")
                    Spacer()
                    Text(viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectId })?.name ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
            Section("記録") {
                TextField("学習時間（分）", text: $manualMinutes)
                    .keyboardType(.numberPad)
                TextField("メモ", text: $manualNote, axis: .vertical)
            }
        }
        .navigationTitle("手動入力")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
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
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - CalendarScreen

private struct CalendarScreen: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDay: Int? = nil

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(app: app))
    }

    private var calendar: Calendar { Calendar.current }

    private var displayYear: Int {
        calendar.component(.year, from: viewModel.displayedMonth)
    }

    private var displayMonth: Int {
        calendar.component(.month, from: viewModel.displayedMonth)
    }

    private var todayDay: Int? {
        let now = Date()
        guard calendar.component(.year, from: now) == displayYear,
              calendar.component(.month, from: now) == displayMonth else { return nil }
        return calendar.component(.day, from: now)
    }

    private var daysInMonth: Int {
        guard let range = calendar.range(of: .day, in: .month, for: viewModel.displayedMonth) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: 1)) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return weekday - 1 // 0-indexed, Sunday=0
    }

    private var maxMinutes: Int {
        viewModel.monthStudyMap.values.max() ?? 1
    }

    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Month navigation
                HStack {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("\(displayYear)年\(displayMonth)月")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption.bold())
                            .foregroundStyle(label == "日" ? AppColors.danger : (label == "土" ? Color(hex: 0x2196F3) : AppColors.textSecondary))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<(firstWeekday + daysInMonth), id: \.self) { index in
                        if index < firstWeekday {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        } else {
                            let day = index - firstWeekday + 1
                            CalendarDayCell(
                                day: day,
                                minutes: viewModel.monthStudyMap[day] ?? 0,
                                isToday: day == todayDay,
                                isSelected: day == selectedDay,
                                maxMinutes: maxMinutes
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDay = (selectedDay == day) ? nil : day
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Selected day detail
                if let day = selectedDay {
                    let minutes = viewModel.monthStudyMap[day] ?? 0
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeaderView(title: "\(displayMonth)月\(day)日の学習", icon: "clock.fill")
                        if minutes > 0 {
                            HStack {
                                StatCard(icon: "clock.fill", value: "\(minutes)", label: "分")
                                StatCard(icon: "flame.fill", value: Goal.format(minutes: minutes), label: "学習時間", iconColor: AppColors.warning)
                            }
                        } else {
                            Text("この日の記録はありません")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle()
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Monthly summary
                let totalMinutes = viewModel.monthStudyMap.values.reduce(0, +)
                let studyDays = viewModel.monthStudyMap.values.filter { $0 > 0 }.count
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "月間サマリー", icon: "chart.bar.fill")
                    HStack(spacing: AppSpacing.sm) {
                        StatCard(icon: "clock.fill", value: Goal.format(minutes: totalMinutes), label: "合計")
                        StatCard(icon: "calendar", value: "\(studyDays)日", label: "学習日数", iconColor: AppColors.success)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("カレンダー")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
        .onChange(of: viewModel.displayedMonth) { _ in
            selectedDay = nil
            Task { await viewModel.load() }
        }
    }

    private func moveMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: viewModel.displayedMonth) {
            viewModel.displayedMonth = next
        }
    }
}

// MARK: - ReportsScreen

private struct ReportsScreen: View {
    @StateObject private var viewModel: ReportsViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Streak Section
                streakSection
                    .padding(.horizontal, AppSpacing.md)

                // Daily Chart
                dailyChartSection
                    .padding(.horizontal, AppSpacing.md)

                // Weekly Chart
                weeklyChartSection
                    .padding(.horizontal, AppSpacing.md)

                // Subject Breakdown
                subjectSection
                    .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("レポート")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }

    private var streakSection: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.sm) {
                Text("🔥")
                    .font(.system(size: 36))
                Text("\(viewModel.reports.streakDays)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.reports.streakDays > 0 ? AppColors.warning : AppColors.textSecondary)
                Text("連続日数")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            VStack(spacing: AppSpacing.sm) {
                Text("🏆")
                    .font(.system(size: 36))
                Text("\(viewModel.reports.bestStreak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.success)
                Text("最長記録")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }

    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "日別学習時間", icon: "chart.bar.fill")
            if viewModel.reports.daily.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                SimpleBarChart(
                    data: viewModel.reports.daily.suffix(7).map { item in
                        (label: String(item.dateLabel.suffix(3)), value: Double(item.minutes))
                    },
                    maxBarHeight: 140
                )
            }
        }
        .cardStyle()
    }

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "週別学習時間", icon: "calendar")
            if viewModel.reports.weekly.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                SimpleBarChart(
                    data: viewModel.reports.weekly.suffix(4).map { item in
                        (label: item.weekLabel, value: Double(item.hours * 60 + item.minutes))
                    },
                    barColor: Color(hex: 0x2196F3),
                    maxBarHeight: 120
                )
            }
        }
        .cardStyle()
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "科目別", icon: "square.grid.2x2.fill")
            if viewModel.reports.bySubject.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                HorizontalBarChart(
                    data: viewModel.reports.bySubject.map { item in
                        (
                            label: item.subjectName,
                            value: Double(item.hours * 60 + item.minutes),
                            color: Color(hex: item.color)
                        )
                    }
                )

                Divider()

                ForEach(viewModel.reports.bySubject) { item in
                    HStack(spacing: AppSpacing.sm) {
                        ColorDot(color: Color(hex: item.color), size: 12)
                        Text(item.subjectName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.hours)時間\(item.minutes)分")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - ExamsScreen

struct ExamsScreen: View {
    @StateObject private var viewModel: ExamsViewModel
    @State private var showAddSheet = false
    @State private var editingExam: Exam?
    @State private var name = ""
    @State private var date = Date()
    @State private var note = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ExamsViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.exams.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "テストがありません",
                    description: "右上の＋ボタンからテストを追加してください。",
                    buttonTitle: "テストを追加",
                    onAction: { showAddSheet = true }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.exams) { exam in
                            ExamCard(exam: exam, onEdit: {
                                name = exam.name
                                date = exam.dateValue
                                note = exam.note ?? ""
                                editingExam = exam
                            }, onDelete: {
                                viewModel.deleteExam(exam)
                            })
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("試験")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    name = ""
                    date = Date()
                    note = ""
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                ExamEditorSheet(name: $name, date: $date, note: $note, title: "テストを追加") {
                    viewModel.saveExam(name: name, date: date, note: note)
                    showAddSheet = false
                } onCancel: {
                    showAddSheet = false
                }
            }
        }
        .sheet(item: $editingExam) { exam in
            NavigationStack {
                ExamEditorSheet(name: $name, date: $date, note: $note, title: "テストを編集") {
                    viewModel.saveExam(id: exam.id, name: name, date: date, note: note)
                    editingExam = nil
                } onCancel: {
                    editingExam = nil
                }
            }
        }
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct ExamCard: View {
    let exam: Exam
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var days: Int { max(exam.daysRemaining(), 0) }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(exam.name)
                    .font(.headline)
                Text(exam.dateValue.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if let note = exam.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            UrgencyBadge(daysRemaining: days)
        }
        .cardStyle()
        .contextMenu {
            Button { onEdit() } label: { Label("編集", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
        }
    }
}

private struct ExamEditorSheet: View {
    @Binding var name: String
    @Binding var date: Date
    @Binding var note: String
    let title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            TextField("テスト名", text: $name)
            DatePicker("日付", selection: $date, displayedComponents: .date)
            TextField("メモ", text: $note, axis: .vertical)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - GoalsScreen

struct GoalsScreen: View {
    @StateObject private var viewModel: GoalsViewModel
    @State private var dailyMinutes = ""
    @State private var weeklyMinutes = ""
    @State private var hasLoadedInitialValues = false
    @State private var showDailyEditor = false
    @State private var showWeeklyEditor = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: GoalsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Daily Goal
                goalCard(
                    title: "1日の目標",
                    icon: "sun.max.fill",
                    goal: viewModel.dailyGoal,
                    currentMinutes: 0,
                    iconColor: AppColors.warning
                ) {
                    showDailyEditor = true
                }

                // Weekly Goal
                goalCard(
                    title: "週間目標",
                    icon: "calendar",
                    goal: viewModel.weeklyGoal,
                    currentMinutes: 0,
                    iconColor: Color(hex: 0x2196F3)
                ) {
                    showWeeklyEditor = true
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("目標")
        .sheet(isPresented: $showDailyEditor) {
            NavigationStack {
                GoalEditorSheet(title: "1日の目標", minutes: $dailyMinutes) {
                    viewModel.updateGoal(type: .daily, targetMinutes: Int(dailyMinutes) ?? 0)
                    showDailyEditor = false
                } onCancel: {
                    showDailyEditor = false
                }
            }
        }
        .sheet(isPresented: $showWeeklyEditor) {
            NavigationStack {
                GoalEditorSheet(title: "週間目標", minutes: $weeklyMinutes) {
                    viewModel.updateGoal(type: .weekly, targetMinutes: Int(weeklyMinutes) ?? 0)
                    showWeeklyEditor = false
                } onCancel: {
                    showWeeklyEditor = false
                }
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            if !hasLoadedInitialValues {
                dailyMinutes = "\(viewModel.dailyGoal?.targetMinutes ?? 0)"
                weeklyMinutes = "\(viewModel.weeklyGoal?.targetMinutes ?? 0)"
                hasLoadedInitialValues = true
            }
        }
    }

    @ViewBuilder
    private func goalCard(title: String, icon: String, goal: Goal?, currentMinutes: Int, iconColor: Color, onEdit: @escaping () -> Void) -> some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
                Spacer()
                Button("変更", action: onEdit)
                    .font(.subheadline.bold())
            }

            if let goal {
                let isComplete = currentMinutes >= goal.targetMinutes && goal.targetMinutes > 0
                VStack(spacing: AppSpacing.md) {
                    ProgressRing(
                        progress: goal.targetMinutes > 0 ? Double(currentMinutes) / Double(goal.targetMinutes) : 0,
                        size: 100,
                        lineWidth: 10,
                        ringColor: isComplete ? AppColors.success : .accentColor
                    )
                    .overlay {
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppColors.success)
                        }
                    }

                    Text("目標: \(goal.targetFormatted)")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    AnimatedProgressBar(
                        value: Double(currentMinutes),
                        total: Double(max(goal.targetMinutes, 1)),
                        height: 8,
                        barColor: isComplete ? AppColors.success : .accentColor
                    )
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "target")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("目標が未設定です")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .cardStyle()
    }
}

private struct GoalEditorSheet: View {
    let title: String
    @Binding var minutes: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("目標時間（分）", text: $minutes)
                    .keyboardType(.numberPad)
            } footer: {
                if let m = Int(minutes), m > 0 {
                    Text("= \(Goal.format(minutes: m))")
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
            }
        }
    }
}

// MARK: - Helpers

private struct OnboardingPage {
    var title: String
    var description: String
    var systemImage: String
    var gradient: [Color]
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
