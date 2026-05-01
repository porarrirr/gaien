import SwiftUI

struct TimetableScreen: View {
    @StateObject private var viewModel: TimetableViewModel
    @State private var isShowingPeriodSettings = false
    @State private var editorContext: TimetableEditorContext?

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timetableHeader
                    .padding(.horizontal, AppSpacing.md)

                timetableGrid
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("時間割")
        .toolbar {
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
                isShowingPeriodSettings = true
            } label: {
                Label("時限", systemImage: "clock")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.bordered)
        }
        .cardStyle()
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
                                editorContext = TimetableEditorContext(day: day, period: period, entry: entry)
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
    var day: StudyWeekday
    var period: TimetablePeriod
    var entry: TimetableEntry?
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
                            dayOfWeek: context.day,
                            periodId: context.period.id,
                            periodSyncId: context.period.syncId,
                            subjectName: subjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                            courseName: courseName.nilIfBlank,
                            roomName: roomName.nilIfBlank,
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
