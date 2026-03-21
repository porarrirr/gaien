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
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        PlanHeaderCardNew(
                            plan: activePlan,
                            totalTargetMinutes: viewModel.totalTargetMinutes,
                            completionRate: viewModel.completionRate
                        )

                        DaySelectorNew(
                            selectedDay: Binding(
                                get: { viewModel.selectedDay ?? .monday },
                                set: { viewModel.selectedDay = $0 }
                            )
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
                    .padding(AppSpacing.md)
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
        .background(AppColors.subtleBackground)
        .navigationTitle("計画")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.activePlan != nil {
                    Button {
                        isShowingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button(role: .destructive) {
                        viewModel.deleteActivePlan()
                    } label: {
                        Image(systemName: "trash")
                    }
                } else {
                    Button {
                        isShowingCreatePlan = true
                    } label: {
                        Image(systemName: "plus")
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

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(plan.name)
                        .font(.title2.bold())
                    Text("\(plan.startDateValue.formatted(date: .abbreviated, time: .omitted)) - \(plan.endDateValue.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                ProgressRing(
                    progress: completionRate,
                    size: 72,
                    lineWidth: 8
                )
            }

            Text("目標: \(totalTargetMinutes / 60)時間\(totalTargetMinutes % 60)分 / 週")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .cardStyle()
    }
}

private struct DaySelectorNew: View {
    @Binding var selectedDay: StudyWeekday

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(StudyWeekday.allCases) { day in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDay = day
                        }
                    } label: {
                        Text(day.japaneseShortTitle)
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedDay == day ? .white : AppColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedDay == day
                                    ? AnyShapeStyle(.tint)
                                    : AnyShapeStyle(AppColors.cardBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .shadow(color: selectedDay == day ? .tint.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DayScheduleSectionNew: View {
    let day: StudyWeekday
    let items: [PlanItemWithSubject]
    let onEdit: (PlanItem) -> Void
    let onDelete: (PlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("\(day.japaneseTitle)")
                    .font(.headline)
                Spacer()
                Text("合計 \(items.reduce(0) { $0 + $1.item.targetMinutes })分")
                    .font(.caption.bold())
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
                .cardStyle()
            } else {
                ForEach(items) { wrapped in
                    HStack(spacing: AppSpacing.md) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: wrapped.subject.color))
                            .frame(width: 4, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(wrapped.subject.name)
                                .font(.subheadline.bold())
                            if let timeSlot = wrapped.item.timeSlot, !timeSlot.isEmpty {
                                Text(timeSlot)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        Spacer()
                        Text("\(wrapped.item.targetMinutes)分")
                            .font(.subheadline.bold())
                            .foregroundStyle(.tint)
                    }
                    .cardStyle()
                    .contextMenu {
                        Button { onEdit(wrapped.item) } label: { Label("編集", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(wrapped.item) } label: { Label("削除", systemImage: "trash") }
                    }
                }
            }
        }
    }
}

private struct CreatePlanSheet: View {
    let subjects: [Subject]
    let onCreate: (String, Date, Date, [PlanItem]) -> Void
    let onCancel: () -> Void
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var draftItems: [DraftPlanItem]

    init(subjects: [Subject], onCreate: @escaping (String, Date, Date, [PlanItem]) -> Void, onCancel: @escaping () -> Void) {
        self.subjects = subjects
        self.onCreate = onCreate
        self.onCancel = onCancel
        _draftItems = State(initialValue: subjects.isEmpty ? [] : [DraftPlanItem(subjectId: subjects.first?.id ?? 0)])
    }

    var body: some View {
        Form {
            TextField("プラン名", text: $name)
            DatePicker("開始日", selection: $startDate, displayedComponents: .date)
            DatePicker("終了日", selection: $endDate, displayedComponents: .date)

            Section("初期項目") {
                ForEach($draftItems) { $item in
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
                Button("項目を追加") {
                    draftItems.append(DraftPlanItem(subjectId: subjects.first?.id ?? 0))
                }
            }
        }
        .navigationTitle("計画を作成")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("作成") {
                    let items = draftItems.compactMap { item -> PlanItem? in
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
                    onCreate(name, startDate, endDate, items)
                }
                .disabled(subjects.isEmpty)
            }
        }
    }
}

private struct PlanItemEditorSheet: View {
    let subjects: [Subject]
    let activePlanId: Int64
    let item: PlanItem?
    let onSave: (PlanItem) -> Void
    let onCancel: () -> Void
    @State private var draft: DraftPlanItem

    init(
        subjects: [Subject],
        activePlanId: Int64,
        item: PlanItem?,
        onSave: @escaping (PlanItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.subjects = subjects
        self.activePlanId = activePlanId
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: DraftPlanItem(item: item, fallbackSubjectId: subjects.first?.id ?? 0))
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
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
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
                .disabled(subjects.isEmpty)
            }
        }
    }
}

private struct DraftPlanItem: Identifiable {
    let id = UUID()
    var subjectId: Int64
    var dayOfWeek: StudyWeekday = .monday
    var targetMinutes = "60"
    var timeSlot = ""

    init(subjectId: Int64) {
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
