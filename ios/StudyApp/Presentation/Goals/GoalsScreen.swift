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
            VStack(spacing: AppSpacing.md) {
                dailyGoalsCard

                goalCard(
                    title: "週間目標",
                    icon: "calendar",
                    goal: viewModel.weeklyGoal,
                    currentMinutes: viewModel.weeklyStudyMinutes,
                    iconColor: Color(hex: 0x2196F3)
                ) {
                    showWeeklyEditor = true
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("目標")
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

    private var dailyGoalsCard: some View {
        let todayGoal = viewModel.dailyGoals[viewModel.todayWeekday]
        let todayTarget = todayGoal?.targetMinutes ?? 0
        let todayProgress = todayTarget > 0 ? Double(viewModel.todayStudyMinutes) / Double(todayTarget) : 0

        return VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.warning)
                Text("曜日別の1日目標")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    ProgressRing(
                        progress: todayProgress,
                        size: 72,
                        lineWidth: 8,
                        ringColor: .accentColor
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.todayWeekday.japaneseTitle)
                            .font(.headline)
                        Text("\(viewModel.todayStudyMinutes)分 / \(todayTarget)分")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                }

                ForEach(StudyWeekday.allCases) { day in
                    let goal = viewModel.dailyGoals[day]
                    let isToday = day == viewModel.todayWeekday
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.japaneseTitle)
                                .font(.subheadline.weight(isToday ? .bold : .medium))
                            Text(goal?.targetFormatted ?? "未設定")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Button(goal == nil ? "設定" : "編集") {
                            editingDayMinutes = "\(goal?.targetMinutes ?? 60)"
                            editingDay = day
                        }
                        .font(.subheadline.bold())
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isToday ? Color.accentColor.opacity(0.12) : AppColors.cardBackground)
                    )
                }
            }
        }
        .cardStyle()
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
