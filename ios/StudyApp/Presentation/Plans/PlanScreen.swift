import SwiftUI

struct PlanScreen: View {
    @StateObject private var viewModel: PlanViewModel
    @State private var isShowingCreatePlan = false
    @State private var isShowingAddItem = false
    @State private var editingItem: PlanItem?

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: PlanViewModel(app: app))
    }

    var body: some View {
        Group {
            if let activePlan = viewModel.activePlan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PlanHeaderCardNew(
                            plan: activePlan,
                            totalTargetMinutes: viewModel.totalTargetMinutes,
                            completionRate: viewModel.completionRate
                        )

                        DaySelectorNew(
                            selectedDay: Binding(
                                get: { viewModel.selectedDay ?? .monday },
                                set: { viewModel.selectedDay = $0 }
                            ),
                            weekStartDate: activePlan.startDateValue
                        )

                        let selectedDay = viewModel.selectedDay ?? .monday
                        DayScheduleSectionNew(
                            day: selectedDay,
                            items: viewModel.weeklySchedule[selectedDay] ?? [],
                            onEdit: { item in
                                editingItem = item
                            },
                            onDelete: { item in
                                viewModel.deletePlanItem(item)
                            }
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                }
            } else {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "学習計画がありません",
                    description: "1週間の学習計画を作成して、Android と同じ計画運用フローにそろえます。",
                    buttonTitle: "計画を作成",
                    onAction: { isShowingCreatePlan = true }
                )
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("計画")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.success)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.activePlan != nil {
                    Button {
                        isShowingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .regular))
                    }

                    Button(role: .destructive) {
                        viewModel.deleteActivePlan()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(AppColors.success)
                    }
                } else {
                    Button {
                        isShowingCreatePlan = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .regular))
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCreatePlan) {
            NavigationStack {
                CreatePlanSheet(
                    subjects: viewModel.subjects,
                    onCreate: { name, startDate, endDate, items in
                        viewModel.createPlan(name: name, startDate: startDate, endDate: endDate, items: items)
                        isShowingCreatePlan = false
                    },
                    onCancel: {
                        isShowingCreatePlan = false
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            NavigationStack {
                PlanItemEditorSheet(
                    subjects: viewModel.subjects,
                    activePlanId: viewModel.activePlan?.id ?? 0,
                    item: nil,
                    onSave: { item in
                        viewModel.savePlanItem(item)
                        isShowingAddItem = false
                    },
                    onDelete: nil,
                    onCancel: {
                        isShowingAddItem = false
                    }
                )
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                PlanItemEditorSheet(
                    subjects: viewModel.subjects,
                    activePlanId: item.planId,
                    item: item,
                    onSave: { updated in
                        viewModel.savePlanItem(updated)
                        editingItem = nil
                    },
                    onDelete: {
                        viewModel.deletePlanItem(item)
                        editingItem = nil
                    },
                    onCancel: {
                        editingItem = nil
                    }
                )
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }
}

private struct PlanHeaderCardNew: View {
    let plan: StudyPlan
    let totalTargetMinutes: Int
    let completionRate: Double
    private var currentMinutes: Int { Int(Double(totalTargetMinutes) * completionRate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "calendar")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x42C857), AppColors.success],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 7) {
                        Text(plan.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(dateRangeText)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                ProgressRing(
                    progress: completionRate,
                    size: 112,
                    lineWidth: 14,
                    ringColor: AppColors.success,
                    trackColor: Color(hex: 0xE5E5E8),
                    showPercentage: false
                )
                .overlay {
                    VStack(spacing: 2) {
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.success)
                        Text(minutesText(currentMinutes))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("/ \(minutesText(totalTargetMinutes))")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("目標:")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                Text(minutesText(totalTargetMinutes))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.success)
                Text("/ 週")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .planSurface(cornerRadius: 16)
    }

    private var dateRangeText: String {
        "\(dateText(plan.startDateValue)) 〜 \(dateText(plan.endDateValue))"
    }

    private func dateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = StudyWeekday.from(calendarWeekday: calendar.component(.weekday, from: date)).japaneseShortTitle
        return "\(month)月\(day)日 (\(weekday))"
    }

    private func minutesText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 { return "\(remainingMinutes)分" }
        if remainingMinutes == 0 { return "\(hours)時間" }
        return "\(hours)時間\(remainingMinutes)分"
    }
}

private struct DaySelectorNew: View {
    @Binding var selectedDay: StudyWeekday
    let weekStartDate: Date

    private let displayDays: [StudyWeekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(displayDays.enumerated()), id: \.element.id) { index, day in
                let isSelected = selectedDay == day

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(day.japaneseShortTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(isSelected ? AppColors.success : Color.clear, in: Circle())
                        Text("\(weekDateNumber(offset: index))")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? AppColors.success : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .planSurface(cornerRadius: 14)
    }

    private func weekDateNumber(offset: Int) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: weekStartDate) - 1
        let start = calendar.date(byAdding: .day, value: -weekday, to: weekStartDate) ?? weekStartDate
        let date = calendar.date(byAdding: .day, value: offset, to: start) ?? weekStartDate
        return calendar.component(.day, from: date)
    }
}

private struct DayScheduleSectionNew: View {
    let day: StudyWeekday
    let items: [PlanItemWithSubject]
    let onEdit: (PlanItem) -> Void
    let onDelete: (PlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(day.japaneseTitle)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("合計: \(items.reduce(0) { $0 + $1.item.targetMinutes })分")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
            }

            if items.isEmpty {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(.tertiary)
                    Text("予定なし")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .strictCard()
            } else {
                ForEach(items) { wrapped in
                    PlanScheduleRow(wrapped: wrapped, onEdit: onEdit, onDelete: onDelete)
                    .contextMenu {
                        Button { onEdit(wrapped.item) } label: { Label("編集", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(wrapped.item) } label: { Label("削除", systemImage: "trash") }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF8F9FA), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xEAECF0), lineWidth: 1)
        }
    }
}

private struct PlanScheduleRow: View {
    let wrapped: PlanItemWithSubject
    let onEdit: (PlanItem) -> Void
    let onDelete: (PlanItem) -> Void

    private var subjectColor: Color {
        Color(hex: wrapped.subject.color)
    }

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(subjectColor)
                .frame(width: 7, height: 118)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ColorDot(color: subjectColor, size: 20)
                    Text(wrapped.subject.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Label {
                    Text(timeText)
                        .font(.system(size: 18, weight: .regular))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.vertical, 20)

            Spacer(minLength: 12)

            Text("\(wrapped.item.targetMinutes)分")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()

            Menu {
                Button { onEdit(wrapped.item) } label: { Label("編集", systemImage: "pencil") }
                Button(role: .destructive) { onDelete(wrapped.item) } label: { Label("削除", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8B9099))
                    .rotationEffect(.degrees(90))
                    .frame(width: 34, height: 58)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 118)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xE3E5EA), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var timeText: String {
        guard let timeSlot = wrapped.item.timeSlot, !timeSlot.isEmpty else { return "時間未設定" }
        return timeSlot
    }
}

private struct PlanSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
            }
    }
}

private extension View {
    func planSurface(cornerRadius: CGFloat) -> some View {
        modifier(PlanSurfaceModifier(cornerRadius: cornerRadius))
    }
}

