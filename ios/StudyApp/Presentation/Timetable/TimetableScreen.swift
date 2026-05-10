import SwiftUI
import UniformTypeIdentifiers

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

    private var calendar: Calendar { Calendar.current }
    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    private var displayYear: Int {
        calendar.component(.year, from: viewModel.displayedMonth)
    }

    private var displayMonth: Int {
        calendar.component(.month, from: viewModel.displayedMonth)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                timetableHeader

                termOverview

                HStack(alignment: .top, spacing: 8) {
                    reviewCalendar
                        .frame(maxWidth: .infinity)
                    selectedDateLessons
                        .frame(width: 168)
                }

                timetableGrid
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("時間割")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isCreatingTerm = true
                    isShowingTermEditor = true
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                        Text("学期設定")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppColors.green)
                }
                .accessibilityLabel("学期設定")

                Button {
                    isShowingPeriodSettings = true
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "clock.badge")
                            .font(.title3)
                        Text("時限設定")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppColors.green)
                }
                .accessibilityLabel("時限設定")
            }
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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text("月〜土の授業")
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.textPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("授業ごとの復習状況を記録できます。")
                    Text("日付を選択して、この日の授業を確認しましょう。")
                }
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                TimetableOutlinedActionButton(title: "学期", systemImage: "graduationcap") {
                    isCreatingTerm = false
                    isShowingTermEditor = true
                }
                TimetableOutlinedActionButton(title: "時限", systemImage: "clock") {
                    isShowingPeriodSettings = true
                }
            }
        }
        .padding(14)
        .background(TimetableCardBackground())
    }

    private var termOverview: some View {
        let summary = viewModel.termSummary
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    isCreatingTerm = false
                    isShowingTermEditor = true
                } label: {
                    Text(viewModel.selectedTerm?.name ?? "前期")
                        .font(.headline.bold())
                        .foregroundStyle(AppColors.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.green.opacity(0.65), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Text(viewModel.selectedTerm?.dateRangeText.replacingOccurrences(of: " - ", with: " 〜 ") ?? "学期を設定してください")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if !viewModel.terms.isEmpty {
                    Menu {
                        ForEach(viewModel.terms) { term in
                            Button(term.name) {
                                viewModel.selectTerm(term)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .font(.title3)
                            .foregroundStyle(AppColors.green)
                    }
                }
            }

            HStack(spacing: 12) {
                Text("復習の進捗")
                    .font(.subheadline.bold())
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray4))
                        Capsule()
                            .fill(AppColors.green)
                            .frame(width: proxy.size.width * Swift.max(0, Swift.min(1, summary.completionRate)))
                    }
                }
                .frame(height: 8)
                Text("\(Int((summary.completionRate * 100).rounded()))%")
                    .font(.headline.bold())
                    .foregroundStyle(AppColors.green)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            HStack(spacing: 30) {
                TimetableLegendItem(title: "復習済み", color: AppColors.green)
                TimetableLegendItem(title: "未復習", color: AppColors.orange)
                TimetableLegendItem(title: "対象外", color: Color(.systemGray3))
            }
        }
        .padding(14)
        .background(TimetableCardBackground())
    }

    private var reviewCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    viewModel.moveDisplayedMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.green)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Text(calendarMonthTitle)
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)

                Button {
                    viewModel.moveDisplayedMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.green)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(weekdayHeaderColor(index))
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { item in
                    TimetableReviewCalendarDayCell(
                        day: item.day,
                        isSelected: calendar.isDate(item.date, inSameDayAs: viewModel.selectedDate),
                        isCurrentMonth: item.isCurrentMonth,
                        isToday: calendar.isDateInToday(item.date),
                        status: item.isCurrentMonth ? viewModel.occurrenceStatusByDayInDisplayedMonth[item.day] : nil,
                        isInSelectedTerm: viewModel.isDateInSelectedTerm(item.date),
                        weekdayIndex: calendar.component(.weekday, from: item.date) - 1
                    )
                    .onTapGesture {
                        viewModel.selectDate(item.date)
                    }
                }
            }
        }
        .padding(14)
        .background(TimetableCardBackground())
    }

    private var calendarDays: [TimetableCalendarDay] {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: 1)) else { return [] }
        let firstIndex = calendar.component(.weekday, from: firstOfMonth) - 1
        let visibleStart = calendar.date(byAdding: .day, value: -firstIndex, to: firstOfMonth) ?? firstOfMonth
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: visibleStart) else { return nil }
            return TimetableCalendarDay(
                date: date.startOfDay,
                day: calendar.component(.day, from: date),
                isCurrentMonth: calendar.isDate(date, equalTo: viewModel.displayedMonth, toGranularity: .month)
            )
        }
    }

    private func weekdayHeaderColor(_ index: Int) -> Color {
        if index == 0 { return AppColors.danger }
        if index == 6 { return AppColors.blue }
        return AppColors.textPrimary
    }

    private var calendarMonthTitle: String {
        "\(displayYear)年 \(displayMonth)月"
    }

    private var selectedDateLessons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この日の授業復習")
                .font(.headline.bold())
            Text(selectedDateTitle)
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.green)

            if viewModel.selectedDateOccurrences.isEmpty {
                Text(viewModel.isDateInSelectedTerm(viewModel.selectedDate) ? "この日の授業はありません" : "選択日は学期の範囲外です")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 284, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.selectedDateOccurrences) { occurrence in
                        TimetableReviewOccurrenceRow(occurrence: occurrence) {
                            reviewEditorContext = occurrence
                        }
                        if occurrence.id != viewModel.selectedDateOccurrences.last?.id {
                            Divider()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 316, alignment: .top)
        .background(TimetableCardBackground())
    }

    private var selectedDateTitle: String {
        StudyFormatters.monthDayWithWeekdaySpaced.string(from: viewModel.selectedDate)
    }

    private var timetableGrid: some View {
        let rows = viewModel.periods.prefix(6)
        let columns = StudyWeekday.timetableDays
        let slotMap = viewModel.entriesBySlot

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                TimetableCornerCell()
                ForEach(columns) { day in
                    TimetableDayHeader(day: day)
                }
            }

            ForEach(Array(rows)) { period in
                HStack(spacing: 0) {
                    TimetablePeriodHeader(period: period)
                    ForEach(columns) { day in
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(0.28), lineWidth: 1)
        }
    }
}

private struct TimetableCalendarDay: Identifiable {
    let date: Date
    let day: Int
    let isCurrentMonth: Bool

    var id: Date { date }
}

private struct TimetableCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppColors.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.separator).opacity(0.24), lineWidth: 1)
            }
    }
}

private struct TimetableOutlinedActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.green)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct TimetableLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

private struct TimetableReviewCalendarDayCell: View {
    let day: Int
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let status: TimetableReviewStatus?
    let isInSelectedTerm: Bool
    let weekdayIndex: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(dayColor)
                .frame(width: 27, height: 27)
                .background(selectionBackground)
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .opacity(dotOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 37)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Circle()
                .fill(AppColors.greenSoft)
                .overlay {
                    Circle()
                        .stroke(AppColors.green, lineWidth: 2)
                }
        } else if isToday {
            Circle()
                .stroke(AppColors.green.opacity(0.35), lineWidth: 1)
        }
    }

    private var dayColor: Color {
        if !isCurrentMonth {
            return AppColors.textSecondary
        }
        if weekdayIndex == 0 {
            return AppColors.danger
        }
        if weekdayIndex == 6 {
            return AppColors.blue
        }
        return AppColors.textPrimary
    }

    private var dotColor: Color {
        guard isCurrentMonth else { return Color(.systemGray3) }
        guard isInSelectedTerm else { return Color(.systemGray3) }
        switch status {
        case .pending, .overdue:
            return AppColors.orange
        case .reviewed:
            return AppColors.green
        case .excluded, .notAvailable:
            return Color(.systemGray3)
        case .none:
            return Color(.systemGray3)
        }
    }

    private var dotOpacity: Double {
        if !isCurrentMonth { return 0.8 }
        return status == nil ? 0 : 1
    }
}

private struct TimetableCornerCell: View {
    var body: some View {
        Text("")
            .frame(width: 58, height: 48)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.24))
                    .frame(width: 1)
            }
    }
}

private struct TimetablePeriodHeader: View {
    let period: TimetablePeriod

    var body: some View {
        VStack(spacing: 2) {
            Text(period.name)
                .font(.headline.bold())
                .foregroundStyle(AppColors.textPrimary)
            Text(period.timeRangeText)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(width: 58, height: 86)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(.separator).opacity(0.24))
                .frame(width: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.18))
                .frame(height: 1)
        }
    }
}

private struct TimetableDayHeader: View {
    let day: StudyWeekday

    var body: some View {
        Text(day.japaneseShortTitle)
            .font(.subheadline.bold())
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 57, height: 48)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.24))
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.24))
                    .frame(height: 1)
            }
    }
}

private struct TimetableCell: View {
    let entry: TimetableEntry?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let entry {
                    Text(entry.subjectName)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(subjectColor(for: entry.subjectName))
                    if let course = entry.courseName, !course.isEmpty {
                        Text(course)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let room = entry.roomName, !room.isEmpty {
                        Text(room)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else {
                    Text("—")
                        .font(.title3)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: 57, height: 86)
            .background(entryBackground)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.20))
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.separator).opacity(0.18))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var entryBackground: Color {
        guard let entry else { return AppColors.cardBackground }
        return subjectColor(for: entry.subjectName).opacity(0.08)
    }

    private func subjectColor(for name: String) -> Color {
        switch name {
        case let value where value.contains("数学"):
            return AppColors.blue
        case let value where value.contains("英"):
            return AppColors.danger
        case let value where value.contains("化"):
            return AppColors.green
        case let value where value.contains("体育"):
            return Color(hex: 0x6A3FB8)
        case let value where value.contains("現代文"):
            return Color(hex: 0xFF6A00)
        case let value where value.contains("総探"):
            return Color(hex: 0x7A5548)
        default:
            return AppColors.textPrimary
        }
    }
}

struct TimetableEditorContext: Identifiable {
    let id = UUID()
    var term: TimetableTerm?
    var day: StudyWeekday
    var period: TimetablePeriod
    var entry: TimetableEntry?
}

private struct TimetableReviewOccurrenceRow: View {
    let occurrence: TimetableReviewOccurrence
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(periodColor)
                    .frame(width: 8, height: 8)
                Text(occurrence.period.name)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 22, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(occurrence.entry.subjectName)
                        .font(.caption.bold())
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let course = occurrence.entry.courseName, !course.isEmpty {
                        Text(course)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else if let room = occurrence.entry.roomName, !room.isEmpty {
                        Text(room)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                Spacer(minLength: 2)
                Text(statusText)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(statusColor.opacity(0.45), lineWidth: 1)
                    }
            }
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private var periodColor: Color {
        switch occurrence.period.sortOrder {
        case 1:
            return AppColors.blue
        case 2:
            return AppColors.danger
        case 3:
            return AppColors.orange
        case 4:
            return AppColors.green
        case 5:
            return Color(hex: 0x6A3FB8)
        default:
            return Color(hex: 0x7A5548)
        }
    }

    private var statusText: String {
        switch occurrence.status {
        case .notAvailable: return "授業後"
        case .pending, .overdue: return "未復習"
        case .reviewed: return "復習済み"
        case .excluded: return "対象外"
        }
    }

    private var statusColor: Color {
        switch occurrence.status {
        case .notAvailable: return AppColors.textSecondary
        case .pending, .overdue: return AppColors.orange
        case .reviewed: return AppColors.green
        case .excluded: return .secondary
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
    @State private var memo: String = ""
    @FocusState private var focusedField: TimetableEntryEditorField?

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
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                topBar

                VStack(alignment: .leading, spacing: 13) {
                    Text("授業の情報")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        TimetableEntryInfoRow(
                            icon: "calendar",
                            iconColor: AppColors.green,
                            title: "学期",
                            value: context.term?.name ?? "未設定"
                        )

                        TimetableEntryDivider()

                        TimetableEntryInfoRow(
                            icon: "calendar",
                            iconColor: AppColors.blue,
                            title: "曜日",
                            value: context.day.japaneseTitle
                        )

                        TimetableEntryDivider()

                        TimetableEntryInfoRow(
                            icon: "clock",
                            iconColor: Color(hex: 0x7442D8),
                            title: "時限",
                            value: "\(context.period.name)  \(periodTimeRangeText)"
                        )
                    }
                    .background(editorCardBackground)
                    .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 13) {
                    Text("授業の詳細")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        subjectRow

                        TimetableEntryDivider()

                        TimetableEntryTextRow(
                            title: "講座名",
                            placeholder: "微分法",
                            text: $courseName,
                            focusedField: $focusedField,
                            field: .course
                        )

                        TimetableEntryDivider()

                        TimetableEntryTextRow(
                            title: "教室",
                            placeholder: "101教室",
                            text: $roomName,
                            focusedField: $focusedField,
                            field: .room
                        )

                        TimetableEntryDivider()

                        memoRow
                    }
                    .background(editorCardBackground)
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    Button(action: saveEntry) {
                        Text("保存")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.green)
                    )
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)

                    Button(action: onCancel) {
                        Text("キャンセル")
                            .font(.system(size: 19, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 55)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.green)
                    .background(editorButtonBackground)

                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
            }
            .padding(.top, 17)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(.systemGray3))
                .frame(width: 42, height: 6)

            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColors.green)
                    .frame(width: 112, alignment: .leading)

                Spacer()

                Text(context.entry == nil ? "授業を追加" : "授業を編集")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("保存", action: saveEntry)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(canSave ? AppColors.green : AppColors.textSecondary)
                    .disabled(!canSave)
                    .frame(width: 112, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }

    private var subjectRow: some View {
        HStack(spacing: 12) {
            Text("科目")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 8)

            Circle()
                .fill(subjectColor)
                .frame(width: 28, height: 28)

            TextField("数学 III", text: $subjectName)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .subject)

            Image(systemName: "chevron.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(minHeight: 68)
        .padding(.horizontal, 18)
    }

    private var memoRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("メモ")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.textPrimary)
                Text("（任意）")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $memo)
                    .font(.system(size: 18))
                    .frame(height: 122)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .memo)
                    .onChange(of: memo) { newValue in
                        if newValue.count > 200 {
                            memo = String(newValue.prefix(200))
                        }
                    }

                if memo.isEmpty {
                    Text("メモを入力（任意）")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 19)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(memo.count)/200")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let entry = context.entry {
            Button(role: .destructive) {
                onDelete(entry)
            } label: {
                Text("削除")
                    .font(.system(size: 19, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 55)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.danger)
            .background(editorButtonBackground)
        } else {
            Text("削除")
                .font(.system(size: 19, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 55)
                .foregroundStyle(AppColors.danger.opacity(0.35))
                .background(editorButtonBackground)
        }
    }

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(AppColors.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
    }

    private var editorButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppColors.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
    }

    private var canSave: Bool {
        !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var periodTimeRangeText: String {
        "\(TimetablePeriod.timeText(context.period.startMinute)) - \(TimetablePeriod.timeText(context.period.endMinute))"
    }

    private var subjectColor: Color {
        switch subjectName {
        case let value where value.contains("数学"):
            return AppColors.blue
        case let value where value.contains("英"):
            return AppColors.danger
        case let value where value.contains("化"):
            return AppColors.green
        case let value where value.contains("体育"):
            return Color(hex: 0x7442D8)
        case let value where value.contains("現代文"):
            return AppColors.orange
        default:
            return AppColors.blue
        }
    }

    private func saveEntry() {
        guard canSave else { return }
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
}

private struct TimetableEntryInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 34)

            Text(title)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 86, alignment: .leading)

            Text(value)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 68)
        .padding(.horizontal, 18)
    }
}

private struct TimetableEntryTextRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focusedField: FocusState<TimetableEntryEditorField?>.Binding
    let field: TimetableEntryEditorField

    var body: some View {
        HStack(spacing: 13) {
            Text(title)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 82, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 18))
                .focused(focusedField, equals: field)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        }
        .frame(minHeight: 78)
        .padding(.horizontal, 18)
    }
}

private struct TimetableEntryDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray4).opacity(0.7))
            .frame(height: 1)
            .padding(.leading, 18)
            .padding(.trailing, 18)
    }
}

private enum TimetableEntryEditorField {
    case subject
    case course
    case room
    case memo
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sheetHeader
                    .padding(.top, 48)

                Text("学期の期間を設定します。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, 18)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.redSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(spacing: 0) {
                    termNameRow
                    TimetableTermEditorDivider()
                    TimetableTermDateRow(title: "開始日", date: $startDate)
                    TimetableTermEditorDivider()
                    TimetableTermDateRow(title: "終了日", date: $endDate)
                }
                .padding(.horizontal, 18)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                }

                Text("※ 終了日は学期の最終日を設定してください。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, -4)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sheetHeader: some View {
        ZStack {
            Text(term == nil ? "学期を追加" : "学期を編集")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(.label))

            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.green)

                Spacer()

                Button("保存", action: saveTerm)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.green)
            }
        }
    }

    private var termNameRow: some View {
        HStack(spacing: 16) {
            Text("学期名")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 74, alignment: .leading)

            TextField("学期名", text: $name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                }
        }
        .frame(height: 73)
    }

    private func saveTerm() {
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

private struct TimetableTermDateRow: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 74, alignment: .leading)

            ZStack {
                HStack {
                    Text(StudyFormatters.yearMonthDayWithWeekdayHalf.string(from: date))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(.label))

                    Spacer(minLength: 8)

                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.green)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                }

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .opacity(0.02)
            }
        }
        .frame(height: 73)
    }
}

private struct TimetableTermEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xDADDE3))
            .frame(height: 1)
            .padding(.leading, 74)
    }
}

private struct TimetableReviewEditorSheet: View {
    let occurrence: TimetableReviewOccurrence
    let onSave: (Bool, String?) -> Void
    let onExclude: () -> Void
    let onRestore: () -> Void
    let onCancel: () -> Void

    @State private var note: String
    @State private var isReviewed: Bool
    private let noteLimit = 300

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
        _isReviewed = State(initialValue: occurrence.isReviewed)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCopy
                    .padding(.top, 10)

                lessonCard

                reviewStateCard

                memoCard
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("復習記録")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.green)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(isReviewed, normalizedNote)
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.green)
                .disabled(!occurrence.canReview && isReviewed)
            }
        }
    }

    private var headerCopy: some View {
        Text("この授業の復習を記録します。\n問題集の記録ではありません。")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .lineSpacing(3)
    }

    private var lessonCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 16) {
                TimetableReviewSectionTitle("授業情報")

                HStack(alignment: .center, spacing: 14) {
                    Circle()
                        .fill(Color(hex: 0x5B8FF9))
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(occurrence.entry.subjectName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        VStack(alignment: .leading, spacing: 12) {
                            TimetableReviewInfoRow(
                                icon: "clock",
                                primary: occurrence.period.name,
                                secondary: occurrence.period.timeRangeText
                            )

                            if let course = occurrence.entry.courseName, !course.isEmpty {
                                TimetableReviewInfoRow(icon: "book", primary: "講座名", secondary: course)
                            }

                            if let room = occurrence.entry.roomName, !room.isEmpty {
                                TimetableReviewInfoRow(icon: "building.2", primary: "教室", secondary: room)
                            }
                        }
                    }

                    Spacer(minLength: 6)

                    VStack(spacing: 7) {
                        Image(systemName: "calendar")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColors.green)
                            .frame(width: 34, height: 28)
                            .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(shortDateText)
                            .font(.caption.weight(.semibold))
                        Text(occurrence.term.name)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 84, height: 84)
                    .background(AppColors.greenSoft.opacity(0.85), in: Circle())
                }
            }
        }
    }

    private var reviewStateCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 18) {
                TimetableReviewSectionTitle("復習の状態")

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("復習済みにする")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("この授業を復習済みとして記録します。")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 14)

                    Toggle("", isOn: $isReviewed)
                        .labelsHidden()
                        .tint(AppColors.green)
                        .disabled(!occurrence.canReview && !occurrence.isReviewed)
                        .scaleEffect(1.08)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isReviewed ? "checkmark.circle" : statusIcon)
                        .font(.title3.weight(.semibold))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isReviewed ? "復習済み" : statusText)
                            .font(.headline.weight(.bold))
                        Text(reviewStateDescription)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(statusPanelColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusPanelColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(statusPanelColor.opacity(0.22), lineWidth: 1)
                }
            }
        }
    }

    private var memoCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 14) {
                TimetableReviewSectionTitle("メモ（任意）")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .frame(minHeight: 116)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        }

                    if note.isEmpty {
                        Text("授業の内容や復習したことをメモしてください...")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }

                    Text("\(note.count) / \(noteLimit)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, 18)
                        .allowsHitTesting(false)
                }
                .onChange(of: note) { newValue in
                    if newValue.count > noteLimit {
                        note = String(newValue.prefix(noteLimit))
                    }
                }

                Button(action: onExclude) {
                    TimetableReviewActionRow(
                        icon: "nosign",
                        title: "対象外にする",
                        subtitle: "この授業を復習の対象から外します。",
                        color: AppColors.danger,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(occurrence.isExcluded)
                .opacity(occurrence.isExcluded ? 0.55 : 1)

                Button(action: onRestore) {
                    TimetableReviewActionRow(
                        icon: "arrow.counterclockwise",
                        title: "対象外を戻す",
                        subtitle: "対象外にした状態を元に戻します。",
                        color: AppColors.orange,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(!occurrence.isExcluded)
                .opacity(occurrence.isExcluded ? 1 : 0.72)

                Text("※ 対象外にすると、この授業は復習の集計に含まれなくなります。")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
            }
        }
    }

    private var normalizedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var formattedDate: String {
        occurrence.date.formatted(date: .abbreviated, time: .omitted)
    }

    private var shortDateText: String {
        StudyFormatters.monthDayWithWeekday.string(from: occurrence.date)
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

    private var reviewStateDescription: String {
        if isReviewed {
            return "授業内容を振り返り、理解を確認した場合にオンにしてください。"
        }
        if occurrence.isExcluded {
            return "この授業は現在、復習の集計対象から外れています。"
        }
        return "復習が終わったらオンにして、右上の保存を押してください。"
    }

    private var statusColor: Color {
        switch occurrence.status {
        case .notAvailable: return AppColors.textSecondary
        case .pending, .overdue: return AppColors.danger
        case .reviewed: return AppColors.success
        case .excluded: return .secondary
        }
    }

    private var statusPanelColor: Color {
        isReviewed ? AppColors.green : statusColor
    }

    private var statusIcon: String {
        switch occurrence.status {
        case .notAvailable: return "clock"
        case .pending: return "exclamationmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .reviewed: return "checkmark.circle.fill"
        case .excluded: return "slash.circle.fill"
        }
    }
}

private struct TimetableReviewCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

private struct TimetableReviewSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(AppColors.green)
    }
}

private struct TimetableReviewInfoRow: View {
    let icon: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .frame(width: 22)
            Text(primary)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .frame(minWidth: 44, alignment: .leading)
            Text(secondary)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct TimetableReviewActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct TimetablePeriodSettingsSheet: View {
    let onSave: ([TimetablePeriodDraft]) -> Void
    let onCancel: () -> Void
    @State private var drafts: [TimetablePeriodDraft]
    @State private var errorMessage: String?
    @State private var draggingPeriodId: String?

    init(periods: [TimetablePeriod], onSave: @escaping ([TimetablePeriodDraft]) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        _drafts = State(initialValue: periods.map(TimetablePeriodDraft.init(period:)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("授業の時限名と開始・終了時刻を設定します。")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 18)
                    .padding(.horizontal, 15)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.danger)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.redSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.danger.opacity(0.22), lineWidth: 1)
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("時限一覧")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 15)

                    VStack(spacing: 0) {
                        ForEach(drafts.indices, id: \.self) { index in
                            TimetablePeriodSettingsRow(
                                orderTitle: "\(index + 1)限",
                                draft: $drafts[index],
                                canDelete: drafts.count > 1,
                                onDelete: {
                                    deletePeriod(id: drafts[index].id)
                                }
                            )
                            .onDrag {
                                draggingPeriodId = drafts[index].id
                                return NSItemProvider(object: drafts[index].id as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: TimetablePeriodDropDelegate(
                                    targetId: drafts[index].id,
                                    drafts: $drafts,
                                    draggingId: $draggingPeriodId
                                )
                            )
                            .padding(.vertical, 11)

                            if index < drafts.count - 1 {
                                Divider()
                                    .opacity(0)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.cardBorder.opacity(0.85), lineWidth: 1)
                    }
                }

                Button(action: addPeriod) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 19, weight: .semibold))
                        Text("時限を追加")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.cardBorder.opacity(0.85), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                TimetablePeriodSettingsInfoCard()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 34)
        }
        .background(Color(.systemBackground))
        .navigationTitle("時限設定")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: validateAndSave)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }
        }
    }

    private func validateAndSave() {
        for index in drafts.indices {
            drafts[index].name = drafts[index].name.nilIfBlank ?? "\(index + 1)限"
            drafts[index].period.sortOrder = index + 1
        }
        if let invalid = drafts.first(where: { $0.startMinute >= $0.endMinute }) {
            errorMessage = "\(invalid.name) の終了時刻は開始時刻より後にしてください"
        } else {
            onSave(drafts)
        }
    }

    private func addPeriod() {
        let order = drafts.count + 1
        let lastEnd = drafts.last?.endMinute ?? (8 * 60 + 40)
        let startMinute = Swift.min(lastEnd + 10, 22 * 60)
        let endMinute = Swift.min(startMinute + 50, 23 * 60 + 55)
        drafts.append(TimetablePeriodDraft(order: order, startMinute: startMinute, endMinute: endMinute))
    }

    private func deletePeriod(id: String) {
        guard drafts.count > 1 else { return }
        drafts.removeAll { $0.id == id }
        for index in drafts.indices {
            drafts[index].period.sortOrder = index + 1
        }
    }
}

private struct TimetablePeriodDropDelegate: DropDelegate {
    let targetId: String
    @Binding var drafts: [TimetablePeriodDraft]
    @Binding var draggingId: String?

    func dropEntered(info: DropInfo) {
        guard
            let draggingId,
            draggingId != targetId,
            let fromIndex = drafts.firstIndex(where: { $0.id == draggingId }),
            let toIndex = drafts.firstIndex(where: { $0.id == targetId })
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            let item = drafts.remove(at: fromIndex)
            drafts.insert(item, at: toIndex)
            for index in drafts.indices {
                drafts[index].period.sortOrder = index + 1
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }
}

private struct TimetablePeriodSettingsRow: View {
    let orderTitle: String
    @Binding var draft: TimetablePeriodDraft
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 22)

            Text(orderTitle)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 38, alignment: .leading)

            TextField("", text: $draft.name)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(width: 78, height: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }

            TimetableCompactTimePicker(selection: $draft.startDate)
                .frame(width: 54, height: 34)

            Text("-")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 10)

            TimetableCompactTimePicker(selection: $draft.endDate)
                .frame(width: 54, height: 34)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.danger)
                    .frame(width: 26, height: 34)
            }
            .buttonStyle(.plain)
            .opacity(canDelete ? 1 : 0.35)
            .disabled(!canDelete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimetableCompactTimePicker: View {
    @Binding var selection: Date

    var body: some View {
        Menu {
            Picker("時", selection: hourBinding) {
                ForEach(0..<24, id: \.self) { hour in
                    Text("\(hour)時").tag(hour)
                }
            }
            Picker("分", selection: minuteBinding) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                    Text("\(minute)分").tag(minute)
                }
            }
        } label: {
            Text(timeText)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var timeText: String {
        let calendar = Calendar.current
        return "\(calendar.component(.hour, from: selection)):\(String(format: "%02d", calendar.component(.minute, from: selection)))"
    }

    private var hourBinding: Binding<Int> {
        Binding {
            Calendar.current.component(.hour, from: selection)
        } set: { hour in
            update(hour: hour, minute: Calendar.current.component(.minute, from: selection))
        }
    }

    private var minuteBinding: Binding<Int> {
        Binding {
            let minute = Calendar.current.component(.minute, from: selection)
            return (minute / 5) * 5
        } set: { minute in
            update(hour: Calendar.current.component(.hour, from: selection), minute: minute)
        }
    }

    private func update(hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: selection)
        if let date = calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: hour,
                minute: minute
            )
        ) {
            selection = date
        }
    }
}

private struct TimetablePeriodSettingsInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                Text("設定について")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(AppColors.green)

            VStack(alignment: .leading, spacing: 12) {
                Text("・時限名は自由に変更できます。")
                Text("・時刻は5分単位で設定してください。")
                Text("・時限はドラッグして並べ替えできます。")
            }
            .font(.system(size: 15))
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.greenSoft.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.green.opacity(0.18), lineWidth: 1)
        }
    }
}
