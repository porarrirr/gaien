import SwiftUI

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
                    Text(StudyFormatters.yearMonthDayWithWeekdayHalf.string(from: date.wrappedValue))
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


struct DraftPlanItem: Identifiable {
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
