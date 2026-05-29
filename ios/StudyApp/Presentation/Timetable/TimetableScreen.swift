import SwiftUI
import UniformTypeIdentifiers

struct TimetableScreen: View {
    @StateObject private var viewModel: TimetableViewModel
    @State private var isShowingPeriodSettings = false
    @State private var isShowingTermEditor = false
    @State private var isCreatingTerm = false
    @State private var editorContext: TimetableEditorContext?
    @State private var reviewEditorContext: TimetableReviewOccurrence?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(app: app))
    }

    private var calendar: Calendar { Calendar.current }
    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]
    private var usesCompactTimetableLayout: Bool { horizontalSizeClass == .compact }

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

                reviewSection

                timetableGrid
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 96)
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
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.green)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("学期設定")

                Button {
                    isShowingPeriodSettings = true
                } label: {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.green)
                        .frame(width: 34, height: 34)
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
        Group {
            if usesCompactTimetableLayout {
                VStack(alignment: .leading, spacing: 14) {
                    timetableHeaderCopy
                    HStack(spacing: 10) {
                        TimetableOutlinedActionButton(title: "学期", systemImage: "graduationcap", expands: true) {
                            isCreatingTerm = false
                            isShowingTermEditor = true
                        }
                        TimetableOutlinedActionButton(title: "時限", systemImage: "clock", expands: true) {
                            isShowingPeriodSettings = true
                        }
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    timetableHeaderCopy
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
            }
        }
        .padding(14)
        .background(TimetableCardBackground())
    }

    private var timetableHeaderCopy: some View {
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

            Group {
                if usesCompactTimetableLayout {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("復習の進捗")
                            .font(.subheadline.bold())
                        HStack(spacing: 12) {
                            timetableProgressBar(completionRate: summary.completionRate)
                            timetableProgressPercent(completionRate: summary.completionRate)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Text("復習の進捗")
                            .font(.subheadline.bold())
                        timetableProgressBar(completionRate: summary.completionRate)
                        timetableProgressPercent(completionRate: summary.completionRate)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 30) {
                    TimetableLegendItem(title: "復習済み", color: AppColors.green)
                    TimetableLegendItem(title: "未復習", color: AppColors.orange)
                    TimetableLegendItem(title: "対象外", color: Color(.systemGray3))
                }
                HStack(spacing: 16) {
                    TimetableLegendItem(title: "復習済み", color: AppColors.green)
                    TimetableLegendItem(title: "未復習", color: AppColors.orange)
                    TimetableLegendItem(title: "対象外", color: Color(.systemGray3))
                }
                VStack(alignment: .leading, spacing: 8) {
                    TimetableLegendItem(title: "復習済み", color: AppColors.green)
                    TimetableLegendItem(title: "未復習", color: AppColors.orange)
                    TimetableLegendItem(title: "対象外", color: Color(.systemGray3))
                }
            }
        }
        .padding(14)
        .background(TimetableCardBackground())
    }

    private func timetableProgressBar(completionRate: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray4))
                Capsule()
                    .fill(AppColors.green)
                    .frame(width: proxy.size.width * Swift.max(0, Swift.min(1, completionRate)))
            }
        }
        .frame(height: 8)
    }

    private func timetableProgressPercent(completionRate: Double) -> some View {
        Text("\(Int((completionRate * 100).rounded()))%")
            .font(.headline.bold())
            .foregroundStyle(AppColors.green)
            .monospacedDigit()
            .frame(width: 48, alignment: .trailing)
    }

    @ViewBuilder
    private var reviewSection: some View {
        if usesCompactTimetableLayout {
            VStack(alignment: .leading, spacing: 8) {
                reviewCalendar
                selectedDateLessons
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                reviewCalendar
                    .frame(maxWidth: .infinity)
                selectedDateLessons
                    .frame(width: 220)
            }
        }
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
                    .frame(maxWidth: .infinity, minHeight: usesCompactTimetableLayout ? 52 : 284, alignment: .topLeading)
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
        .frame(minHeight: usesCompactTimetableLayout ? 128 : 316, alignment: .top)
        .background(TimetableCardBackground())
    }

    private var selectedDateTitle: String {
        StudyFormatters.monthDayWithWeekdaySpaced.string(from: viewModel.selectedDate)
    }

    private var timetableGrid: some View {
        let rows = viewModel.periods.prefix(6)
        let columns = StudyWeekday.timetableDays
        let slotMap = viewModel.entriesBySlot

        return GeometryReader { proxy in
            let metrics = timetableGridMetrics(availableWidth: proxy.size.width)

            ScrollView(.horizontal, showsIndicators: metrics.totalWidth > proxy.size.width) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TimetableCornerCell(width: metrics.periodColumnWidth, height: metrics.headerHeight)
                        ForEach(columns) { day in
                            TimetableDayHeader(day: day, width: metrics.dayColumnWidth, height: metrics.headerHeight)
                        }
                    }

                    ForEach(Array(rows)) { period in
                        HStack(spacing: 0) {
                            TimetablePeriodHeader(period: period, width: metrics.periodColumnWidth, height: metrics.rowHeight)
                            ForEach(columns) { day in
                                let entry = slotMap[TimetableSlotKey(day: day, periodId: period.id)]
                                TimetableCell(entry: entry, width: metrics.dayColumnWidth, height: metrics.rowHeight) {
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
                .frame(width: metrics.totalWidth)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator).opacity(0.28), lineWidth: 1)
                }
            }
        }
        .frame(height: timetableGridHeight)
    }

    private var timetableGridHeight: CGFloat {
        let rowCount = viewModel.periods.prefix(6).count
        return TimetableGridMetrics.headerHeight + CGFloat(rowCount) * TimetableGridMetrics.rowHeight
    }

    private func timetableGridMetrics(availableWidth: CGFloat) -> TimetableGridMetrics {
        TimetableGridMetrics(availableWidth: availableWidth, isCompact: usesCompactTimetableLayout)
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
    var expands = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.green)
                .padding(.horizontal, 12)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: 44)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct TimetableGridMetrics {
    static let headerHeight: CGFloat = 48
    static let rowHeight: CGFloat = 86

    let periodColumnWidth: CGFloat
    let dayColumnWidth: CGFloat
    let headerHeight = Self.headerHeight
    let rowHeight = Self.rowHeight

    init(availableWidth: CGFloat, isCompact: Bool) {
        let dayCount = CGFloat(StudyWeekday.timetableDays.count)
        let preferredPeriodWidth: CGFloat = isCompact ? 50 : 58
        let preferredDayWidth: CGFloat = isCompact ? 57 : 62
        let minimumDayWidth: CGFloat = 44
        let fittedDayWidth = floor((availableWidth - preferredPeriodWidth) / dayCount)

        periodColumnWidth = preferredPeriodWidth
        dayColumnWidth = max(minimumDayWidth, min(preferredDayWidth, fittedDayWidth))
    }

    var totalWidth: CGFloat {
        periodColumnWidth + dayColumnWidth * CGFloat(StudyWeekday.timetableDays.count)
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
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Text("")
            .frame(width: width, height: height)
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
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(period.name)
                .font(.headline.bold())
                .foregroundStyle(AppColors.textPrimary)
            Text(period.timeRangeText)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: width, height: height)
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
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Text(day.japaneseShortTitle)
            .font(.subheadline.bold())
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: width, height: height)
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
    let width: CGFloat
    let height: CGFloat
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
            .padding(.horizontal, 2)
            .frame(width: width, height: height)
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
