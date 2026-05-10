import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - HomeScreen

struct HomeScreen: View {
    @StateObject private var viewModel: HomeViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(app: app))
    }

    private var dailyGoalMinutes: Int {
        viewModel.homeData.todayGoal?.targetMinutes ?? 120
    }

    private var todayProgress: Double {
        let target = max(dailyGoalMinutes, 1)
        return min(Double(viewModel.homeData.todayStudyMinutes) / Double(target), 1)
    }

    private var todayProgressPercent: Int {
        Int(todayProgress * 100)
    }

    private var weeklyGoalMinutes: Int {
        viewModel.homeData.weeklyGoal?.targetMinutes ?? 600
    }

    private var weeklyProgress: Double {
        let target = max(weeklyGoalMinutes, 1)
        return min(Double(viewModel.homeData.weeklyStudyMinutes) / Double(target), 1)
    }

    private var weeklyProgressPercent: Int {
        Int(weeklyProgress * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                todayStudyCard
                reviewCard
                weeklyGoalCard
                timetableCards
                sessionsAndExamsGrid
                recentMaterialsCard
                quickNavCard
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 14)
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
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.success)
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var todayStudyCard: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Label {
                    Text("今日の学習")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.success)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(viewModel.homeData.todayStudyMinutes)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                    Text("分")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Text("目標 \(Goal.format(minutes: dailyGoalMinutes))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 8)

            ProgressRing(
                progress: todayProgress,
                size: 90,
                lineWidth: 8,
                ringColor: AppColors.success,
                trackColor: AppColors.cardBorder.opacity(0.65),
                showPercentage: false
            )
            .overlay {
                VStack(spacing: 2) {
                    Text("\(todayProgressPercent)%")
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                    Text("達成率")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .homeCard(padding: 16)
    }

    private var reviewCard: some View {
        NavigationLink {
            TodayReviewListScreen(
                problems: viewModel.homeData.todayReviewProblems,
                dueText: reviewDueRelativeText
            )
        } label: {
            VStack(spacing: 0) {
                cardHeader(title: "今日の復習", icon: "arrow.clockwise", countText: "\(viewModel.homeData.todayReviewProblems.count)件")
                    .padding(.bottom, 8)

                if viewModel.homeData.todayReviewProblems.isEmpty {
                    Text("今日の復習はありません")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                } else {
                    ForEach(Array(viewModel.homeData.todayReviewProblems.prefix(3).enumerated()), id: \.element.id) { index, problem in
                        ReviewRow(
                            problem: problem,
                            dueText: reviewDueRelativeText(problem.nextReviewDate),
                            color: reviewColor(at: index)
                        )
                        if index < min(viewModel.homeData.todayReviewProblems.count, 3) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .homeCard(padding: 10)
        .buttonStyle(.plain)
    }

    private var weeklyGoalCard: some View {
        NavigationLink {
            GoalsScreen(app: viewModel.app)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                cardHeader(
                    title: "週間目標",
                    icon: "target",
                    countText: "\(Goal.format(minutes: viewModel.homeData.weeklyStudyMinutes)) / \(Goal.format(minutes: weeklyGoalMinutes))"
                )

                Text("学習時間の目標 \(Goal.format(minutes: weeklyGoalMinutes))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 12) {
                    AnimatedProgressBar(
                        value: Double(viewModel.homeData.weeklyStudyMinutes),
                        total: Double(max(weeklyGoalMinutes, 1)),
                        height: 7,
                        barColor: AppColors.success,
                        trackColor: AppColors.cardBorder.opacity(0.75)
                    )
                    Text("\(weeklyProgressPercent)%")
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 46, alignment: .trailing)
                }
            }
        }
        .homeCard(padding: 12)
        .buttonStyle(.plain)
    }

    private var timetableCards: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            NavigationLink {
                TimetableScreen(app: viewModel.app)
            } label: {
                if let lesson = viewModel.homeData.timetableLesson {
                    LessonCard(eyebrow: "現在の授業", lesson: lesson, color: AppColors.success)
                } else {
                    EmptyLessonCard(eyebrow: "現在の授業", message: "現在の授業はありません", color: AppColors.success)
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                TimetableScreen(app: viewModel.app)
            } label: {
                if let lesson = viewModel.homeData.upcomingTimetableLesson {
                    LessonCard(eyebrow: "次の授業", lesson: lesson, color: AppColors.blue)
                } else {
                    EmptyLessonCard(eyebrow: "次の授業", message: "登録された次の授業はありません", color: AppColors.blue)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var sessionsAndExamsGrid: some View {
        VStack(spacing: 8) {
            sessionsCard
            examsCard
        }
    }

    private var sessionsCard: some View {
        NavigationLink {
            HistoryScreen(app: viewModel.app)
        } label: {
            VStack(spacing: 0) {
                cardHeader(title: "今日のセッション", icon: "clock", countText: "\(viewModel.homeData.todaySessions.count)件")
                    .padding(.bottom, 8)

                if viewModel.homeData.todaySessions.isEmpty {
                    emptyCompactText("セッションはまだありません")
                } else {
                    ForEach(Array(viewModel.homeData.todaySessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                        SessionRow(session: session, color: sessionColor(at: index))
                        if index < min(viewModel.homeData.todaySessions.count, 3) - 1 {
                            Divider()
                        }
                    }
                }

                footerLink("すべてのセッションを表示")
            }
        }
        .homeCard(padding: 10)
        .buttonStyle(.plain)
    }

    private var examsCard: some View {
        NavigationLink {
            ExamsScreen(app: viewModel.app)
        } label: {
            VStack(spacing: 0) {
                cardHeader(title: "今後のテスト", icon: "clipboard", countText: "\(viewModel.homeData.upcomingExams.count)件")
                    .padding(.bottom, 8)

                if viewModel.homeData.upcomingExams.isEmpty {
                    emptyCompactText("予定されたテストはありません")
                } else {
                    ForEach(Array(viewModel.homeData.upcomingExams.prefix(4).enumerated()), id: \.element.id) { index, exam in
                        ExamRow(exam: exam)
                        if index < min(viewModel.homeData.upcomingExams.count, 4) - 1 {
                            Divider()
                        }
                    }
                }

                footerLink("すべてのテストを表示")
            }
        }
        .homeCard(padding: 10)
        .buttonStyle(.plain)
    }

    private var recentMaterialsCard: some View {
        NavigationLink {
            MaterialsScreen(app: viewModel.app)
        } label: {
            VStack(spacing: 10) {
                cardHeader(title: "最近使った教材", icon: "book", countText: "\(viewModel.recentMaterials.count)件")

                if viewModel.recentMaterials.isEmpty {
                    emptyCompactText("最近使った教材はありません")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(viewModel.recentMaterials.prefix(6).enumerated()), id: \.offset) { _, pair in
                                MaterialMiniCard(material: pair.0, subject: pair.1)
                                    .frame(width: 138)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .homeCard(padding: 10)
        .buttonStyle(.plain)
    }

    private var quickNavCard: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            HomeNavButton(icon: "clipboard", label: "試験") { ExamsScreen(app: viewModel.app) }
            HomeNavButton(icon: "flask", label: "科目") { SubjectsScreen(app: viewModel.app) }
            HomeNavButton(icon: "clock.arrow.circlepath", label: "履歴") { HistoryScreen(app: viewModel.app) }
            HomeNavButton(icon: "target", label: "目標") { GoalsScreen(app: viewModel.app) }
            HomeNavButton(icon: "calendar", label: "計画") { PlanScreen(app: viewModel.app) }
            HomeNavButton(icon: "tablecells", label: "時間割") { TimetableScreen(app: viewModel.app) }
            HomeNavButton(icon: "gearshape", label: "設定") { SettingsScreen(app: viewModel.app) }
        }
        .homeCard(padding: 16)
    }

    private func cardHeader(title: String, icon: String, countText: String? = nil) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.success)
                .frame(width: 22)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .layoutPriority(1)
            Spacer()
            if let countText {
                Text(countText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(countText.contains("/") ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func footerLink(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.success)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .padding(.top, 10)
        .frame(minHeight: 38)
    }

    private func emptyCompactText(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .center)
    }

    private func reviewColor(at index: Int) -> Color {
        [AppColors.success, AppColors.orange, AppColors.blue][index % 3]
    }

    private func sessionColor(at index: Int) -> Color {
        [AppColors.blue, AppColors.danger, AppColors.orange][index % 3]
    }

    private func reviewDueRelativeText(_ epochMilliseconds: Int64) -> String {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: Date(epochMilliseconds: epochMilliseconds))
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days <= 0 { return "今日まで" }
        if days == 1 { return "明日まで" }
        return "\(days)日後"
    }
}

private struct ReviewRow: View {
    let problem: TodayReviewProblem
    let dueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 42, height: 42)
                .overlay {
                    Text("\(problem.problemNumber)")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.65)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(problem.materialName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text("\(problem.subjectName.isEmpty ? "科目未設定" : problem.subjectName)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(dueText)
                .font(.caption.weight(.bold))
                .foregroundStyle(dueText == "今日まで" ? AppColors.danger : (dueText == "明日まで" ? AppColors.orange : AppColors.textPrimary))
                .frame(width: 50, alignment: .center)

            ReviewMetric(title: "連続正解", value: problem.consecutiveCorrectCount, color: AppColors.success)
            ReviewMetric(title: "連続不正解", value: problem.wrongCount, color: AppColors.danger)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(minHeight: 52)
    }
}

private struct ReviewMetric: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text("問")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 58)
    }
}

private struct LessonCard: View {
    let eyebrow: String
    let lesson: TimetableLesson
    let color: Color

    private var subtitle: String {
        lesson.entry.courseName?.nilIfBlank ?? "講座名なし"
    }

    private var room: String {
        lesson.entry.roomName?.nilIfBlank ?? "教室未設定"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(lesson.entry.subjectName.isEmpty ? "授業名未設定" : lesson.entry.subjectName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    iconText("calendar", lesson.dayOfWeek.japaneseTitle)
                    iconText("clock", lesson.period.name)
                }
                HStack(spacing: 9) {
                    iconText("clock", lesson.period.timeRangeText)
                    iconText("mappin.and.ellipse", room)
                }
            }
        }
        .homeCard(padding: 12)
    }

    private func iconText(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct EmptyLessonCard: View {
    let eyebrow: String
    let message: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Spacer(minLength: 0)
            Text(message)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("時間割で登録してください")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary.opacity(0.82))
            Spacer(minLength: 0)
        }
        .frame(minHeight: 112)
        .homeCard(padding: 12)
    }
}

private struct TodayReviewListScreen: View {
    let problems: [TodayReviewProblem]
    let dueText: (Int64) -> String

    var body: some View {
        List {
            if problems.isEmpty {
                Text("今日の復習はありません")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(Array(problems.enumerated()), id: \.element.id) { index, problem in
                    TodayReviewListRow(
                        problem: problem,
                        dueText: dueText(problem.nextReviewDate),
                        color: [AppColors.success, AppColors.orange, AppColors.blue][index % 3]
                    )
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("今日の復習")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TodayReviewListRow: View {
    let problem: TodayReviewProblem
    let dueText: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 46, height: 46)
                .overlay {
                    Text("\(problem.problemNumber)")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.65)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(problem.materialName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(3)
                Text(problem.subjectName.isEmpty ? "科目未設定" : problem.subjectName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 12) {
                    Text(dueText)
                        .foregroundStyle(dueText == "今日まで" ? AppColors.danger : AppColors.orange)
                    Text("連続正解 \(problem.consecutiveCorrectCount)問")
                        .foregroundStyle(AppColors.success)
                    Text("連続不正解 \(problem.wrongCount)問")
                        .foregroundStyle(AppColors.danger)
                }
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
    }
}

private struct SessionRow: View {
    let session: TodaySession
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.subjectName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(session.materialName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.duration / 60_000))分")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                Text(timeRangeText(start: session.startTime, duration: session.duration))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 44)
    }

    private func timeRangeText(start: Int64, duration: Int64) -> String {
        let formatter = StudyFormatters.clockLoose
        let startDate = Date(epochMilliseconds: start)
        let endDate = Date(epochMilliseconds: start + duration)
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

private struct ExamRow: View {
    let exam: Exam

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exam.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(examDateText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 6)
            Text(remainingText)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppColors.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppColors.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(AppColors.orange, lineWidth: 1)
                }
        }
        .frame(minHeight: 44)
    }

    private var examDateText: String {
        StudyFormatters.shortDateWithWeekday.string(from: exam.dateValue)
    }

    private var remainingText: String {
        let days = max(exam.daysRemaining(), 0)
        return days == 0 ? "今日" : "あと\(days)日"
    }
}

private struct MaterialMiniCard: View {
    let material: Material
    let subject: Subject

    private var color: Color {
        Color(hex: material.color ?? subject.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                Text(subject.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }

            Text(material.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)

            HStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.cardBorder)
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * material.progress)
                    }
                }
                .frame(height: 5)

                Text("\(material.progressPercent)%")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(8)
        .frame(minHeight: 72)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct HomeNavButton<Destination: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppColors.success)
                    .frame(height: 26)
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func homeCard(padding: CGFloat) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}
