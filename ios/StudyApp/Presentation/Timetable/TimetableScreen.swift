import SwiftUI

struct TimetableScreen: View {
    @StateObject private var viewModel: TimetableViewModel
    @State private var isShowingPeriodSettings = false
    @State private var isShowingTermEditor = false
    @State private var isCreatingTerm = false
    @State private var editorContext: TimetableEditorContext?
    @State private var reviewEditorContext: TimetableReviewOccurrence?

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timetableHeader
                    .padding(.horizontal, AppSpacing.md)

                termOverview
                    .padding(.horizontal, AppSpacing.md)

                reviewCalendar
                    .padding(.horizontal, AppSpacing.md)

                selectedDateLessons
                    .padding(.horizontal, AppSpacing.md)

                timetableGrid
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("時間割")
        .toolbar {
            Button {
                isCreatingTerm = true
                isShowingTermEditor = true
            } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .accessibilityLabel("学期設定")

            Button {
                isShowingPeriodSettings = true
            } label: {
                Image(systemName: "clock.badge")
            }
            .accessibilityLabel("時限設定")
        }
        .sheet(isPresented: $isShowingPeriodSettings) {
            NavigationStack {
                TimetablePeriodSettingsSheet(
                    periods: viewModel.periods,
                    onSave: { drafts in
                        viewModel.savePeriodDrafts(drafts)
                        isShowingPeriodSettings = false
                    },
                    onCancel: {
                        isShowingPeriodSettings = false
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingTermEditor) {
            NavigationStack {
                TimetableTermEditorSheet(
                    term: isCreatingTerm ? nil : viewModel.selectedTerm,
                    onSave: { term in
                        viewModel.saveTerm(term)
                        isCreatingTerm = false
                        isShowingTermEditor = false
                    },
                    onCancel: {
                        isCreatingTerm = false
                        isShowingTermEditor = false
                    }
                )
            }
        }
        .sheet(item: $editorContext) { context in
            NavigationStack {
                TimetableEntryEditorSheet(
                    context: context,
                    onSave: { entry in
                        viewModel.saveEntry(entry)
                        editorContext = nil
                    },
                    onDelete: { entry in
                        viewModel.deleteEntry(entry)
                        editorContext = nil
                    },
                    onCancel: {
                        editorContext = nil
                    }
                )
            }
        }
        .sheet(item: $reviewEditorContext) { occurrence in
            NavigationStack {
                TimetableReviewEditorSheet(
                    occurrence: occurrence,
                    onSave: { reviewed, note in
                        viewModel.setReviewed(occurrence, reviewed: reviewed, note: note)
                        reviewEditorContext = nil
                    },
                    onExclude: {
                        viewModel.setExcluded(occurrence, excluded: true)
                        reviewEditorContext = nil
                    },
                    onRestore: {
                        viewModel.setExcluded(occurrence, excluded: false)
                        reviewEditorContext = nil
                    },
                    onCancel: {
                        reviewEditorContext = nil
                    }
                )
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var timetableHeader: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("月〜土の授業")
                    .font(.headline)
                Text("空きコマをタップして科目、講座名、教室を登録します。")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                isCreatingTerm = false
                isShowingTermEditor = true
            } label: {
                Label("学期", systemImage: "calendar")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.bordered)
            Button {
                isShowingPeriodSettings = true
            } label: {
                Label("時限", systemImage: "clock")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.bordered)
        }
        .cardStyle()
    }

    private var termOverview: some View {
        let summary = viewModel.termSummary
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedTerm?.name ?? "学期未設定")
                        .font(.headline)
                    Text(viewModel.selectedTerm?.dateRangeText ?? "学期を設定してください")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                if !viewModel.terms.isEmpty {
                    Menu {
                        ForEach(viewModel.terms) { term in
                            Button(term.name) {
                                viewModel.selectTerm(term)
                            }
                        }
                    } label: {
                        Label("切替", systemImage: "chevron.down.circle")
                    }
                }
                Button {
                    isCreatingTerm = true
                    isShowingTermEditor = true
                } label: {
                    Label("追加", systemImage: "plus.circle")
                }
            }

            ProgressView(value: summary.completionRate)
                .tint(summary.pending > 0 ? AppColors.danger : .green)

            HStack(spacing: AppSpacing.sm) {
                TimetableSummaryBadge(title: "復習済み", value: summary.reviewed, color: .green)
                TimetableSummaryBadge(title: "未復習", value: summary.pending, color: AppColors.danger)
                TimetableSummaryBadge(title: "対象外", value: summary.excluded, color: .secondary)
            }
        }
        .cardStyle()
    }

    private var reviewCalendar: some View {
        DatePicker(
            "復習確認日",
            selection: Binding(
                get: { viewModel.selectedDate },
                set: { viewModel.selectDate($0) }
            ),
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(viewModel.isDateInSelectedTerm(viewModel.selectedDate) ? Color.clear : AppColors.danger.opacity(0.35))
        }
    }

    private var selectedDateLessons: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeaderView(title: "この日の授業復習", icon: "checklist.checked")
                Spacer()
            }

            if viewModel.selectedDateOccurrences.isEmpty {
                Text(viewModel.isDateInSelectedTerm(viewModel.selectedDate) ? "この日の授業はありません" : "選択日は学期の範囲外です")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(viewModel.selectedDateOccurrences) { occurrence in
                    TimetableReviewOccurrenceRow(occurrence: occurrence) {
                        reviewEditorContext = occurrence
                    }
                }
            }
        }
    }

    private var timetableGrid: some View {
        let columns = viewModel.periods
        let slotMap = viewModel.entriesBySlot

        return ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    TimetableCornerCell()
                    ForEach(columns) { period in
                        TimetablePeriodHeader(period: period)
                    }
                }

                ForEach(StudyWeekday.timetableDays) { day in
                    HStack(spacing: 0) {
                        TimetableDayHeader(day: day)
                        ForEach(columns) { period in
                            let entry = slotMap[TimetableSlotKey(day: day, periodId: period.id)]
                            TimetableCell(entry: entry) {
                                editorContext = TimetableEditorContext(term: viewModel.selectedTerm, day: day, period: period, entry: entry)
                            }
                            .contextMenu {
                                if let entry {
                                    Button(role: .destructive) {
                                        viewModel.deleteEntry(entry)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
    }
}

private struct TimetableCornerCell: View {
    var body: some View {
        Text("")
            .frame(width: 48, height: 58)
    }
}

private struct TimetablePeriodHeader: View {
    let period: TimetablePeriod

    var body: some View {
        VStack(spacing: 2) {
            Text(period.name)
                .font(.caption.bold())
                .foregroundStyle(AppColors.textPrimary)
            Text(period.timeRangeText)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(width: 132, height: 58)
    }
}

private struct TimetableDayHeader: View {
    let day: StudyWeekday

    var body: some View {
        Text(day.japaneseShortTitle)
            .font(.headline)
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 48, height: 86)
    }
}

private struct TimetableCell: View {
    let entry: TimetableEntry?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                if let entry {
                    Text(entry.subjectName)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                        .foregroundStyle(AppColors.textPrimary)
                    if let course = entry.courseName, !course.isEmpty {
                        Text(course)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let room = entry.roomName, !room.isEmpty {
                        Label(room, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.tint)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColors.textSecondary)
                    Text("追加")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: 116, height: 70, alignment: .topLeading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(entry == nil ? AppColors.cardBackground : Color.accentColor.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(entry == nil ? Color(.separator).opacity(0.35) : Color.accentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(4)
    }
}

struct TimetableEditorContext: Identifiable {
    let id = UUID()
    var term: TimetableTerm?
    var day: StudyWeekday
    var period: TimetablePeriod
    var entry: TimetableEntry?
}

private struct TimetableSummaryBadge: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct TimetableReviewOccurrenceRow: View {
    let occurrence: TimetableReviewOccurrence
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(occurrence.entry.subjectName)
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(statusText)
                            .font(.caption.bold())
                            .foregroundStyle(statusColor)
                    }
                    Text("\(occurrence.period.name) \(occurrence.period.timeRangeText)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    if let course = occurrence.entry.courseName, !course.isEmpty {
                        Text(course)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let note = occurrence.record?.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(statusColor.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(statusColor.opacity(0.35), lineWidth: occurrence.status == .pending || occurrence.status == .overdue ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch occurrence.status {
        case .notAvailable: return "clock"
        case .pending: return "exclamationmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .reviewed: return "checkmark.circle.fill"
        case .excluded: return "slash.circle.fill"
        }
    }

    private var statusText: String {
        switch occurrence.status {
        case .notAvailable: return "授業後に記録可"
        case .pending: return "未復習"
        case .overdue: return "期限超過"
        case .reviewed: return "復習済み"
        case .excluded: return "対象外"
        }
    }

    private var statusColor: Color {
        switch occurrence.status {
        case .notAvailable: return AppColors.textSecondary
        case .pending, .overdue: return AppColors.danger
        case .reviewed: return .green
        case .excluded: return .secondary
        }
    }

    private var backgroundOpacity: Double {
        switch occurrence.status {
        case .pending, .overdue: return 0.18
        default: return 0.10
        }
    }
}

private struct TimetableEntryEditorSheet: View {
    let context: TimetableEditorContext
    let onSave: (TimetableEntry) -> Void
    let onDelete: (TimetableEntry) -> Void
    let onCancel: () -> Void

    @State private var subjectName: String
    @State private var courseName: String
    @State private var roomName: String

    init(
        context: TimetableEditorContext,
        onSave: @escaping (TimetableEntry) -> Void,
        onDelete: @escaping (TimetableEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _subjectName = State(initialValue: context.entry?.subjectName ?? "")
        _courseName = State(initialValue: context.entry?.courseName ?? "")
        _roomName = State(initialValue: context.entry?.roomName ?? "")
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(context.day.japaneseTitle)
                    Spacer()
                    Text("\(context.period.name) \(context.period.timeRangeText)")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Section("授業") {
                TextField("科目", text: $subjectName)
                TextField("講座名", text: $courseName)
                TextField("教室", text: $roomName)
                if context.entry != nil {
                    Text("保存すると、過去の復習履歴はそのまま残し、今後の時間割だけを新しい内容にします。")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let entry = context.entry {
                Section {
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Label("このコマを削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(context.entry == nil ? "授業を追加" : "授業を編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let now = Date().epochMilliseconds
                    onSave(
                        TimetableEntry(
                            id: context.entry?.id ?? 0,
                            syncId: context.entry?.syncId ?? UUID().uuidString.lowercased(),
                            termId: context.term?.id,
                            termSyncId: context.term?.syncId,
                            dayOfWeek: context.day,
                            periodId: context.period.id,
                            periodSyncId: context.period.syncId,
                            subjectName: subjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                            courseName: courseName.nilIfBlank,
                            roomName: roomName.nilIfBlank,
                            validFromDate: context.entry?.validFromDate,
                            validToDate: context.entry?.validToDate,
                            createdAt: context.entry?.createdAt ?? now,
                            updatedAt: now,
                            deletedAt: context.entry?.deletedAt,
                            lastSyncedAt: context.entry?.lastSyncedAt
                        )
                    )
                }
                .disabled(subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct TimetableTermEditorSheet: View {
    let term: TimetableTerm?
    let onSave: (TimetableTerm) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorMessage: String?

    init(term: TimetableTerm?, onSave: @escaping (TimetableTerm) -> Void, onCancel: @escaping () -> Void) {
        self.term = term
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: term?.name ?? "新しい学期")
        _startDate = State(initialValue: term?.startDateValue ?? Date().startOfDay)
        _endDate = State(initialValue: term?.endDateValue ?? (Calendar.current.date(byAdding: .month, value: 6, to: Date().startOfDay) ?? Date().startOfDay))
    }

    var body: some View {
        Form {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.danger)
            }

            Section("学期") {
                TextField("学期名", text: $name)
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)
            }
        }
        .navigationTitle(term == nil ? "学期を追加" : "学期を編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        errorMessage = "学期名を入力してください"
                        return
                    }
                    guard startDate.startOfDay <= endDate.startOfDay else {
                        errorMessage = "終了日は開始日以降にしてください"
                        return
                    }
                    let now = Date().epochMilliseconds
                    onSave(
                        TimetableTerm(
                            id: term?.id ?? 0,
                            syncId: term?.syncId ?? UUID().uuidString.lowercased(),
                            name: trimmed,
                            startDate: startDate.startOfDay.epochDay,
                            endDate: endDate.startOfDay.epochDay,
                            isActive: true,
                            createdAt: term?.createdAt ?? now,
                            updatedAt: now,
                            deletedAt: term?.deletedAt,
                            lastSyncedAt: term?.lastSyncedAt
                        )
                    )
                }
            }
        }
    }
}

private struct TimetableReviewEditorSheet: View {
    let occurrence: TimetableReviewOccurrence
    let onSave: (Bool, String?) -> Void
    let onExclude: () -> Void
    let onRestore: () -> Void
    let onCancel: () -> Void

    @State private var note: String

    init(
        occurrence: TimetableReviewOccurrence,
        onSave: @escaping (Bool, String?) -> Void,
        onExclude: @escaping () -> Void,
        onRestore: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.occurrence = occurrence
        self.onSave = onSave
        self.onExclude = onExclude
        self.onRestore = onRestore
        self.onCancel = onCancel
        _note = State(initialValue: occurrence.record?.note ?? "")
    }

    var body: some View {
        Form {
            Section("授業") {
                LabeledContent("科目", value: occurrence.entry.subjectName)
                LabeledContent("日時", value: "\(formattedDate) \(occurrence.period.name) \(occurrence.period.timeRangeText)")
                if let course = occurrence.entry.courseName, !course.isEmpty {
                    LabeledContent("講座", value: course)
                }
                if let room = occurrence.entry.roomName, !room.isEmpty {
                    LabeledContent("教室", value: room)
                }
            }

            Section("復習メモ") {
                TextEditor(text: $note)
                    .frame(minHeight: 96)
            }

            Section {
                Button {
                    onSave(true, note)
                } label: {
                    Label("復習済みにする", systemImage: "checkmark.circle.fill")
                }
                .disabled(!occurrence.canReview)

                if occurrence.isReviewed {
                    Button {
                        onSave(false, note)
                    } label: {
                        Label("未復習に戻す", systemImage: "arrow.uturn.backward.circle")
                    }
                }

                if occurrence.isExcluded {
                    Button("対象外を解除", action: onRestore)
                } else {
                    Button("この日は授業なし（対象外）", action: onExclude)
                }
            }
        }
        .navigationTitle("復習記録")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる", action: onCancel)
            }
        }
    }

    private var formattedDate: String {
        occurrence.date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct TimetablePeriodSettingsSheet: View {
    let onSave: ([TimetablePeriodDraft]) -> Void
    let onCancel: () -> Void
    @State private var drafts: [TimetablePeriodDraft]
    @State private var errorMessage: String?

    init(periods: [TimetablePeriod], onSave: @escaping ([TimetablePeriodDraft]) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        _drafts = State(initialValue: periods.map(TimetablePeriodDraft.init(period:)))
    }

    var body: some View {
        Form {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.danger)
            }

            ForEach($drafts) { $draft in
                Section(draft.name) {
                    DatePicker("開始", selection: $draft.startDate, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $draft.endDate, displayedComponents: .hourAndMinute)
                }
            }
        }
        .navigationTitle("時限設定")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if let invalid = drafts.first(where: { $0.startMinute >= $0.endMinute }) {
                        errorMessage = "\(invalid.name) の終了時刻は開始時刻より後にしてください"
                    } else {
                        onSave(drafts)
                    }
                }
            }
        }
    }
}
