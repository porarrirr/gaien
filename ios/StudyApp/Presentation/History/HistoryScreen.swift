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
                                    HistorySessionCardNew(session: session)
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
                        HStack {
                            TextField("開始問題", text: $problemStartDraft)
                                .keyboardType(.numberPad)
                            TextField("終了問題", text: $problemEndDraft)
                                .keyboardType(.numberPad)
                            TextField("誤答", text: $wrongProblemCountDraft)
                                .keyboardType(.numberPad)
                        }
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
                            viewModel.updateSession(
                                session,
                                durationMinutes: Int(durationDraft) ?? session.durationMinutes,
                                note: noteDraft,
                                rating: ratingDraft,
                                problemStart: Int(problemStartDraft),
                                problemEnd: Int(problemEndDraft),
                                wrongProblemCount: Int(wrongProblemCountDraft)
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
}

private struct HistorySessionCardNew: View {
    let session: StudySession

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
                    Text("\(session.problemRangeText ?? "範囲未入力") / 誤答 \(session.wrongProblemCount ?? 0)")
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
}
