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
                    VStack(alignment: .leading, spacing: 18) {
                        Text("科目一覧")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.leading, 3)

                        subjectListCard

                        reorderHintCard
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 23)
                    .padding(.bottom, 28)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("科目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    resetAndShowAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .regular))
                }
                .foregroundStyle(AppColors.success)
            }
        }
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private var subjectListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.subjects.enumerated()), id: \.element.id) { index, subject in
                subjectRow(subject)
                if index < viewModel.subjects.count - 1 {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var reorderHintCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 26, height: 26)

            Text("科目の並び順はドラッグ＆ドロップで変更できます。")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func subjectRow(_ subject: Subject) -> some View {
        HStack(spacing: 14) {
            Image(systemName: subject.icon?.systemImage ?? SubjectIcon.book.systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(hex: subject.color), in: Circle())

            Text(subject.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            Circle()
                .fill(Color(hex: subject.color))
                .frame(width: 13, height: 13)
                .frame(width: 42, alignment: .center)

            HStack(spacing: 16) {
                Button {
                    name = subject.name
                    selectedColor = Color(hex: subject.color)
                    icon = subject.icon ?? .book
                    editingSubject = subject
                } label: {
                    rowActionLabel(title: "編集", systemImage: "pencil", color: AppColors.success)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    viewModel.deleteSubject(subject)
                } label: {
                    rowActionLabel(title: "削除", systemImage: "trash", color: Color(hex: 0xFF2D2D))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .contentShape(Rectangle())
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

    private func rowActionLabel(title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(color)
    }

    @ViewBuilder
    private func subjectEditorSheet(title: String, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "科目名", icon: "textformat")
                    TextField("例）数学III", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "色", icon: "paintpalette.fill")
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
                    ColorPicker("カスタム色", selection: $selectedColor, supportsOpacity: false)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "アイコン", icon: "square.grid.2x2")
                    Picker("アイコン", selection: $icon) {
                        ForEach(SubjectIcon.allCases) { ic in
                            Label(ic.rawValue, systemImage: ic.systemImage).tag(ic)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .cardStyle()
            }
            .padding(AppSpacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.subtleBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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
