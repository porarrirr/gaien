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

private struct CreatePlanSheet: View {
    let subjects: [Subject]
    let onCreate: (String, Date, Date, [PlanItem]) -> Void
    let onCancel: () -> Void
    @State private var name = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var draftItems: [DraftPlanItem]
    @FocusState private var focusedPlanName: Bool

    init(subjects: [Subject], onCreate: @escaping (String, Date, Date, [PlanItem]) -> Void, onCancel: @escaping () -> Void) {
        self.subjects = subjects
        self.onCreate = onCreate
        self.onCancel = onCancel
        _startDate = State(initialValue: Self.defaultStartDate)
        _endDate = State(initialValue: Self.defaultEndDate)
        _draftItems = State(initialValue: Self.initialDraftItems(subjects: subjects))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("新しい週次計画を作成します。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 2)

                planFieldsCard

                VStack(alignment: .leading, spacing: 6) {
                    Text("初期項目")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("計画作成時に登録する初期の項目です。")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, 10)

                draftItemsCard
                addItemButton
                aboutCard
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(hex: 0xF8F9FA).ignoresSafeArea())
        .navigationTitle("計画を作成")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .tint(AppColors.success)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("作成") {
                    onCreate(name, startDate, endDate, planItems)
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.success)
                .disabled(subjects.isEmpty || planItems.isEmpty)
            }
        }
    }

    private var planFieldsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("計画名")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 94, alignment: .leading)
                TextField("例）平日集中プラン", text: $name)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($focusedPlanName)
            }
            .frame(height: 54)
            .padding(.horizontal, 18)

            Divider().background(AppColors.cardBorder)

            dateRow(title: "開始日", date: $startDate)

            Divider().background(AppColors.cardBorder)

            dateRow(title: "終了日", date: $endDate)
        }
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var draftItemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(draftItems.indices), id: \.self) { index in
                draftItemRow(index: index)
                if index < draftItems.count - 1 {
                    Divider().background(AppColors.cardBorder)
                }
            }
        }
        .padding(.vertical, 14)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var addItemButton: some View {
        Button {
            draftItems.append(DraftPlanItem(subjectId: subjects.first?.id ?? 0, ordinal: draftItems.count + 1))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22, weight: .semibold))
                Text("項目を追加")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(AppColors.success)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.plain)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .disabled(subjects.isEmpty)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                Text("について")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(AppColors.success)

            VStack(alignment: .leading, spacing: 10) {
                Text("・ 作成後に各日の予定は編集できます。")
                Text("・ 目標時間は１日の合計目標として扱われます。")
                Text("・ 曜日や時間帯は後から変更できます。")
            }
            .font(.system(size: 14))
            .foregroundStyle(AppColors.textSecondary)
            .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.greenSoft.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func dateRow(title: String, date: Binding<Date>) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 94, alignment: .leading)

            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(AppColors.success)
                .overlay(alignment: .leading) {
                    Text(Self.dateFormatter.string(from: date.wrappedValue))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.success)
                        .allowsHitTesting(false)
                }
        }
        .frame(height: 54)
        .padding(.horizontal, 18)
    }

    private func draftItemRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9BA0A6))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 44, height: 26)
                    .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.success.opacity(0.18), lineWidth: 1)
                    }

                VStack(spacing: 0) {
                    subjectMenuRow(index: index)
                    Divider().background(AppColors.cardBorder)
                    weekdayMenuRow(index: index)
                    Divider().background(AppColors.cardBorder)
                    targetMinutesMenuRow(index: index)
                    Divider().background(AppColors.cardBorder)
                    timeSlotMenuRow(index: index)
                }
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
            }

            Button(role: .destructive) {
                draftItems.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF2D20))
                    .frame(width: 28, height: 34)
            }
            .buttonStyle(.plain)
            .disabled(draftItems.count <= 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func subjectMenuRow(index: Int) -> some View {
        Menu {
            ForEach(subjects) { subject in
                Button {
                    draftItems[index].subjectId = subject.id
                } label: {
                    Label(subject.name, systemImage: draftItems[index].subjectId == subject.id ? "checkmark" : "circle")
                }
            }
        } label: {
            createPlanSelectionRow(
                title: "科目",
                value: selectedSubject(index: index)?.name ?? "科目なし",
                color: selectedSubject(index: index).map { Color(hex: $0.color) } ?? AppColors.textSecondary,
                showsDot: selectedSubject(index: index) != nil
            )
        }
        .buttonStyle(.plain)
        .disabled(subjects.isEmpty)
    }

    private func weekdayMenuRow(index: Int) -> some View {
        Menu {
            ForEach(StudyWeekday.allCases) { day in
                Button(day.japaneseTitle) {
                    draftItems[index].dayOfWeek = day
                }
            }
        } label: {
            createPlanSelectionRow(title: "曜日", value: draftItems[index].dayOfWeek.japaneseTitle)
        }
        .buttonStyle(.plain)
    }

    private func targetMinutesMenuRow(index: Int) -> some View {
        Menu {
            ForEach([30, 45, 60, 90, 120, 150, 180], id: \.self) { minutes in
                Button("\(minutes)") {
                    draftItems[index].targetMinutes = "\(minutes)"
                }
            }
        } label: {
            createPlanSelectionRow(title: "目標時間（分）", value: draftItems[index].targetMinutes)
        }
        .buttonStyle(.plain)
    }

    private func timeSlotMenuRow(index: Int) -> some View {
        Menu {
            ForEach(["未設定", "6:00 - 7:00", "7:00 - 8:00", "19:00 - 20:30", "19:00 - 21:00", "21:00 - 22:00"], id: \.self) { slot in
                Button(slot) {
                    draftItems[index].timeSlot = slot == "未設定" ? "" : slot
                }
            }
        } label: {
            createPlanSelectionRow(title: "時間帯", value: draftItems[index].timeSlot.isEmpty ? "未設定" : draftItems[index].timeSlot)
        }
        .buttonStyle(.plain)
    }

    private func createPlanSelectionRow(title: String, value: String, color: Color = AppColors.success, showsDot: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 8)
            if showsDot {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x8B9098))
        }
        .frame(height: 42)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var planItems: [PlanItem] {
        draftItems.compactMap { item -> PlanItem? in
            guard let minutes = Int(item.targetMinutes), minutes > 0 else { return nil }
            return PlanItem(
                planId: 0,
                subjectId: item.subjectId,
                dayOfWeek: item.dayOfWeek,
                targetMinutes: minutes,
                actualMinutes: 0,
                timeSlot: item.timeSlot.nilIfBlank
            )
        }
    }

    private func selectedSubject(index: Int) -> Subject? {
        subjects.first { $0.id == draftItems[index].subjectId }
    }

    private static func initialDraftItems(subjects: [Subject]) -> [DraftPlanItem] {
        guard let first = subjects.first else { return [] }
        let second = subjects.dropFirst().first ?? first
        return [
            DraftPlanItem(subjectId: first.id, ordinal: 1, dayOfWeek: .monday, targetMinutes: "120", timeSlot: "19:00 - 21:00"),
            DraftPlanItem(subjectId: second.id, ordinal: 2, dayOfWeek: .tuesday, targetMinutes: "90", timeSlot: "19:00 - 20:30")
        ]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 (E)"
        return formatter
    }()

    private static var defaultStartDate: Date {
        makeDate(year: 2026, month: 5, day: 26)
    }

    private static var defaultEndDate: Date {
        makeDate(year: 2026, month: 8, day: 31)
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date()
    }
}

private struct PlanItemEditorSheet: View {
    let subjects: [Subject]
    let activePlanId: Int64
    let item: PlanItem?
    let onSave: (PlanItem) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    @State private var draft: DraftPlanItem

    init(
        subjects: [Subject],
        activePlanId: Int64,
        item: PlanItem?,
        onSave: @escaping (PlanItem) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.subjects = subjects
        self.activePlanId = activePlanId
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _draft = State(initialValue: DraftPlanItem(item: item, fallbackSubjectId: subjects.first?.id ?? 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("計画項目の内容を編集します。")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.top, 20)

                    editorCard

                    inputGuide

                    if item != nil, let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            HStack(spacing: 13) {
                                Image(systemName: "trash")
                                    .font(.system(size: 24, weight: .regular))
                                Text("計画項目を削除")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: 0xFF3B30))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.hidden)
        .tint(AppColors.green)
    }

    private var selectedSubject: Subject? {
        subjects.first { $0.id == draft.subjectId } ?? subjects.first
    }

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 35, height: 5)
                .padding(.top, 20)
                .padding(.bottom, 29)

            ZStack {
                Text(item == nil ? "計画項目を追加" : "計画項目を編集")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(.label))

                HStack {
                    Button("キャンセル", action: onCancel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.green)

                    Spacer()

                    Button("保存", action: saveItem)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.green)
                        .disabled(subjects.isEmpty)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 25)
        .background(Color(.systemBackground))
    }

    private var editorCard: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(subjects) { subject in
                    Button {
                        draft.subjectId = subject.id
                    } label: {
                        Text(subject.name)
                    }
                }
            } label: {
                PlanItemEditorMenuRow(
                    title: "科目",
                    value: selectedSubject?.name ?? "未設定",
                    color: selectedSubject.map { Color(hex: $0.color) }
                )
            }
            .buttonStyle(.plain)

            PlanItemEditorDivider()

            Menu {
                ForEach(StudyWeekday.allCases) { day in
                    Button {
                        draft.dayOfWeek = day
                    } label: {
                        Text(day.japaneseTitle)
                    }
                }
            } label: {
                PlanItemEditorMenuRow(
                    title: "曜日",
                    value: draft.dayOfWeek.japaneseTitle,
                    color: nil
                )
            }
            .buttonStyle(.plain)

            PlanItemEditorDivider()

            HStack(spacing: 12) {
                Text("目標時間 （分）")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(.label))

                Spacer(minLength: 16)

                TextField("", text: $draft.targetMinutes)
                    .keyboardType(.numberPad)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 15)
                    .frame(width: 142, height: 47)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                    }

                Text("分")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .frame(height: 78)

            PlanItemEditorDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("時間帯")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(.label))

                    Spacer(minLength: 16)

                    TextField("", text: $draft.timeSlot)
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 15)
                        .frame(width: 210, height: 47)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                        }
                }

                Text("例：19:00-20:30")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.leading, 190)
            }
            .frame(height: 103)
        }
        .padding(.horizontal, 18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
        }
    }

    private var inputGuide: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 14) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.green)
                Text("入力のガイド")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }

            VStack(alignment: .leading, spacing: 15) {
                Text("・ 目標時間は 1 分以上で入力してください。")
                Text("・ 時間帯は 24 時間形式で入力してください。")
                Text("   例：19:00-20:30、07:30-08:15")
            }
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Color(.secondaryLabel))
            .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.greenSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.green.opacity(0.16), lineWidth: 1)
        }
    }

    private func saveItem() {
        guard let minutes = Int(draft.targetMinutes), minutes > 0 else { return }
        onSave(
            PlanItem(
                id: item?.id ?? 0,
                planId: item?.planId ?? activePlanId,
                subjectId: draft.subjectId,
                dayOfWeek: draft.dayOfWeek,
                targetMinutes: minutes,
                actualMinutes: item?.actualMinutes ?? 0,
                timeSlot: draft.timeSlot.nilIfBlank,
                createdAt: item?.createdAt ?? Date().epochMilliseconds,
                updatedAt: Date().epochMilliseconds
            )
        )
    }
}

private struct PlanItemEditorMenuRow: View {
    let title: String
    let value: String
    let color: Color?

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.label))

            Spacer(minLength: 16)

            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
            }

            Text(value)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.label))

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .frame(height: 76)
        .contentShape(Rectangle())
    }
}

private struct PlanItemEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xE4E5E8))
            .frame(height: 1)
    }
}

private struct DraftPlanItem: Identifiable {
    let id = UUID()
    var subjectId: Int64
    var dayOfWeek: StudyWeekday = .monday
    var targetMinutes = "60"
    var timeSlot = ""

    init(subjectId: Int64, ordinal: Int = 1, dayOfWeek: StudyWeekday? = nil, targetMinutes: String? = nil, timeSlot: String? = nil) {
        self.subjectId = subjectId
        if let dayOfWeek {
            self.dayOfWeek = dayOfWeek
        } else {
            self.dayOfWeek = ordinal == 2 ? .tuesday : .monday
        }
        self.targetMinutes = targetMinutes ?? (ordinal == 2 ? "90" : "120")
        self.timeSlot = timeSlot ?? (ordinal == 2 ? "19:00 - 20:30" : "19:00 - 21:00")
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
