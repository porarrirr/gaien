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
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.exams) { exam in
                            ExamCard(exam: exam, onEdit: {
                                name = exam.name
                                date = exam.dateValue
                                note = exam.note ?? ""
                                editingExam = exam
                            }, onDelete: {
                                viewModel.deleteExam(exam)
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .strictScreen()
        .navigationTitle("試験")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    name = ""
                    date = Date()
                    note = ""
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 29, weight: .regular))
                        .foregroundStyle(Color(hex: 0x008C2A))
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

    private var daysRemaining: Int { exam.daysRemaining() }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(exam.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 19, height: 19)
                    Text(Self.dateFormatter.string(from: exam.dateValue))
                        .font(.system(size: 18, weight: .regular))
                        .lineLimit(1)
                }
                .foregroundStyle(Color(hex: 0x5F636D))

                if let note = exam.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(hex: 0x5F636D))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer()

            HStack(alignment: .center, spacing: 16) {
                Text(badgeText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(minWidth: 61)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: 0x727680))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 13)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xE4E5EA), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 7, x: 0, y: 2)
        .contextMenu {
            Button { onEdit() } label: { Label("編集", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
        }
    }

    private var badgeText: String {
        if daysRemaining < 0 { return "終了" }
        if daysRemaining == 0 { return "今日" }
        return "あと\(daysRemaining)日"
    }

    private var badgeColor: Color {
        if daysRemaining < 0 { return Color(hex: 0xFF3B30) }
        return Color(hex: 0xFF9500)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy/M/d（E）"
        return formatter
    }()
}

private struct ExamEditorSheet: View {
    @Binding var name: String
    @Binding var date: Date
    @Binding var note: String
    let title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetHeader

                Text("テストの予定を追加します。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 12)
                    .padding(.horizontal, 10)

                ExamTextCard(
                    title: "テスト名",
                    placeholder: "テスト名を入力してください",
                    text: $name,
                    maxLength: 100,
                    minHeight: 128
                )

                dateCard

                ExamMemoCard(note: $note)

                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .semibold))
                    Text("リマインダーや通知は設定で管理できます。")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppColors.blue)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(AppColors.blueSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.blue.opacity(0.28), lineWidth: 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: name) { newValue in
            if newValue.count > 100 {
                name = String(newValue.prefix(100))
            }
        }
        .onChange(of: note) { newValue in
            if newValue.count > 500 {
                note = String(newValue.prefix(500))
            }
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 34, height: 5)

            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.success)

                Spacer()

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("保存", action: onSave)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.success.opacity(isSaveDisabled ? 0.28 : 1))
                    .disabled(isSaveDisabled)
            }
        }
        .padding(.horizontal, 10)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("日付")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            ZStack {
                HStack(spacing: 18) {
                    Image(systemName: "calendar")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 28, height: 28)

                    Text(Self.dateFormatter.string(from: date))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.success)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }

                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .opacity(0.02)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月 d日（E） H:mm"
        return formatter
    }()
}

private struct ExamTextCard: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let maxLength: Int
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.top, 2)
                }

                TextField("", text: $text, axis: .vertical)
                    .font(.system(size: 17))
                    .foregroundStyle(AppColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
            }
            .frame(minHeight: minHeight - 86, alignment: .topLeading)

            HStack {
                Spacer()
                Text("\(text.count) / \(maxLength)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct ExamMemoCard: View {
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("メモ")
                    .font(.system(size: 18, weight: .bold))
                Text("（任意）")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    }

                if note.isEmpty {
                    Text("メモを入力してください")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                }

                TextEditor(text: $note)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(note.count) / 500")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .monospacedDigit()
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
            .frame(minHeight: 122)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}
