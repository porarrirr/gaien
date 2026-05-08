import Foundation
import SwiftUI

// MARK: - CalendarScreen

struct CalendarScreen: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDay: Int? = nil
    @State private var detailDisplayMode: CalendarDetailDisplayMode = .timeline
    @State private var editingSession: StudySession? = nil
    @State private var pendingDeletionSession: StudySession? = nil
    @State private var intervalDrafts: [HistorySessionIntervalDraft] = []
    @State private var noteText: String = ""
    @State private var ratingSelection: Int? = nil
    @State private var problemStartText: String = ""
    @State private var problemEndText: String = ""
    @State private var wrongProblemCountText: String = ""
    @State private var problemCountText: String = ""
    @State private var editingProblemRecords: [ProblemSessionRecord] = []

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(app: app))
    }

    private var calendar: Calendar { Calendar.current }

    private var displayYear: Int {
        calendar.component(.year, from: viewModel.displayedMonth)
    }

    private var displayMonth: Int {
        calendar.component(.month, from: viewModel.displayedMonth)
    }

    private var todayDay: Int? {
        let now = Date()
        guard calendar.component(.year, from: now) == displayYear,
              calendar.component(.month, from: now) == displayMonth else { return nil }
        return calendar.component(.day, from: now)
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: viewModel.displayedMonth)?.count ?? 30
    }

    private var calendarGridDays: [CalendarSummaryGridDay] {
        visibleCalendarDates.map { date in
            let isCurrentMonth = calendar.component(.year, from: date) == displayYear &&
                calendar.component(.month, from: date) == displayMonth
            let day = calendar.component(.day, from: date)
            return CalendarSummaryGridDay(
                date: date,
                day: day,
                weekday: calendar.component(.weekday, from: date),
                isCurrentMonth: isCurrentMonth,
                minutes: isCurrentMonth ? (viewModel.monthStudyMap[day] ?? 0) : 0
            )
        }
    }

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingDeletionSession != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionSession = nil
                }
            }
        )
    }

    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    private var selectedDate: Date? {
        guard let selectedDay else { return nil }
        return calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: selectedDay))
    }

    private var visibleCalendarDates: [Date] {
        let monthStart = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: 1)) ?? viewModel.displayedMonth.startOfDay
        let weekday = calendar.component(.weekday, from: monthStart)
        let start = calendar.date(byAdding: .day, value: -(weekday - 1), to: monthStart) ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                calendarSummaryCard
                calendarSummaryLegend

                if let day = selectedDay {
                    let sessions = viewModel.sessions(for: day)
                    let subjectSummaries = viewModel.subjectSummaries(for: day)
                    let timelineItems = viewModel.timelineItems(for: day)
                    let totalMins = viewModel.totalMinutes(for: day)

                    VStack(alignment: .leading, spacing: 0) {
                        selectedDayHeader(day: day, totalMinutes: totalMins, sessionCount: sessions.count)
                            .padding(.horizontal, 18)
                            .padding(.top, 18)
                            .padding(.bottom, 14)
                        if sessions.isEmpty && timelineItems.isEmpty {
                            VStack(spacing: AppSpacing.sm) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("この日の記録はありません")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text("タイマーから学習を記録しましょう")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.lg)
                        } else {
                            if !sessions.isEmpty {
                                detailModeSwitch
                                    .padding(.horizontal, 26)
                                    .padding(.bottom, 16)
                            }

                            switch sessions.isEmpty ? CalendarDetailDisplayMode.timeline : detailDisplayMode {
                            case .summary:
                                summaryRows(subjectSummaries)
                            case .timeline:
                                VStack(spacing: 8) {
                                    ForEach(timelineItems) { item in
                                        timelineItemView(item)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                        }
                    }
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    }
                    .padding(.horizontal, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                let totalMinutes = viewModel.monthStudyMap.values.reduce(0, +)
                let studyDays = viewModel.monthStudyMap.values.filter { $0 > 0 }.count
                monthlySummaryCard(totalMinutes: totalMinutes, studyDays: studyDays)
            }
            .padding(.horizontal, 0)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
            selectDefaultDayIfNeeded()
        }
        .onChange(of: viewModel.displayedMonth) { _ in
            selectedDay = nil
            editingSession = nil
            Task {
                await viewModel.load()
                selectDefaultDayIfNeeded()
            }
        }
        .sheet(item: $editingSession) { session in
            HistorySessionEditorSheet(
                session: session,
                chapters: viewModel.materialProblemChapters(for: session),
                totalProblems: editingTotalProblems(for: session),
                intervalDrafts: $intervalDrafts,
                note: $noteText,
                rating: $ratingSelection,
                problemStart: $problemStartText,
                problemEnd: $problemEndText,
                wrongProblemCount: $wrongProblemCountText,
                problemCount: $problemCountText,
                problemRecords: $editingProblemRecords,
                onCancel: { editingSession = nil },
                onSave: { saveEditingSession(session) },
                onDelete: { pendingDeletionSession = session }
            )
        }
        .confirmationDialog(
            "この学習履歴を削除しますか？",
            isPresented: isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                guard let session = pendingDeletionSession else { return }
                viewModel.deleteSession(session)
                pendingDeletionSession = nil
                editingSession = nil
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した履歴は元に戻せません。")
        }
    }

    private func moveMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: viewModel.displayedMonth) {
            viewModel.displayedMonth = next
        }
    }

    private func selectDefaultDayIfNeeded() {
        guard selectedDay == nil else { return }
        if let todayDay {
            selectedDay = todayDay
            return
        }
        selectedDay = viewModel.monthStudyMap
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted()
            .last
            ?? 1
    }

    private var calendarMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: viewModel.displayedMonth)
    }

    private var calendarSummaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Text(calendarMonthTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer(minLength: 8)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(AppColors.success)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(weekdayColor(label: label, isCurrentMonth: true))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
            }
            .padding(.top, 6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(calendarGridDays) { item in
                    CalendarSummaryDayCell(
                        item: item,
                        isSelected: item.isCurrentMonth && item.day == selectedDay
                    )
                    .onTapGesture {
                        guard item.isCurrentMonth else { return }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                            selectedDay = item.day
                        }
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 8)
        }
        .background(AppColors.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)
        }
    }

    private var calendarSummaryLegend: some View {
        HStack(spacing: 0) {
            CalendarSummaryLegendItem(color: CalendarSummaryDayCell.fillColor(minutes: 0), title: "0分")
            CalendarSummaryLegendItem(color: CalendarSummaryDayCell.fillColor(minutes: 1), title: "1〜29分")
            CalendarSummaryLegendItem(color: CalendarSummaryDayCell.fillColor(minutes: 30), title: "30〜59分")
            CalendarSummaryLegendItem(color: CalendarSummaryDayCell.fillColor(minutes: 60), title: "60〜119分")
            CalendarSummaryLegendItem(color: CalendarSummaryDayCell.fillColor(minutes: 120), title: "120分以上")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private func selectedDayHeader(day: Int, totalMinutes: Int, sessionCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedDateTitle(day: day))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 12)
            Text("合計 \(Goal.format(minutes: totalMinutes)) ・ \(sessionCount)セッション")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }

    @ViewBuilder
    private func summaryRows(_ subjects: [DayStudySubjectSummary]) -> some View {
        let rows = calendarSummaryRows(from: subjects)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Button {
                    if let session = row.material.sessions.first {
                        prepareEditing(session)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(summarySubjectColor(index: index))
                                .frame(width: 19, height: 19)

                            Text(row.subject.subjectName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(width: 82, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(row.material.materialName)
                                .font(.system(size: 17))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Spacer(minLength: 10)

                            Text(Goal.format(minutes: row.material.totalMinutes))
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        if !row.material.problemRecords.isEmpty {
                            Text(problemNumbersText(
                                for: row.material.problemRecords,
                                chapters: problemChapters(for: row.material),
                                limitPerResult: 8
                            ))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .monospacedDigit()
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 35)
                            .padding(.trailing, 26)
                        }
                    }
                    .frame(minHeight: 56)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 12)
    }

    private func monthlySummaryCard(totalMinutes: Int, studyDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(displayMonth)月のまとめ")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("(1〜\(daysInMonth)日)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 8) {
                CalendarMonthlyStatCard(
                    icon: "clock",
                    title: "合計学習時間",
                    value: monthTotalTimeValue(totalMinutes),
                    subtitle: ""
                )

                CalendarMonthlyStatCard(
                    icon: "calendar",
                    title: "学習日数",
                    value: "\(studyDays)日",
                    subtitle: ""
                )

                CalendarMonthlyStatCard(
                    icon: "star",
                    title: "平均評価（5段階）",
                    value: averageRatingText,
                    subtitle: ""
                )
            }
        }
        .padding(12)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .padding(.horizontal, 10)
    }

    private func calendarSummaryRows(
        from subjects: [DayStudySubjectSummary]
    ) -> [(id: String, subject: DayStudySubjectSummary, material: DayStudyMaterialSummary)] {
        subjects.flatMap { subject in
            subject.materials.map { material in
                (id: "\(subject.id)-\(material.id)", subject: subject, material: material)
            }
        }
    }

    private func selectedDateTitle(day: Int) -> String {
        guard let date = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: day)) else {
            return "\(displayMonth)月\(day)日"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    private func weekdayColor(label: String, isCurrentMonth: Bool) -> Color {
        guard isCurrentMonth else { return AppColors.textSecondary.opacity(0.7) }
        if label == "日" { return Color(hex: 0xFF1D25) }
        if label == "土" { return Color(hex: 0x0A63C9) }
        return AppColors.textPrimary
    }

    private func summarySubjectColor(index: Int) -> Color {
        let colors = [
            Color(hex: 0x0B63D8),
            Color(hex: 0xFF1D25),
            Color(hex: 0xFF6B0A),
            AppColors.success,
            AppColors.warning,
            Color(hex: 0x7C3AED)
        ]
        return colors[index % colors.count]
    }

    private func monthTotalTimeValue(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)時間 \(minutes)分"
        }
        return "\(minutes)分"
    }

    private var averageRatingText: String {
        let ratings = viewModel.daySessionsMap.values
            .flatMap { $0 }
            .compactMap(\.rating)
        guard !ratings.isEmpty else { return "-" }
        let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
        return String(format: "%.1f", average)
    }

    private var detailModeSwitch: some View {
        HStack(spacing: 0) {
            ForEach(CalendarDetailDisplayMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        detailDisplayMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(detailDisplayMode == mode ? .white : AppColors.textPrimary.opacity(0.82))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(detailDisplayMode == mode ? AppColors.success : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("表示切替")
    }

    private func subjectSummarySection(_ subject: DayStudySubjectSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(subject.subjectName)
                    .font(.headline.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(Goal.format(minutes: subject.totalMinutes)) · \(subject.materials.count)教材")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
            }
            .padding(.top, AppSpacing.xs)

            ForEach(subject.materials) { material in
                materialSummaryCard(material)
            }
        }
    }

    private func materialSummaryCard(_ material: DayStudyMaterialSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(material.materialName)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(material.sessionCount)セッションを集約")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(Goal.format(minutes: material.totalMinutes))
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            if !material.intervals.isEmpty {
                Label(material.intervals.map(intervalText).joined(separator: " / "), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            if material.wrongProblemCount > 0 || material.reviewCorrectProblemCount > 0 || !material.problemRecords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("問題記録", systemImage: "list.number")
                        Spacer()
                        if material.wrongProblemCount > 0 {
                            Text("不正解 \(material.wrongProblemCount)")
                        }
                        if material.reviewCorrectProblemCount > 0 {
                            Text("復習 \(material.reviewCorrectProblemCount)")
                        }
                    }
                    if !material.problemRecords.isEmpty {
                        Text(problemNumbersText(for: material.problemRecords, chapters: problemChapters(for: material)))
                            .lineLimit(2)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("メモ")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.textSecondary)
                if material.notes.isEmpty {
                    Text("メモはまだありません")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                } else {
                    ForEach(Array(material.notes.enumerated()), id: \.offset) { _, note in
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if material.sessions.count > 1 {
                DisclosureGroup("個別履歴を編集") {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(material.sessions) { session in
                            compactSessionEditRow(session)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .font(.caption.bold())
            } else if let session = material.sessions.first {
                Button {
                    prepareEditing(session)
                } label: {
                    Label("この履歴を編集", systemImage: "square.and.pencil")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .cardStyle()
    }

    private func compactSessionEditRow(_ session: StudySession) -> some View {
        Button {
            prepareEditing(session)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionIntervalText(session).replacingOccurrences(of: "\n", with: " / "))
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(session.sessionType.title) · \(Goal.format(minutes: session.durationMinutes))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                prepareEditing(session)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletionSession = session
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func timelineItemView(_ item: CalendarTimelineItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 2) {
                Text(timeString(from: item.startTime))
                    .font(.system(size: 12, weight: .medium))
                Text("|")
                    .font(.system(size: 12, weight: .medium))
                Text(timeString(from: timelineEndTime(for: item)))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 42, alignment: .top)

            VStack(spacing: 0) {
                Circle()
                    .fill(timelineColor(for: item))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 1)
            }
            .frame(width: 12)
            .frame(minHeight: timelineMinHeight(for: item))

            switch item {
            case .gap(let gap):
                timelineGapCard(gap)
            case .lesson(let lesson):
                timelineLessonCard(lesson)
            case .study(let session):
                sessionCard(session)
            }
        }
    }

    private func timelineGapCard(_ gap: CalendarTimelineGap) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("空き時間")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                Text(durationText(milliseconds: gap.durationMilliseconds))
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: AppSpacing.xs)
            Text("空き \(durationText(milliseconds: gap.durationMilliseconds))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(.systemGray5), in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("空き時間 \(durationText(milliseconds: gap.durationMilliseconds))")
    }

    private func timelineLessonCard(_ lesson: CalendarTimelineLesson) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: 0x8B6DF6))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("時間割の授業")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(lesson.entry.subjectName.isEmpty ? "授業" : lesson.entry.subjectName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                if let courseName = lesson.entry.courseName?.nilIfBlank {
                    Text(courseName)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Text(lesson.period.name)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                Text("授業（\(durationText(milliseconds: lesson.endTime - lesson.startTime))）")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x5E55DB))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0xECE9FF), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("復習済み")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func sessionCard(_ session: StudySession) -> some View {
        Button {
            prepareEditing(session)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(timelineColor(for: .study(session)))
                            .frame(width: 18, height: 18)
                        Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    if !session.materialName.isEmpty {
                        Text(session.materialName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    if let range = session.problemRangeText {
                        Text(range)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textPrimary)
                    } else if let note = session.note?.nilIfBlank {
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(Goal.format(minutes: session.durationMinutes))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                        ratingStars(session.rating)
                    }
                    problemStats(session)
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                }
            }
            .padding(10)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                prepareEditing(session)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletionSession = session
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func timelineEndTime(for item: CalendarTimelineItem) -> Int64 {
        switch item {
        case .gap(let gap):
            return gap.endTime
        case .lesson(let lesson):
            return lesson.endTime
        case .study(let session):
            return session.sessionEndTime
        }
    }

    private func timelineMinHeight(for item: CalendarTimelineItem) -> CGFloat {
        switch item {
        case .gap:
            return 62
        case .lesson:
            return 88
        case .study:
            return 98
        }
    }

    private func timelineColor(for item: CalendarTimelineItem) -> Color {
        switch item {
        case .gap:
            return Color(hex: 0xAEB4BD)
        case .lesson:
            return Color(hex: 0x8B6DF6)
        case .study(let session):
            if let color = viewModel.material(for: session)?.color {
                return Color(hex: color)
            }
            let palette = [Color(hex: 0x1E73D8), AppColors.success, AppColors.orange, AppColors.danger]
            return palette[Int(session.subjectName.hashValue.magnitude % UInt(palette.count))]
        }
    }

    private func ratingStars(_ rating: Int?) -> some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(value <= (rating ?? 0) ? AppColors.warning : Color(hex: 0xAEB4BD))
            }
        }
    }

    private func problemStats(_ session: StudySession) -> some View {
        let correct = session.problemRecords.filter { $0.result == .correct }.count
        let wrong = session.effectiveWrongProblemCount ?? 0
        let review = session.effectiveReviewCorrectProblemCount
        return HStack(spacing: 10) {
            Text("正解")
            Text("\(correct)")
                .foregroundStyle(AppColors.success)
            Text("誤答")
            Text("\(wrong)")
                .foregroundStyle(AppColors.danger)
            Text("復習済")
            Text("\(review)")
                .foregroundStyle(AppColors.orange)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppColors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }

    private var areIntervalDraftsValid: Bool {
        guard !intervalDrafts.isEmpty else { return false }
        let intervals = intervalDrafts.map(\.interval)
        guard intervals.allSatisfy({ $0.endTime > $0.startTime }) else { return false }

        for index in intervals.indices.dropFirst() where intervals[index].startTime < intervals[index - 1].endTime {
            return false
        }
        return true
    }

    private func prepareEditing(_ session: StudySession) {
        intervalDrafts = session.effectiveIntervals.enumerated().map {
            HistorySessionIntervalDraft(interval: $0.element, index: $0.offset)
        }
        noteText = session.note ?? ""
        ratingSelection = session.rating
        problemStartText = session.problemStart.map(String.init) ?? ""
        problemEndText = session.problemEnd.map(String.init) ?? ""
        wrongProblemCountText = session.wrongProblemCount.map(String.init) ?? ""
        editingProblemRecords = session.problemRecords
        problemCountText = initialProblemCountText(for: session)
        editingSession = session
    }

    private func initialProblemCountText(for session: StudySession) -> String {
        let totalProblems = viewModel.materialProblemCount(for: session)
        if totalProblems > 0 {
            return "\(totalProblems)"
        }
        let maxRecordedProblem = session.problemRecords.map(\.number).max() ?? 0
        let count = max(maxRecordedProblem, session.problemEnd ?? 0)
        return count > 0 ? "\(count)" : ""
    }

    private func editingTotalProblems(for session: StudySession) -> Int {
        let materialProblemCount = viewModel.materialProblemCount(for: session)
        if materialProblemCount > 0 {
            return materialProblemCount
        }
        return parseDraftInt(problemCountText)
    }

    private func saveEditingSession(_ session: StudySession) {
        let normalizedRecords = editingProblemRecords.sorted { $0.number < $1.number }
        viewModel.updateSession(
            session,
            intervals: intervalDrafts.map(\.interval),
            note: noteText,
            rating: ratingSelection,
            problemStart: normalizedRecords.first?.number ?? Int(problemStartText),
            problemEnd: normalizedRecords.last?.number ?? Int(problemEndText),
            wrongProblemCount: normalizedRecords.isEmpty ? Int(wrongProblemCountText) : normalizedRecords.filter(\.isWrong).count,
            problemRecords: normalizedRecords
        )
        editingSession = nil
    }

    private func problemChapters(for material: DayStudyMaterialSummary) -> [ProblemChapter] {
        guard let session = material.sessions.first else { return [] }
        return viewModel.materialProblemChapters(for: session)
    }

    private func problemRangeText(for session: StudySession) -> String {
        let chapters = viewModel.materialProblemChapters(for: session)
        if !session.problemRecords.isEmpty {
            let numbers = session.problemRecords.map(\.number).sorted()
            guard let first = numbers.first, let last = numbers.last else { return "範囲未入力" }
            return first == last ? chapters.label(for: first) : "\(chapters.label(for: first)) - \(chapters.label(for: last))"
        }
        guard let start = session.problemStart, let end = session.problemEnd else { return "範囲未入力" }
        return start == end ? chapters.label(for: start) : "\(chapters.label(for: start)) - \(chapters.label(for: end))"
    }

    private func problemNumbersText(
        for records: [ProblemSessionRecord],
        chapters: [ProblemChapter] = [],
        limitPerResult: Int? = nil
    ) -> String {
        let correct = records.filter { $0.result == .correct }.map { chapters.label(for: $0.number) }
        let wrong = records.filter(\.isWrong).map { chapters.label(for: $0.number) }
        let review = records.filter { $0.result == .reviewCorrect }.map { chapters.label(for: $0.number) }
        var parts: [String] = []
        if !wrong.isEmpty {
            parts.append("不正解 \(compactProblemLabels(wrong, limit: limitPerResult))")
        }
        if !correct.isEmpty {
            parts.append("正解 \(compactProblemLabels(correct, limit: limitPerResult))")
        }
        if !review.isEmpty {
            parts.append("復習 \(compactProblemLabels(review, limit: limitPerResult))")
        }
        return parts.joined(separator: " / ")
    }

    private func compactProblemLabels(_ labels: [String], limit: Int?) -> String {
        guard let limit, labels.count > limit else {
            return labels.joined(separator: ", ")
        }
        let visible = labels.prefix(limit).joined(separator: ", ")
        return "\(visible) +\(labels.count - limit)"
    }

    private func timeString(from millis: Int64) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(epochMilliseconds: millis))
    }

    private func intervalText(_ interval: StudySessionInterval) -> String {
        "\(timeString(from: interval.startTime))~\(timeString(from: interval.endTime))"
    }

    private func durationText(milliseconds: Int64) -> String {
        let totalSeconds = max(Int(milliseconds / 1_000), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)時間 \(minutes)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        if minutes > 0 && seconds > 0 {
            return "\(minutes)分 \(seconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(seconds)秒"
    }

    private func sessionIntervalText(_ session: StudySession) -> String {
        session.effectiveIntervals
            .map(intervalText)
            .joined(separator: "\n")
    }
}

private struct CalendarSummaryGridDay: Identifiable, Hashable {
    var date: Date
    var day: Int
    var weekday: Int
    var isCurrentMonth: Bool
    var minutes: Int

    var id: Int64 {
        date.startOfDay.epochMilliseconds
    }
}

private struct CalendarSummaryDayCell: View {
    let item: CalendarSummaryGridDay
    let isSelected: Bool

    var body: some View {
        Text("\(item.day)")
            .font(.system(size: 17, weight: isSelected ? .bold : .regular))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? AppColors.success : Self.fillColor(minutes: item.minutes).opacity(item.isCurrentMonth ? 1 : 0.28))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white, lineWidth: 2)
                        .padding(2)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.success, lineWidth: 2)
                        .padding(0)
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabel("\(item.day)日 \(item.minutes)分")
    }

    static func fillColor(minutes: Int) -> Color {
        switch minutes {
        case 120...:
            return Color(hex: 0x08944A)
        case 60...119:
            return Color(hex: 0x58BE75)
        case 30...59:
            return Color(hex: 0x9EDFB0)
        case 1...29:
            return Color(hex: 0xE8F6EB)
        default:
            return Color(hex: 0xF8F9FA)
        }
    }

    private var textColor: Color {
        guard item.isCurrentMonth else { return AppColors.textSecondary.opacity(0.62) }
        if isSelected { return .white }
        if item.weekday == 1 { return Color(hex: 0xFF1D25) }
        if item.weekday == 7 { return Color(hex: 0x0A63C9) }
        return AppColors.textPrimary
    }
}

private struct CalendarSummaryLegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarMonthlyStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 18)
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer()
                    .frame(width: 18)
            }

            Text(value)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(AppColors.success)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private enum CalendarDetailDisplayMode: String, CaseIterable, Identifiable {
    case summary
    case timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "集計"
        case .timeline: return "時系列"
        }
    }
}
