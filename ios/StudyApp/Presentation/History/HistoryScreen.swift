import SwiftUI

struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var editingSession: StudySession?
    @State private var durationDraft = ""
    @State private var noteDraft = ""
    @State private var isShowingFilter = false

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.filteredSessions.isEmpty {
                EmptyHistoryState()
            } else {
                List {
                    ForEach(viewModel.filteredSessions) { session in
                        HistorySessionCard(
                            session: session,
                            onEdit: {
                                editingSession = session
                                durationDraft = "\(session.durationMinutes)"
                                noteDraft = session.note ?? ""
                            },
                            onDelete: {
                                viewModel.deleteSession(session)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("履歴")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .confirmationDialog("科目で絞り込む", isPresented: $isShowingFilter, titleVisibility: .visible) {
            Button("すべて") {
                viewModel.setFilter(nil)
            }
            ForEach(viewModel.subjects) { subject in
                Button(subject.name) {
                    viewModel.setFilter(subject.id)
                }
            }
        }
        .sheet(item: $editingSession) { session in
            NavigationStack {
                Form {
                    Text(session.subjectName)
                        .font(.headline)
                    if !session.materialName.isEmpty {
                        Text(session.materialName)
                            .foregroundStyle(.secondary)
                    }
                    TextField("学習時間（分）", text: $durationDraft)
                        .keyboardType(.numberPad)
                    TextField("メモ", text: $noteDraft, axis: .vertical)
                }
                .navigationTitle("履歴を編集")
                .toolbar {
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
                                note: noteDraft
                            )
                            editingSession = nil
                        }
                    }
                }
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }
}

private struct EmptyHistoryState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("学習履歴がありません")
                .font(.title3.bold())
            Text("タイマーや手動入力で記録した学習履歴がここに表示されます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct HistorySessionCard: View {
    let session: StudySession
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.subjectName)
                        .font(.headline)
                    if !session.materialName.isEmpty {
                        Text(session.materialName)
                            .foregroundStyle(.secondary)
                    }
                    Text(historyDateLabel(session))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(session.durationFormatted)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }

            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("編集", action: onEdit)
                    .buttonStyle(.bordered)
                Button("削除", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private func historyDateLabel(_ session: StudySession) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ja_JP")
        dayFormatter.dateFormat = "M月d日"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm"
        return "\(dayFormatter.string(from: session.startDate)) \(timeFormatter.string(from: session.startDate)) - \(timeFormatter.string(from: session.endDate))"
    }
}
