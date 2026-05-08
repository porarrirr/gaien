import SwiftUI

struct BookResultSheet: View {
    let book: BookInfo?
    let subjects: [Subject]
    let fallbackSubjectId: Int64
    let onAdd: (String, Int64, Int, String?) -> Void
    let onClose: () -> Void
    @State private var selectedSubjectId: Int64
    @State private var memo = ""
    @State private var isDescriptionExpanded = false

    init(
        book: BookInfo?,
        subjects: [Subject],
        fallbackSubjectId: Int64,
        onAdd: @escaping (String, Int64, Int, String?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.book = book
        self.subjects = subjects
        self.fallbackSubjectId = fallbackSubjectId
        self.onAdd = onAdd
        self.onClose = onClose
        _selectedSubjectId = State(initialValue: fallbackSubjectId)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                if let book {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("1件の結果が見つかりました")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.top, 20)

                        BookResultSummaryCard(book: book)

                        BookResultDescriptionCard(
                            description: displayDescription(for: book),
                            isExpanded: $isDescriptionExpanded
                        )

                        subjectPickerCard

                        memoCard

                        Button(action: addBook) {
                            HStack(spacing: 16) {
                                Image(systemName: "plus")
                                    .font(.system(size: 31, weight: .light))
                                Text("教材に追加")
                                    .font(.system(size: 19, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppColors.success, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(subjects.isEmpty)
                        .opacity(subjects.isEmpty ? 0.45 : 1)

                        Button(action: onClose) {
                            Text("閉じる")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(AppColors.success)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 22)
                } else {
                    Text("書籍が見つかりませんでした")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 320)
                        .padding(22)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.hidden)
        .tint(AppColors.success)
    }

    private var sheetHeader: some View {
        ZStack {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(.systemGray3))
                    .frame(width: 72, height: 7)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                Divider()
            }

            Text("検索結果")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 23)

            HStack {
                Spacer()
                Button("閉じる", action: onClose)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
            .padding(.horizontal, 22)
            .padding(.top, 23)
        }
        .frame(height: 114)
        .background(Color(.systemBackground))
    }

    private var subjectPickerCard: some View {
        BookResultSectionCard(title: "科目") {
            Menu {
                ForEach(subjects) { subject in
                    Button {
                        selectedSubjectId = subject.id
                    } label: {
                        Text(subject.name)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(selectedSubjectColor)
                        .frame(width: 25, height: 25)

                    Text(selectedSubject?.name ?? "科目を選択")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(.systemGray))
                }
                .padding(.horizontal, 16)
                .frame(height: 70)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var memoCard: some View {
        BookResultSectionCard(title: "メモ（任意）") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $memo)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(minHeight: 124)

                if memo.isEmpty {
                    Text("メモを入力（任意）")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }

            Text("\(memo.count)/200")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
        .onChange(of: memo) { newValue in
            if newValue.count > 200 {
                memo = String(newValue.prefix(200))
            }
        }
    }

    private var selectedSubject: Subject? {
        subjects.first(where: { $0.id == selectedSubjectId }) ?? subjects.first(where: { $0.id == fallbackSubjectId }) ?? subjects.first
    }

    private var selectedSubjectColor: Color {
        Color(hex: selectedSubject?.color ?? 0x1D7FEA)
    }

    private func displayDescription(for book: BookInfo) -> String {
        book.description?.nilIfBlank ?? "内容紹介は取得できませんでした。"
    }

    private func addBook() {
        guard let book else { return }
        let metadataNote = [book.publisher, book.publishedDate].compactMap { $0?.nilIfBlank }.joined(separator: " / ")
        let userMemo = memo.nilIfBlank
        let note: String?
        if let userMemo, !metadataNote.isEmpty {
            note = "\(metadataNote)\n\(userMemo)"
        } else {
            note = userMemo ?? metadataNote.nilIfBlank
        }
        onAdd(book.title, selectedSubject?.id ?? selectedSubjectId, book.pageCount ?? 0, note)
    }
}

private struct BookResultSummaryCard: View {
    let book: BookInfo

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            BookResultCoverView(book: book)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(book.title)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text("新課程")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.blueSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if !book.authors.isEmpty {
                    Text(authorText)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                }

                if let publisher = book.publisher?.nilIfBlank {
                    Text(publisher)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text("総ページ数")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(book.pageCount ?? 0)ページ")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }

    private var authorText: String {
        let joined = book.authors.joined(separator: "、")
        guard !joined.contains("著"), !joined.contains("編") else { return joined }
        return "\(joined) 編著"
    }
}

private struct BookResultCoverView: View {
    let book: BookInfo

    var body: some View {
        Group {
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        generatedCover
                    }
                }
            } else {
                generatedCover
            }
        }
        .frame(width: 96, height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }

    private var thumbnailURL: URL? {
        guard let value = book.thumbnailURL?.nilIfBlank else { return nil }
        return URL(string: value.replacingOccurrences(of: "http://", with: "https://"))
    }

    private var generatedCover: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            VStack(alignment: .leading, spacing: 8) {
                Text("新課程")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AppColors.blue)
                Text(book.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("CHART INSTITUTE")
                    .font(.system(size: 5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(11)

            VStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    PolygonShape(points: [
                        CGPoint(x: 0, y: 0.54),
                        CGPoint(x: 1, y: 0.18),
                        CGPoint(x: 1, y: 1),
                        CGPoint(x: 0, y: 1)
                    ])
                    .fill(AppColors.blue)
                    PolygonShape(points: [
                        CGPoint(x: 0, y: 0.40),
                        CGPoint(x: 0.78, y: 1),
                        CGPoint(x: 0, y: 1)
                    ])
                    .fill(AppColors.blue.opacity(0.62))
                }
                .frame(height: 56)
            }
        }
    }
}

private struct BookResultDescriptionCard: View {
    let description: String
    @Binding var isExpanded: Bool

    var body: some View {
        BookResultSectionCard(title: "内容紹介") {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(7)
                    .lineLimit(isExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    isExpanded.toggle()
                } label: {
                    Text(isExpanded ? "閉じる" : "もっと見る")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.blue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
        }
    }
}

private struct BookResultSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }
}

private struct PolygonShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}
