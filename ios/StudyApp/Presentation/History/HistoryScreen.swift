import SwiftUI

struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var editingSession: StudySession?
    @State private var pendingDeletionSession: StudySession?
    @State private var durationDraft = ""
    @State private var noteDraft = ""
    @State private var ratingDraft: Int? = nil
    @State private var problemStartDraft = ""
    @State private var problemEndDraft = ""
    @State private var wrongProblemCountDraft = ""
    @State private var editingProblemRecords: [ProblemSessionRecord] = []
    @State private var problemCountDraft = ""
    @State private var isShowingFilter = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(app: app))
    }

    private var groupedSessions: [(String, [StudySession])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        let grouped = Dictionary(grouping: viewModel.filteredSessions) { session -> String in
            formatter.string(from: session.startDate)
        }
        return grouped.sorted { $0.key > $1.key }
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
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(groupedSessions, id: \.0) { dateLabel, sessions in
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                SectionHeaderView(title: dateLabel, icon: "calendar")
                                    .padding(.horizontal, AppSpacing.md)

                                ForEach(sessions) { session in
                                    HistorySessionCardNew(
                                        session: session,
                                        problemChapters: viewModel.materialProblemChapters(for: session)
                                    )
                                        .padding(.horizontal, AppSpacing.md)
                                        .contextMenu {
                                            Button {
                                                editingSession = session
                                                durationDraft = "\(session.durationMinutes)"
                                                noteDraft = session.note ?? ""
                                                ratingDraft = session.rating
                                                problemStartDraft = session.problemStart.map(String.init) ?? ""
                                                problemEndDraft = session.problemEnd.map(String.init) ?? ""
                                                wrongProblemCountDraft = session.wrongProblemCount.map(String.init) ?? ""
                                                editingProblemRecords = session.problemRecords
                                                problemCountDraft = initialProblemCountText(for: session)
                                            } label: {
                                                Label("編集", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                viewModel.deleteSession(session)
                                            } label: {
                                                Label("削除", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("履歴")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                    Image(systemName: viewModel.filterSubjectId != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $editingSession) { session in
            NavigationStack {
                Form {
                    Section {
                        Text(session.subjectName)
                            .font(.headline)
                        if !session.materialName.isEmpty {
                            Text(session.materialName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("記録") {
                        TextField("学習時間（分）", text: $durationDraft)
                            .keyboardType(.numberPad)
                        SessionRatingSelector(rating: $ratingDraft, allowsClearing: true)
                        problemEditor(for: session)
                        TextField("メモ", text: $noteDraft, axis: .vertical)
                    }
                }
                .navigationTitle("履歴を編集")
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
                                durationMinutes: Int(durationDraft) ?? session.durationMinutes,
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
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func problemEditor(for session: StudySession) -> some View {
        let totalProblems = editingTotalProblems(for: session)
        if totalProblems > 0 {
            let chapters = viewModel.materialProblemChapters(for: session)
            Text(chapters.isEmpty ? "全\(totalProblems)問" : "全\(totalProblems)問 ・ \(chapters.count)章")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProblemTileSelector(
                totalProblems: totalProblems,
                chapters: chapters,
                records: $editingProblemRecords
            )
            Text(problemRecordEditSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                TextField("開始問題", text: $problemStartDraft)
                    .keyboardType(.numberPad)
                TextField("終了問題", text: $problemEndDraft)
                    .keyboardType(.numberPad)
                TextField("不正解", text: $wrongProblemCountDraft)
                    .keyboardType(.numberPad)
            }
        }
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

    private var problemRecordEditSummary: String {
        let done = editingProblemRecords.count
        let correct = editingProblemRecords.filter { $0.result == .correct }.count
        let wrong = editingProblemRecords.filter(\.isWrong).count
        let review = editingProblemRecords.filter { $0.result == .reviewCorrect }.count
        return "選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
    }
}

private struct HistorySessionCardNew: View {
    let session: StudySession
    let problemChapters: [ProblemChapter]

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(.tint.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "book.fill")
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(session.subjectName)
                        .font(.subheadline.bold())
                    if let rating = session.rating {
                        SessionRatingBadge(rating: rating)
                    }
                }
                if !session.materialName.isEmpty {
                    Text(session.materialName)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if session.problemRangeText != nil || session.wrongProblemCount != nil {
                    Text(sessionProblemSummary(session))
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(historyTimeLabel(session))
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text(session.durationFormatted)
                .font(.headline)
                .foregroundStyle(.tint)
        }
        .cardStyle()
    }

    private func historyTimeLabel(_ session: StudySession) -> String {
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "ja_JP")
        tf.dateFormat = "HH:mm"
        return "\(tf.string(from: session.startDate)) - \(tf.string(from: session.endDate))"
    }

    private func sessionProblemSummary(_ session: StudySession) -> String {
        guard !session.problemRecords.isEmpty else {
            return "\(problemRangeText) / 不正解 \(session.effectiveWrongProblemCount ?? 0)"
        }
        let correct = session.problemRecords.filter { $0.result == .correct }.map { problemChapters.label(for: $0.number) }
        let wrong = session.problemRecords.filter(\.isWrong).map { problemChapters.label(for: $0.number) }
        let review = session.problemRecords.filter { $0.result == .reviewCorrect }.map { problemChapters.label(for: $0.number) }
        var parts = [problemRangeText]
        if !wrong.isEmpty {
            parts.append("不正解 \(wrong.map { String(describing: $0) }.joined(separator: ", "))")
        }
        if !correct.isEmpty {
            parts.append("正解 \(correct.map { String(describing: $0) }.joined(separator: ", "))")
        }
        if !review.isEmpty {
            parts.append("復習 \(review.map { String(describing: $0) }.joined(separator: ", "))")
        }
        return parts.joined(separator: " / ")
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
