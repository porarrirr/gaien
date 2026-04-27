import Foundation
import SwiftUI

// MARK: - HomeScreen

struct HomeScreen: View {
    @StateObject private var viewModel: HomeViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(app: app))
    }

    private var dailyGoalMinutes: Int {
        viewModel.homeData.todayGoal?.targetMinutes ?? 60
    }

    private var todayProgress: Double {
        let target = max(dailyGoalMinutes, 1)
        return Double(viewModel.homeData.todayStudyMinutes) / Double(target)
    }

    private var todayProgressPercent: Int {
        Int(todayProgress * 100)
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
                    if let goal = viewModel.homeData.todayGoal {
                        Text("目標 \(goal.targetFormatted)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.8))
                    }
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
                    Text("\(todayProgressPercent)%")
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
