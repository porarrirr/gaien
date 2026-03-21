import SwiftUI

struct SubjectsScreen: View {
    @StateObject private var viewModel: SubjectsViewModel
    @State private var showAddSheet = false
    @State private var editingSubject: Subject?
    @State private var name = ""
    @State private var selectedColor: Color = Color(hex: 0x4CAF50)
    @State private var icon: SubjectIcon = .book

    private let presetColors: [Color] = [
        Color(hex: 0x4CAF50), Color(hex: 0x2196F3), Color(hex: 0xFF9800),
        Color(hex: 0xF44336), Color(hex: 0x9C27B0), Color(hex: 0x00BCD4),
        Color(hex: 0xE91E63), Color(hex: 0x795548), Color(hex: 0x607D8B),
        Color(hex: 0x3F51B5), Color(hex: 0x009688), Color(hex: 0xFFC107)
    ]

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SubjectsViewModel(app: app))
    }

    var body: some View {
        Group {
            if viewModel.subjects.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: "科目がありません",
                    description: "右上の＋ボタンから科目を追加してください。",
                    buttonTitle: "科目を追加",
                    onAction: { resetAndShowAdd() }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.subjects) { subject in
                            subjectRow(subject)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("科目")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    resetAndShowAdd()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                subjectEditorSheet(title: "科目を追加") {
                    let colorInt = colorToInt(selectedColor)
                    viewModel.saveSubject(name: name, color: colorInt, icon: icon)
                    showAddSheet = false
                } onCancel: {
                    showAddSheet = false
                }
            }
        }
        .sheet(item: $editingSubject) { subject in
            NavigationStack {
                subjectEditorSheet(title: "科目を編集") {
                    let colorInt = colorToInt(selectedColor)
                    viewModel.saveSubject(id: subject.id, name: name, color: colorInt, icon: icon)
                    editingSubject = nil
                } onCancel: {
                    editingSubject = nil
                }
            }
        }
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }

    private func subjectRow(_ subject: Subject) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: subject.icon?.systemImage ?? SubjectIcon.book.systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: subject.color), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(subject.name)
                .font(.headline)

            Spacer()

            Circle()
                .fill(Color(hex: subject.color))
                .frame(width: 14, height: 14)
        }
        .cardStyle()
        .contextMenu {
            Button {
                name = subject.name
                selectedColor = Color(hex: subject.color)
                icon = subject.icon ?? .book
                editingSubject = subject
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.deleteSubject(subject)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func subjectEditorSheet(title: String, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        Form {
            Section {
                TextField("科目名", text: $name)
            }

            Section("色") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if colorToInt(color) == colorToInt(selectedColor) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
                .padding(.vertical, AppSpacing.sm)

                ColorPicker("カスタム色", selection: $selectedColor, supportsOpacity: false)
            }

            Section("アイコン") {
                Picker("アイコン", selection: $icon) {
                    ForEach(SubjectIcon.allCases) { ic in
                        Label(ic.rawValue, systemImage: ic.systemImage).tag(ic)
                    }
                }
            }
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

    private func resetAndShowAdd() {
        name = ""
        selectedColor = Color(hex: 0x4CAF50)
        icon = .book
        showAddSheet = true
    }

    private func colorToInt(_ color: Color) -> Int {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
    }
}
