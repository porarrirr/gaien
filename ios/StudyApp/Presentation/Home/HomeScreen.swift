import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
                heroSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                todayReviewSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                weeklyGoalSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                timetableSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                todaySessionsSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                upcomingExamsSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                recentMaterialsSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                quickNavSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = viewModel.app.logger.exportText()
                    #endif
                    viewModel.app.logger.log(category: .app, message: "Diagnostic logs copied from Home toolbar")
                } label: {
                    Label("診断ログをコピー", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("今日の学習", systemImage: "clock.badge.checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(AppColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.homeData.todayStudyMinutes)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppColors.textPrimary)
                        Text("分")
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    if let goal = viewModel.homeData.todayGoal {
                        Text("目標 \(goal.targetFormatted)")
                            .font(.caption.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                ProgressRing(
                    progress: todayProgress,
                    size: 82,
                    lineWidth: 8,
                    ringColor: AppColors.success,
                    trackColor: AppColors.greenSoft,
                    showPercentage: false
                )
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(todayProgressPercent)%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("達成")
                            .font(.caption2.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            if dailyGoalMinutes > 0 {
                AnimatedProgressBar(
                    value: Double(viewModel.homeData.todayStudyMinutes),
                    total: Double(dailyGoalMinutes),
                    height: 8,
                    barColor: AppColors.success,
                    trackColor: AppColors.greenSoft
                )
            }
        }
        .cardStyle()
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
                        height: 8,
                        barColor: AppColors.success,
                        trackColor: AppColors.greenSoft
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

    private var todayReviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "今日の復習", icon: "arrow.clockwise.circle.fill")
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if viewModel.homeData.todayReviewProblems.isEmpty {
                    Text("今日の復習はありません")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(viewModel.homeData.todayReviewProblems.prefix(5)) { problem in
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(AppColors.success)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text("\(problem.problemNumber)")
                                        .font(.caption2.bold())
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(problem.materialName)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text(reviewProblemSubtitle(problem))
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(reviewDueText(problem.nextReviewDate))
                                .font(.caption.bold())
                                .foregroundStyle(.tint)
                        }
                        if problem.id != viewModel.homeData.todayReviewProblems.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .cardStyle()
        }
    }

    private var timetableSection: some View {
        Group {
            if let lesson = viewModel.homeData.timetableLesson {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: lesson.statusTitle, icon: lesson.isCurrent ? "play.circle.fill" : "calendar.badge.clock")
                    HStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(.tint)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lesson.entry.subjectName)
                                .font(.headline)
                            if let course = lesson.entry.courseName, !course.isEmpty {
                                Text(course)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            HStack(spacing: AppSpacing.sm) {
                                Text("\(lesson.dayOfWeek.japaneseShortTitle) \(lesson.period.name) \(lesson.period.timeRangeText)")
                                if let room = lesson.entry.roomName, !room.isEmpty {
                                    Text("教室 \(room)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                    }
                    .cardStyle()
                }
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
                QuickNavButton(icon: "tablecells", label: "時間割") {
                    TimetableScreen(app: viewModel.app)
                }
                QuickNavButton(icon: "gearshape.fill", label: "設定") {
                    SettingsScreen(app: viewModel.app)
                }
            }
        }
    }

    private func reviewProblemSubtitle(_ problem: TodayReviewProblem) -> String {
        let subject = problem.subjectName.isEmpty ? "科目未設定" : problem.subjectName
        return "\(subject) ・ \(problem.problemNumber)問目 ・ 連続\(problem.consecutiveCorrectCount)回 / 不正解\(problem.wrongCount)回"
    }

    private func reviewDueText(_ epochMilliseconds: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date(epochMilliseconds: epochMilliseconds))
    }
}
