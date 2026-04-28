import Foundation
import SwiftUI

// MARK: - CalendarScreen

struct CalendarScreen: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDay: Int? = nil
    @State private var editingSession: StudySession? = nil
    @State private var pendingDeletionSession: StudySession? = nil
    @State private var durationText: String = ""
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
        guard let range = calendar.range(of: .day, in: .month, for: viewModel.displayedMonth) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: 1)) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return weekday - 1 // 0-indexed, Sunday=0
    }

    private var maxMinutes: Int {
        viewModel.monthStudyMap.values.max() ?? 1
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

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Month navigation
                HStack {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text(calendarMonthTitle)
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption.bold())
                            .foregroundStyle(label == "日" ? AppColors.danger : (label == "土" ? Color(hex: 0x2196F3) : AppColors.textSecondary))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                HStack {
                    Spacer()
                    CalendarHeatmapLegend(hasData: !viewModel.monthStudyMap.isEmpty)
                }
                .padding(.horizontal, AppSpacing.md)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<(firstWeekday + daysInMonth), id: \.self) { index in
                        if index < firstWeekday {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        } else {
                            let day = index - firstWeekday + 1
                            CalendarDayCell(
                                day: day,
                                minutes: viewModel.monthStudyMap[day] ?? 0,
                                isToday: day == todayDay,
                                isSelected: day == selectedDay,
                                maxMinutes: maxMinutes
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDay = (selectedDay == day) ? nil : day
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Selected day detail
                if let day = selectedDay {
                    let sessions = viewModel.sessions(for: day)
                    let subjectSummaries = viewModel.subjectSummaries(for: day)
                    let totalMins = viewModel.totalMinutes(for: day)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        // Header with date, total, and count badge
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(displayMonth)月\(day)日")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppColors.textPrimary)
                                if totalMins > 0 {
                                    Text("合計 \(Goal.format(minutes: totalMins)) · \(sessions.count)セッション")
                                        .font(.subheadline)
                                        .foregroundStyle(.tint)
                                }
                            }
                            Spacer()
                            if !sessions.isEmpty {
                                Text("\(sessions.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(.tint, in: Circle())
                            }
                        }

                        if sessions.isEmpty {
                            // Empty state
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
                            .cardStyle()
                        } else {
                            ForEach(subjectSummaries) { subject in
                                subjectSummarySection(subject)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Monthly summary
                let totalMinutes = viewModel.monthStudyMap.values.reduce(0, +)
                let studyDays = viewModel.monthStudyMap.values.filter { $0 > 0 }.count
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "月間サマリー", icon: "chart.bar.fill")
                    HStack(spacing: AppSpacing.sm) {
                        StatCard(icon: "clock.fill", value: Goal.format(minutes: totalMinutes), label: "合計")
                        StatCard(icon: "calendar", value: "\(studyDays)日", label: "学習日数", iconColor: AppColors.success)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("カレンダー")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
        .onChange(of: viewModel.displayedMonth) { _ in
            selectedDay = nil
            editingSession = nil
            Task { await viewModel.load() }
        }
        .sheet(item: $editingSession) { session in
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                                    .font(.headline)
                                if !session.materialName.isEmpty {
                                    Text(session.materialName)
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            Spacer()
                            Text(sessionIntervalText(session))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("学習時間（分）")
                                .font(.subheadline.bold())
                            TextField("学習時間（分）", text: $durationText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("評価")
                                .font(.subheadline.bold())
                            SessionRatingSelector(rating: $ratingSelection, allowsClearing: true)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("問題集の記録")
                                .font(.subheadline.bold())
                            problemRecordEditor(for: session)
                        }

                        TextEditor(text: $noteText)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(AppSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )

                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("履歴を編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            pendingDeletionSession = session
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            editingSession = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let normalizedRecords = editingProblemRecords.sorted { $0.number < $1.number }
                            viewModel.updateSession(
                                session,
                                durationMinutes: Int(durationText) ?? session.durationMinutes,
                                note: noteText,
                                rating: ratingSelection,
                                problemStart: normalizedRecords.first?.number ?? Int(problemStartText),
                                problemEnd: normalizedRecords.last?.number ?? Int(problemEndText),
                                wrongProblemCount: normalizedRecords.isEmpty ? Int(wrongProblemCountText) : normalizedRecords.filter(\.isWrong).count,
                                problemRecords: normalizedRecords
                            )
                            editingSession = nil
                        }
                        .bold()
                    }
                }
            }
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

    private var calendarMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: viewModel.displayedMonth)
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
                        Text(problemNumbersText(for: material.problemRecords))
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

    private func sessionCard(_ session: StudySession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Subject + Duration badge
            HStack {
                Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(session.sessionType.title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                if let rating = session.rating {
                    SessionRatingBadge(rating: rating)
                }
                Text(Goal.format(minutes: session.durationMinutes))
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            // Material name
            if !session.materialName.isEmpty {
                Text(session.materialName)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if session.problemRangeText != nil || session.effectiveWrongProblemCount != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(session.problemRangeText ?? "範囲未入力", systemImage: "list.number")
                        Spacer()
                        Text("不正解 \(session.effectiveWrongProblemCount ?? 0)")
                    }
                    if !session.problemRecords.isEmpty {
                        Text(problemNumbersText(for: session.problemRecords))
                            .lineLimit(2)
                    } else if session.effectiveReviewCorrectProblemCount > 0 {
                        Text("復習 \(session.effectiveReviewCorrectProblemCount)")
                    }
                    ForEach(session.problemRecords.filter { $0.detail?.nilIfBlank != nil }) { record in
                        Text("\(record.number)問目: \(record.detail ?? "")")
                            .lineLimit(2)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            // Time range
            VStack(alignment: .leading, spacing: 2) {
                ForEach(session.effectiveIntervals, id: \.self) { interval in
                    Text("\(timeString(from: interval.startTime))~\(timeString(from: interval.endTime))")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Divider()

            // Memo section – tappable to edit
            Button {
                prepareEditing(session)
            } label: {
                HStack {
                    if let note = session.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("メモはまだありません")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
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
        .cardStyle()
    }

    @ViewBuilder
    private func problemRecordEditor(for session: StudySession) -> some View {
        let totalProblems = editingTotalProblems(for: session)
        if viewModel.materialProblemCount(for: session) > 0 {
            Text("全\(totalProblems)問")
                .font(.caption.bold())
                .foregroundStyle(AppColors.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    TextField("開始問題", text: $problemStartText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("終了問題", text: $problemEndText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("不正解", text: $wrongProblemCountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    TextField("全問題数", text: $problemCountText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    ForEach([10, 20, 50], id: \.self) { count in
                        Button("\(count)問") {
                            problemCountText = "\(count)"
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.bold())
                    }
                }
            }
        }

        if totalProblems > 0 {
            ProblemTileSelector(totalProblems: totalProblems, records: $editingProblemRecords)
            Text(problemRecordEditSummary)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var problemRecordEditSummary: String {
        let done = editingProblemRecords.count
        let correct = editingProblemRecords.filter { $0.result == .correct }.count
        let wrong = editingProblemRecords.filter(\.isWrong).count
        let review = editingProblemRecords.filter { $0.result == .reviewCorrect }.count
        return "タップで正解、ダブルタップで不正解、長押しで復習正解とメモを編集。選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
    }

    private func prepareEditing(_ session: StudySession) {
        durationText = "\(session.durationMinutes)"
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

    private func problemNumbersText(for records: [ProblemSessionRecord]) -> String {
        let correct = records.filter { $0.result == .correct }.map(\.number)
        let wrong = records.filter(\.isWrong).map(\.number)
        let review = records.filter { $0.result == .reviewCorrect }.map(\.number)
        var parts: [String] = []
        if !wrong.isEmpty {
            parts.append("不正解 \(wrong.map(String.init).joined(separator: ", "))")
        }
        if !correct.isEmpty {
            parts.append("正解 \(correct.map(String.init).joined(separator: ", "))")
        }
        if !review.isEmpty {
            parts.append("復習 \(review.map(String.init).joined(separator: ", "))")
        }
        return parts.joined(separator: " / ")
    }

    private func timeString(from millis: Int64) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(epochMilliseconds: millis))
    }

    private func intervalText(_ interval: StudySessionInterval) -> String {
        "\(timeString(from: interval.startTime))~\(timeString(from: interval.endTime))"
    }

    private func sessionIntervalText(_ session: StudySession) -> String {
        session.effectiveIntervals
            .map(intervalText)
            .joined(separator: "\n")
    }
}
