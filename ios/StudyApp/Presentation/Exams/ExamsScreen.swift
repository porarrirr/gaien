import Foundation
import SwiftUI

// MARK: - ExamsScreen

struct ExamsScreen: View {
    @StateObject private var viewModel: ExamsViewModel
    @State private var showAddSheet = false
    @State private var editingExam: Exam?
    @State private var name = ""
    @State private var date = Date()
    @State private var note = ""

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ExamsViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.exams.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "テストがありません",
                    description: "右上の＋ボタンからテストを追加してください。",
                    buttonTitle: "テストを追加",
                    onAction: { showAddSheet = true }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.exams) { exam in
                            ExamCard(exam: exam, onEdit: {
                                name = exam.name
                                date = exam.dateValue
                                note = exam.note ?? ""
                                editingExam = exam
                            }, onDelete: {
                                viewModel.deleteExam(exam)
                            })
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("試験")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    name = ""
                    date = Date()
                    note = ""
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                ExamEditorSheet(name: $name, date: $date, note: $note, title: "テストを追加") {
                    viewModel.saveExam(name: name, date: date, note: note)
                    showAddSheet = false
                } onCancel: {
                    showAddSheet = false
                }
            }
        }
        .sheet(item: $editingExam) { exam in
            NavigationStack {
                ExamEditorSheet(name: $name, date: $date, note: $note, title: "テストを編集") {
                    viewModel.saveExam(id: exam.id, name: name, date: date, note: note)
                    editingExam = nil
                } onCancel: {
                    editingExam = nil
                }
            }
        }
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}

private struct ExamCard: View {
    let exam: Exam
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var days: Int { max(exam.daysRemaining(), 0) }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(exam.name)
                    .font(.headline)
                Text(exam.dateValue.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if let note = exam.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            UrgencyBadge(daysRemaining: days)
        }
        .cardStyle()
        .contextMenu {
            Button { onEdit() } label: { Label("編集", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
        }
    }
}

private struct ExamEditorSheet: View {
    @Binding var name: String
    @Binding var date: Date
    @Binding var note: String
    let title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            TextField("テスト名", text: $name)
            DatePicker("日付", selection: $date, displayedComponents: .date)
            TextField("メモ", text: $note, axis: .vertical)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
