import SwiftUI

struct SubjectsScreen: View {
    @EnvironmentObject private var store: StudyAppStore
    @State private var draft = SubjectDraft()
    @State private var isPresentingEditor = false
    @State private var editingSubject: Subject?
    @State private var deleteTarget: Subject?

    private var subjectStudyMinutes: [Int64: Int] {
        store.subjectStudyMinutes
    }

    var body: some View {
        List {
            if store.subjects.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "科目が登録されていません",
                    message: "＋ボタンで追加してください"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.subjects) { subject in
                    SubjectRow(
                        subject: subject,
                        studyMinutes: subjectStudyMinutes[subject.id, default: 0]
                    )
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            deleteTarget = subject
                        }

                        Button("編集") {
                            editingSubject = subject
                            draft = SubjectDraft(subject: subject)
                            isPresentingEditor = true
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("科目")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingSubject = nil
                    draft = SubjectDraft()
                    isPresentingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(
            isPresented: $isPresentingEditor,
            onDismiss: {
                editingSubject = nil
                draft = SubjectDraft()
            }
        ) {
            NavigationStack {
                SubjectEditorSheet(draft: $draft, isEditing: editingSubject != nil) {
                    if let editingSubject {
                        store.updateSubject(draft.makeSubject(id: editingSubject.id))
                    } else {
                        store.addSubject(name: draft.name, color: draft.color, icon: draft.icon)
                    }
                    isPresentingEditor = false
                }
            }
        }
        .alert(
            "科目を削除",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { subject in
            Button("削除", role: .destructive) {
                store.deleteSubject(subject)
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: { subject in
            Text("「\(subject.name)」を削除しますか？関連する教材・学習履歴・計画項目も削除されます。")
        }
    }
}

private struct SubjectRow: View {
    let subject: Subject
    let studyMinutes: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: subject.color))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(subject.name.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)

                if studyMinutes > 0 {
                    Text(Goal.format(minutes: studyMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

private struct SubjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: SubjectDraft
    let isEditing: Bool
    let onSave: () -> Void

    private let colors: [Int] = [
        0x4CAF50, 0x2196F3, 0xFF9800, 0xE91E63, 0x9C27B0, 0x00BCD4, 0xFBC02D, 0x795548
    ]

    var body: some View {
        Form {
            TextField("科目名", text: $draft.name)

            Section("カラー") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            draft.color = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                        .opacity(draft.color == color ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker("アイコン", selection: $draft.icon) {
                ForEach(SubjectIcon.allCases) { icon in
                    Label(icon.title, systemImage: icon.systemImage)
                        .tag(Optional(icon))
                }
            }
        }
        .navigationTitle(isEditing ? "科目を編集" : "科目を追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

private struct SubjectDraft {
    var name = ""
    var color = 0x4CAF50
    var icon: SubjectIcon? = .book

    init(subject: Subject? = nil) {
        if let subject {
            name = subject.name
            color = subject.color
            icon = subject.icon
        }
    }

    func makeSubject(id: Int64) -> Subject {
        Subject(id: id, name: name, color: color, icon: icon)
    }
}
