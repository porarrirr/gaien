import Foundation
import SwiftUI

// MARK: - GoalsScreen

struct GoalsScreen: View {
    @StateObject private var viewModel: GoalsViewModel
    @State private var weeklyMinutes = ""
    @State private var showWeeklyEditor = false
    @State private var editingDay: StudyWeekday?
    @State private var editingDayMinutes = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: GoalsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                todayGoalCard
                weekdayGoalsList
                weeklyGoalCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Color(hex: 0xF8F9FB).ignoresSafeArea())
        .navigationTitle("目標")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingDay) { day in
            NavigationStack {
                GoalEditorSheet(title: "\(day.japaneseTitle)の目標", minutes: $editingDayMinutes) {
                    viewModel.updateDailyGoal(dayOfWeek: day, targetMinutes: parsedMinutes(editingDayMinutes) ?? 0)
                    editingDay = nil
                } onCancel: {
                    editingDay = nil
                }
            }
        }
        .sheet(isPresented: $showWeeklyEditor) {
            NavigationStack {
                GoalEditorSheet(title: "週間目標", minutes: $weeklyMinutes) {
                    viewModel.updateWeeklyGoal(targetMinutes: parsedMinutes(weeklyMinutes) ?? 0)
                    showWeeklyEditor = false
                } onCancel: {
                    showWeeklyEditor = false
                }
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            weeklyMinutes = "\(viewModel.weeklyGoal?.targetMinutes ?? 0)"
        }
    }

    private var orderedWeekdays: [StudyWeekday] {
        [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    }

    private var todayGoalCard: some View {
        let todayGoal = viewModel.dailyGoals[viewModel.todayWeekday]
        let todayTarget = todayGoal?.targetMinutes ?? 0
        let todayProgress = todayTarget > 0 ? Double(viewModel.todayStudyMinutes) / Double(todayTarget) : 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF6A000))
                    .frame(width: 40, height: 40)
                Text("曜日別の1日目標")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }

            HStack(spacing: 22) {
                goalRing(progress: todayProgress, size: 112, lineWidth: 13)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.todayWeekday.japaneseTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppColors.success)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.todayStudyMinutes)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .monospacedDigit()
                        Text("分 / \(todayTarget)分")
                            .font(.system(size: 27, weight: .regular))
                            .foregroundStyle(Color(hex: 0x2F3138))
                    }
                    Text("今日の進捗")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .goalSurface(horizontalPadding: 22, verticalPadding: 20)
    }

    private var weekdayGoalsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedWeekdays.enumerated()), id: \.element.id) { index, day in
                let goal = viewModel.dailyGoals[day]
                let isToday = day == viewModel.todayWeekday

                weekdayGoalRow(day: day, goal: goal, isToday: isToday)

                if index < orderedWeekdays.count - 1 {
                    Divider()
                        .background(Color(hex: 0xE4E6EA))
                }
            }
        }
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func weekdayGoalRow(day: StudyWeekday, goal: Goal?, isToday: Bool) -> some View {
        HStack(spacing: 8) {
            Text(day.japaneseTitle)
                .font(.system(size: 22, weight: isToday ? .bold : .regular))
                .foregroundStyle(weekdayColor(day, isToday: isToday))
                .frame(width: 104, alignment: .leading)

            Text(goal?.targetFormatted ?? "未設定")
                .font(.system(size: 22, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? AppColors.success : goal == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(goal == nil ? "設定" : "編集") {
                editingDayMinutes = "\(goal?.targetMinutes ?? 60)"
                editingDay = day
            }
            .buttonStyle(.plain)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(isToday ? .white : AppColors.success)
            .frame(width: 56, height: 32)
            .background(isToday ? AppColors.success : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.success, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(isToday ? AppColors.greenSoft : AppColors.cardBackground)
    }

    private var weeklyGoalCard: some View {
        let goal = viewModel.weeklyGoal
        let target = goal?.targetMinutes ?? 0
        let progress = target > 0 ? Double(viewModel.weeklyStudyMinutes) / Double(target) : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 40, height: 40)
                Text("週間目標")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }

            HStack(alignment: .center, spacing: 14) {
                goalRing(progress: progress, size: 106, lineWidth: 13)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("目標:")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(target > 0 ? Goal.format(minutes: target) : "未設定")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Goal.format(minutes: viewModel.weeklyStudyMinutes))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("/ \(target > 0 ? Goal.format(minutes: target) : "未設定")")
                            .font(.system(size: 23, weight: .regular))
                            .foregroundStyle(Color(hex: 0x2F3138))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: 0xE0E0E0))
                            Capsule()
                                .fill(AppColors.success)
                                .frame(width: geometry.size.width * min(max(progress, 0), 1))
                        }
                    }
                    .frame(height: 8)
                    .frame(maxWidth: 136)

                    Text("今週の進捗")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 0)

                Button("変更") {
                    showWeeklyEditor = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.success)
                .frame(width: 56, height: 32)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.success, lineWidth: 1.5)
                }
            }
        }
        .goalSurface(horizontalPadding: 22, verticalPadding: 18)
    }

    private func goalRing(progress: Double, size: CGFloat, lineWidth: CGFloat) -> some View {
        let clamped = min(max(progress, 0), 1)

        ProgressRing(
            progress: clamped,
            size: size,
            lineWidth: lineWidth,
            ringColor: AppColors.success,
            trackColor: Color(hex: 0xE9E9E9),
            showPercentage: false
        )
        .overlay {
            VStack(spacing: 3) {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppColors.success)
                    .monospacedDigit()
                Text("達成")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func weekdayColor(_ day: StudyWeekday, isToday: Bool) -> Color {
        if isToday { return AppColors.success }
        switch day {
        case .sunday:
            return AppColors.danger
        case .saturday:
            return AppColors.blue
        default:
            return AppColors.textPrimary
        }
    }

    private func parsedMinutes(_ value: String) -> Int? {
        let normalized = value
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard let normalized, !normalized.isEmpty else {
            return nil
        }

        return Int(normalized)
    }
}

private struct GoalSurfaceModifier: ViewModifier {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
            }
    }
}

private extension View {
    func goalSurface(horizontalPadding: CGFloat, verticalPadding: CGFloat) -> some View {
        modifier(GoalSurfaceModifier(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }
}

private struct GoalEditorSheet: View {
    let title: String
    @Binding var minutes: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    StrictSectionTitle(title: title, icon: "target")
                    TextField("目標時間（分）", text: $minutes)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    if let m = Int(minutes), m > 0 {
                        MetricPill(text: Goal.format(minutes: m), color: AppColors.success, systemImage: "clock.fill")
                    }
                }
                .strictCard()
            }
            .padding(StrictUI.screenPadding)
        }
        .strictScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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
