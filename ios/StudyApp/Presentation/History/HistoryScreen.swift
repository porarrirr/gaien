import SwiftUI

struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var editingSession: StudySession?
    @State private var pendingDeletionSession: StudySession?
    @State private var intervalDrafts: [HistorySessionIntervalDraft] = []
    @State private var noteDraft = ""
    @State private var ratingDraft: Int? = nil
    @State private var problemStartDraft = ""
    @State private var problemEndDraft = ""
    @State private var wrongProblemCountDraft = ""
    @State private var editingProblemRecords: [ProblemSessionRecord] = []
    @State private var problemCountDraft = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(app: app))
    }

    private var groupedSessions: [HistoryDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.filteredSessions) { session in
            calendar.startOfDay(for: session.startDate)
        }
        return grouped
            .map { date, sessions in
                HistoryDayGroup(
                    date: date,
                    sessions: sessions.sorted { $0.sessionStartTime > $1.sessionStartTime }
                )
            }
            .sorted { $0.date > $1.date }
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

    var body: some View {
        Group {
            if viewModel.filteredSessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "学習履歴がありません",
                    description: "タイマーや手動入力で記録した学習履歴がここに表示されます。"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("すべての履歴")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            Menu {
                                Button("すべて") {
                                    viewModel.setFilter(nil)
                                }
                                ForEach(viewModel.subjects) { subject in
                                    Button {
                                        viewModel.setFilter(subject.id)
                                    } label: {
                                        Label(subject.name, systemImage: "circle.fill")
                                    }
                                }
                            } label: {
                                Text("編集")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppColors.success)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, 8)

                        ForEach(groupedSessions) { group in
                            HistoryDaySection(
                                group: group,
                                subjectColor: subjectColor,
                                problemChapters: { viewModel.materialProblemChapters(for: $0) },
                                onEdit: beginEditing,
                                onDelete: { pendingDeletionSession = $0 }
                            )
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSession) { session in
            HistorySessionEditorSheet(
                session: session,
                chapters: viewModel.materialProblemChapters(for: session),
                totalProblems: editingTotalProblems(for: session),
                intervalDrafts: $intervalDrafts,
                note: $noteDraft,
                rating: $ratingDraft,
                problemStart: $problemStartDraft,
                problemEnd: $problemEndDraft,
                wrongProblemCount: $wrongProblemCountDraft,
                problemCount: $problemCountDraft,
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
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private func beginEditing(_ session: StudySession) {
        intervalDrafts = session.effectiveIntervals.enumerated().map {
            HistorySessionIntervalDraft(interval: $0.element, index: $0.offset)
        }
        noteDraft = session.note ?? ""
        ratingDraft = session.rating
        problemStartDraft = session.problemStart.map(String.init) ?? ""
        problemEndDraft = session.problemEnd.map(String.init) ?? ""
        wrongProblemCountDraft = session.wrongProblemCount.map(String.init) ?? ""
        editingProblemRecords = session.problemRecords
        problemCountDraft = initialProblemCountText(for: session)
        editingSession = session
    }

    private func initialProblemCountText(for session: StudySession) -> String {
        let materialProblemCount = viewModel.materialProblemCount(for: session)
        if materialProblemCount > 0 {
            return "\(materialProblemCount)"
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
        return parseDraftInt(problemCountDraft)
    }

    private func subjectColor(for session: StudySession) -> Color {
        if let materialId = session.materialId,
           let material = viewModel.materials.first(where: { $0.id == materialId }),
           let color = material.color {
            return Color(hex: color)
        }
        if let subject = viewModel.subjects.first(where: { $0.id == session.subjectId }) {
            return Color(hex: subject.color)
        }
        return AppColors.blue
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

    private func saveEditingSession(_ session: StudySession) {
        let normalizedRecords = editingProblemRecords.sorted { $0.number < $1.number }
        viewModel.updateSession(
            session,
            intervals: intervalDrafts.map(\.interval),
            note: noteDraft,
            rating: ratingDraft,
            problemStart: normalizedRecords.first?.number ?? Int(problemStartDraft),
            problemEnd: normalizedRecords.last?.number ?? Int(problemEndDraft),
            wrongProblemCount: normalizedRecords.isEmpty ? Int(wrongProblemCountDraft) : normalizedRecords.filter(\.isWrong).count,
            problemRecords: normalizedRecords
        )
        editingSession = nil
    }
}

private struct HistoryDayGroup: Identifiable {
    var id: Int64 {
        date.epochMilliseconds
    }

    let date: Date
    let sessions: [StudySession]

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }
}

private struct HistoryDaySection: View {
    let group: HistoryDayGroup
    let subjectColor: (StudySession) -> Color
    let problemChapters: (StudySession) -> [ProblemChapter]
    let onEdit: (StudySession) -> Void
    let onDelete: (StudySession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateLabel(group.date))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("合計 \(group.sessions.count)セッション ・ \(Goal.format(minutes: group.totalMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.offset) { index, session in
                    HistorySessionCardNew(
                        session: session,
                        subjectColor: subjectColor(session),
                        problemChapters: problemChapters(session),
                        onEdit: { onEdit(session) }
                    )
                    .contextMenu {
                        Button {
                            onEdit(session)
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            onDelete(session)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }

                    if index < group.sessions.count - 1 {
                        Divider()
                            .padding(.leading, 0)
                    }
                }
            }
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        StudyFormatters.yearMonthDayWithWeekday.string(from: date)
    }
}

private struct HistorySessionCardNew: View {
    let session: StudySession
    let subjectColor: Color
    let problemChapters: [ProblemChapter]
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            materialColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .center, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(session.durationMinutes)")
                        .font(.system(size: 27, weight: .semibold))
                    Text("分")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundStyle(AppColors.textPrimary)

                Text(historyTimeLabel(session))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: 82)
            .padding(.horizontal, 6)

            Divider()
                .padding(.vertical, 8)

            reviewColumn
                .frame(width: 150, alignment: .leading)

            Divider()
                .padding(.vertical, 8)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("履歴を編集")
        }
        .padding(.vertical, 14)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 116)
    }

    private var materialColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Circle()
                    .fill(subjectColor)
                    .frame(width: 14, height: 14)

                Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }

            Text(session.materialName.isEmpty ? "教材未設定" : session.materialName)
                .font(.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(problemRangeDisplay)
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.trailing, 12)
    }

    private var reviewColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            StarRatingRow(rating: session.rating ?? 0)

            HStack(spacing: 12) {
                ProblemCountColumn(title: "正解", value: correctProblemCount, color: AppColors.success)
                ProblemCountColumn(title: "不正解", value: wrongProblemCount, color: AppColors.danger)
                ProblemCountColumn(title: "復習正解", value: reviewCorrectProblemCount, color: AppColors.warning)
            }

            if !session.problemRecords.isEmpty {
                problemResultDetails
            }

            Text(noteDisplay)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
    }

    private func historyTimeLabel(_ session: StudySession) -> String {
        let tf = StudyFormatters.clock
        return "\(tf.string(from: session.startDate)) - \(tf.string(from: session.endDate))"
    }

    private var correctProblemCount: Int {
        session.problemRecords.filter { $0.result == .correct }.count
    }

    private var wrongProblemCount: Int {
        session.effectiveWrongProblemCount ?? 0
    }

    private var reviewCorrectProblemCount: Int {
        session.effectiveReviewCorrectProblemCount
    }

    private var noteDisplay: String {
        session.note?.nilIfBlank ?? "メモはありません"
    }

    private var problemResultDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            problemResultLine(title: "正解", color: AppColors.success, result: .correct)
            problemResultLine(title: "不正解", color: AppColors.danger, result: .wrong)
            problemResultLine(title: "復習正解", color: AppColors.warning, result: .reviewCorrect)
        }
    }

    @ViewBuilder
    private func problemResultLine(title: String, color: Color, result: ProblemResult) -> some View {
        let numbers = session.problemRecords
            .filter { $0.result == result }
            .map(\.number)
            .sorted()
            .map { problemChapters.label(for: $0) }
        if !numbers.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 42, alignment: .leading)
                Text(compactProblemNumbers(numbers))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private func compactProblemNumbers(_ numbers: [String]) -> String {
        let visibleLimit = 8
        let visible = numbers.prefix(visibleLimit).joined(separator: ", ")
        let remaining = numbers.count - visibleLimit
        return remaining > 0 ? "\(visible) +\(remaining)" : visible
    }

    private var problemRangeDisplay: String {
        let text = problemRangeText
        if text.hasPrefix("p.") {
            return text
        }
        return text == "範囲未入力" ? text : "p.\(text)"
    }

    private var problemRangeText: String {
        if !session.problemRecords.isEmpty {
            let numbers = session.problemRecords.map(\.number).sorted()
            guard let first = numbers.first, let last = numbers.last else { return "範囲未入力" }
            return first == last ? problemChapters.label(for: first) : "\(problemChapters.label(for: first)) - \(problemChapters.label(for: last))"
        }
        guard let start = session.problemStart, let end = session.problemEnd else { return session.problemRangeText ?? "範囲未入力" }
        return start == end ? problemChapters.label(for: start) : "\(problemChapters.label(for: start)) - \(problemChapters.label(for: end))"
    }
}

private struct StarRatingRow: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(value <= rating ? AppColors.warning : Color(hex: 0xC6CAD1))
            }
        }
        .accessibilityLabel("評価 \(rating) / 5")
    }
}

private struct ProblemCountColumn: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(minWidth: 42, alignment: .leading)
    }
}
