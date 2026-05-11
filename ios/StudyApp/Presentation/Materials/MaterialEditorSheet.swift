import Foundation
import SwiftUI

struct MaterialEditorSheet: View {
    let title: String
    @Binding var draft: MaterialDraft
    let subjects: [Subject]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if subjects.isEmpty {
                    Text("先に科目を作成してください")
                        .materialEditorCard(padding: 16)
                } else {
                    labeledField(title: "教材名") {
                        MaterialEditorTextField(text: $draft.name, clearable: true)
                    }

                    labeledField(title: "科目") {
                        MaterialSubjectMenu(
                            subjectId: $draft.subjectId,
                            subjects: subjects
                        )
                    }

                    MaterialEditorStatsCard {
                        MaterialEditorNumberRow(
                            title: "総ページ数",
                            text: $draft.totalPages,
                            unit: "ページ"
                        )
                        MaterialEditorDivider()
                        MaterialEditorNumberRow(
                            title: "現在ページ",
                            text: $draft.currentPage,
                            unit: "ページ"
                        )
                        MaterialEditorDivider()
                        MaterialEditorNumberRow(
                            title: "問題数（合計）",
                            text: totalProblemsBinding,
                            unit: "問"
                        )
                        MaterialProblemInfoBox(total: draft.effectiveTotalProblems)
                            .padding(.top, 2)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("章・節ごとの問題数")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        VStack(spacing: 0) {
                            ForEach(draft.problemChapters.indices, id: \.self) { index in
                                MaterialChapterEditorRow(
                                    index: index,
                                    title: $draft.problemChapters[index].title,
                                    problemCount: $draft.problemChapters[index].problemCount,
                                    onDelete: {
                                        draft.problemChapters.remove(at: index)
                                    }
                                )
                                if index < draft.problemChapters.count - 1 {
                                    MaterialEditorDivider()
                                }
                            }

                            Button {
                                if draft.problemChapters.isEmpty,
                                   let total = draft.totalProblems.nilIfBlank {
                                    draft.problemChapters.append(
                                        ProblemChapterDraft(title: "", problemCount: total)
                                    )
                                    draft.totalProblems = ""
                                } else {
                                    draft.problemChapters.append(
                                        ProblemChapterDraft(title: "", problemCount: "")
                                    )
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 22, weight: .medium))
                                    Text("章・節を追加")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundStyle(AppColors.success)
                                .frame(maxWidth: .infinity)
                                .frame(height: 47)
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .top) {
                                MaterialEditorDivider()
                            }
                        }
                        .materialEditorCard(padding: 0)
                    }

                    labeledField(title: "メモ") {
                        MaterialEditorNoteField(text: $draft.note)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 26)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .disabled(subjects.isEmpty)
            }
        }
    }

    private var totalProblemsBinding: Binding<String> {
        Binding(
            get: {
                if !draft.problemChapters.isEmpty {
                    return draft.effectiveTotalProblems == 0 ? "" : "\(draft.effectiveTotalProblems)"
                }
                return draft.totalProblems
            },
            set: { newValue in
                if draft.problemChapters.isEmpty {
                    draft.totalProblems = newValue
                }
            }
        )
    }

    private func labeledField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.leading, 18)
            content()
        }
    }
}

struct MaterialSubjectMenu: View {
    @Binding var subjectId: Int64
    let subjects: [Subject]

    private var selectedSubject: Subject? {
        subjects.first { $0.id == subjectId } ?? subjects.first
    }

    var body: some View {
        Menu {
            ForEach(subjects) { subject in
                Button {
                    subjectId = subject.id
                } label: {
                    Text(subject.name)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: selectedSubject?.color ?? 0x2196F3))
                    .frame(width: 18, height: 18)
                Text(selectedSubject?.name ?? "科目を選択")
                    .font(.system(size: 19))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .frame(height: 58)
            .padding(.horizontal, 16)
            .materialEditorCard(padding: 0)
        }
        .buttonStyle(.plain)
        .onAppear {
            if subjectId == 0, let first = subjects.first {
                subjectId = first.id
            }
        }
    }
}

struct MaterialEditorStatsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .materialEditorCard(padding: 0)
    }
}

struct MaterialEditorNumberRow: View {
    let title: String
    @Binding var text: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
            MaterialEditorTextField(
                text: $text,
                keyboardType: .numberPad,
                alignment: .center,
                clearable: false
            )
            .frame(width: 118, height: 52)
            Text(unit)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 56, alignment: .center)
        }
        .frame(height: 72)
        .padding(.horizontal, 22)
    }
}

struct MaterialChapterEditorRow: View {
    let index: Int
    @Binding var title: String
    @Binding var problemCount: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("第 \(index + 1) 章")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 66, alignment: .leading)
            MaterialEditorTextField(text: $title, clearable: false)
                .frame(height: 50)
            MaterialEditorTextField(
                text: $problemCount,
                keyboardType: .numberPad,
                alignment: .center,
                clearable: false
            )
            .frame(width: 98, height: 50)
            Text("問")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 24)
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color(hex: 0xFF2D2D))
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 44)
        }
        .frame(height: 67)
        .padding(.horizontal, 18)
    }
}

struct MaterialProblemInfoBox: View {
    let total: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppColors.blue)
                .padding(.top, 2)
            Text("問題数は、章・節ごとの問題数の合計が適用されます。\n（現在の合計：\(total) 問）")
                .font(.system(size: 15))
                .lineSpacing(5)
                .foregroundStyle(Color(hex: 0x576071))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.blueSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.blue.opacity(0.28), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }
}

struct MaterialEditorTextField: View {
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var alignment: TextAlignment = .leading
    var clearable = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text)
                .font(.system(size: 21))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(alignment)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
            if clearable && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
        }
    }
}

struct MaterialEditorNoteField: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $text)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 138)
            Text("\(text.count)/300")
                .font(.system(size: 16))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.trailing, 16)
                .padding(.bottom, 13)
        }
        .materialEditorCard(padding: 0)
        .onChange(of: text) { newValue in
            if newValue.count > 300 {
                text = String(newValue.prefix(300))
            }
        }
    }
}

struct MaterialEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.cardBorder)
            .frame(height: 1)
    }
}

struct MaterialEditorCardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

private extension View {
    func materialEditorCard(padding: CGFloat) -> some View {
        modifier(MaterialEditorCardModifier(padding: padding))
    }
}

struct MaterialDraft {
    var name = ""
    var subjectId: Int64 = 0
    var totalPages = ""
    var currentPage = ""
    var totalProblems = ""
    var problemChapters: [ProblemChapterDraft] = []
    var note = ""

    var problemChaptersForSave: [ProblemChapter] {
        problemChapters.map { draft in
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let count = parseDraftInt(draft.problemCount)
            return ProblemChapter(id: draft.id.uuidString.lowercased(), title: title, problemCount: count)
        }
    }

    var effectiveTotalProblems: Int {
        let chapterTotal = problemChaptersForSave.totalProblemCount
        return chapterTotal > 0 ? chapterTotal : parseDraftInt(totalProblems)
    }

    init(subjectId: Int64 = 0) {
        self.subjectId = subjectId
    }

    init(material: Material) {
        name = material.name
        subjectId = material.subjectId
        totalPages = "\(material.totalPages)"
        currentPage = "\(material.currentPage)"
        totalProblems = material.problemChapters.isEmpty && material.totalProblems > 0 ? "\(material.totalProblems)" : ""
        problemChapters = material.problemChapters.map(ProblemChapterDraft.init(chapter:))
        note = material.note ?? ""
    }
}

struct ProblemChapterDraft: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var problemCount: String

    init(title: String, problemCount: String) {
        self.title = title
        self.problemCount = problemCount
    }

    init(chapter: ProblemChapter) {
        id = UUID(uuidString: chapter.id.uppercased()) ?? UUID()
        title = chapter.title
        problemCount = "\(chapter.problemCount)"
    }
}
