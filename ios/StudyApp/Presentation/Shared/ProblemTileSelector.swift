import SwiftUI

struct ProblemTileSelector: View {
    let totalProblems: Int
    var chapters: [ProblemChapter] = []
    @Binding var records: [ProblemSessionRecord]
    @State private var editingNumber: Int?
    @State private var editingStatus: ProblemTileEditStatus = .untouched
    @State private var detailText = ""
    @State private var subNumberText = ""
    @State private var selectedPageIndex = 0

    private let pageSize = 50
    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if effectiveTotalProblems > 0 {
                if chapters.totalProblemCount > 0 {
                    chapterSelector
                    selectedChapterGrid
                } else {
                    pageSelector
                    plainPagedGrid
                }
            }
        }
        .onChange(of: effectiveTotalProblems) { _ in
            clampSelectedGroup()
        }
        .sheet(item: Binding(
            get: { editingNumber.map(ProblemTileEditTarget.init(number:)) },
            set: { if $0 == nil { editingNumber = nil } }
        )) { target in
            NavigationStack {
                Form {
                    Picker("状態", selection: $editingStatus) {
                        Text("未着手").tag(ProblemTileEditStatus.untouched)
                        Text("正解").tag(ProblemTileEditStatus.correct)
                        Text("不正解").tag(ProblemTileEditStatus.wrong)
                    }
                    TextField("小問（任意・例: 1、(2)、a）", text: $subNumberText)
                        .keyboardType(.default)
                    TextField("メモ（例: 計算ミス、解き直し必要）", text: $detailText, axis: .vertical)
                        .keyboardType(.default)
                }
                .navigationTitle(editingTitle(for: target.number))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { editingNumber = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveEditedRecord(number: target.number)
                            editingNumber = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chapterSelector: some View {
        if chapterSections.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chapterSections.indices, id: \.self) { index in
                        let section = chapterSections[index]
                        Button {
                            selectedPageIndex = index
                        } label: {
                            VStack(spacing: 2) {
                                Text(section.chapter.title)
                                    .lineLimit(1)
                                Text("\(section.chapter.problemCount)問")
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .font(.caption.bold())
                            .foregroundStyle(selectedPageIndex == index ? Color.white : Color.accentColor)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedPageIndex == index ? Color.accentColor : Color.accentColor.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var pageSelector: some View {
        if pages.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        let page = pages[index]
                        Button {
                            selectedPageIndex = index
                        } label: {
                            Text("\(page.start)〜\(page.end)")
                                .font(.caption.bold())
                                .monospacedDigit()
                                .foregroundStyle(selectedPageIndex == index ? Color.white : Color.accentColor)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedPageIndex == index ? Color.accentColor : Color.accentColor.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var selectedChapterGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            let section = selectedChapterSection
            HStack {
                Text(section.chapter.title)
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(section.chapter.problemCount)問")
                    .font(.caption2.bold())
                    .foregroundStyle(AppColors.textSecondary)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...section.chapter.problemCount, id: \.self) { localNumber in
                    let globalNumber = section.startGlobalNumber + localNumber - 1
                    problemTile(
                        globalNumber: globalNumber,
                        localLabel: "\(localNumber)",
                        accessibilityPrefix: section.chapter.title
                    )
                }
            }
        }
    }

    private var selectedChapterSection: ProblemChapterSection {
        let sections = chapterSections
        guard !sections.isEmpty else {
            return ProblemChapterSection(
                chapter: ProblemChapter(title: "1章", problemCount: 1),
                startGlobalNumber: 1
            )
        }
        return sections[min(selectedPageIndex, sections.count - 1)]
    }

    private var plainPagedGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(selectedPage.start...selectedPage.end, id: \.self) { number in
                problemTile(
                    globalNumber: number,
                    localLabel: "\(number)",
                    accessibilityPrefix: nil
                )
            }
        }
    }

    private var effectiveTotalProblems: Int {
        let chapterTotal = chapters.totalProblemCount
        return chapterTotal > 0 ? chapterTotal : max(totalProblems, 0)
    }

    private var pages: [ProblemPage] {
        guard effectiveTotalProblems > 0 else { return [] }
        return stride(from: 1, through: effectiveTotalProblems, by: pageSize).map { start in
            ProblemPage(start: start, end: min(start + pageSize - 1, effectiveTotalProblems))
        }
    }

    private var selectedPage: ProblemPage {
        guard !pages.isEmpty else { return ProblemPage(start: 1, end: 1) }
        return pages[min(selectedPageIndex, pages.count - 1)]
    }

    private var chapterSections: [ProblemChapterSection] {
        var start = 1
        return chapters.filter { $0.problemCount > 0 }.map { chapter in
            defer { start += chapter.problemCount }
            return ProblemChapterSection(chapter: chapter, startGlobalNumber: start)
        }
    }

    private func clampSelectedGroup() {
        let count = chapters.totalProblemCount > 0 ? chapterSections.count : pages.count
        guard count > 0 else {
            selectedPageIndex = 0
            return
        }
        if selectedPageIndex >= count {
            selectedPageIndex = count - 1
        }
    }

    private func problemTile(globalNumber: Int, localLabel: String, accessibilityPrefix: String?) -> some View {
        ProblemTile(
            number: globalNumber,
            label: localLabel,
            accessibilityPrefix: accessibilityPrefix,
            record: displayRecord(for: globalNumber),
            onCorrectTap: { toggleCorrect(globalNumber) },
            onWrongTap: { setWrong(globalNumber) },
            onLongPress: {
                let record = records.first { $0.number == globalNumber && $0.normalizedSubNumber == nil }
                if let record {
                    editingStatus = record.result.editStatus
                } else {
                    editingStatus = .untouched
                }
                subNumberText = ""
                detailText = record?.detail ?? ""
                editingNumber = globalNumber
            }
        )
    }

    private func editingTitle(for number: Int) -> String {
        chapters.label(for: number)
    }

    private func displayRecord(for number: Int) -> ProblemSessionRecord? {
        let matching = records.filter { $0.number == number }
        if matching.contains(where: { $0.result == .wrong }) {
            return ProblemSessionRecord(number: number, result: .wrong)
        }
        if matching.contains(where: { $0.result == .reviewCorrect }) {
            return ProblemSessionRecord(number: number, result: .reviewCorrect)
        }
        if matching.contains(where: { $0.result == .correct }) {
            return ProblemSessionRecord(number: number, result: .correct)
        }
        return nil
    }

    private func toggleCorrect(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number && $0.normalizedSubNumber == nil }) {
            if records[index].result == .correct {
                records.remove(at: index)
            } else {
                records[index].result = .correct
            }
            return
        }
        records.append(ProblemSessionRecord(number: number, result: .correct))
        records.sort { lhs, rhs in
            lhs.number == rhs.number
                ? (lhs.normalizedSubNumber ?? "") < (rhs.normalizedSubNumber ?? "")
                : lhs.number < rhs.number
        }
    }

    private func setWrong(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number && $0.normalizedSubNumber == nil }) {
            records[index].result = .wrong
            return
        }
        records.append(ProblemSessionRecord(number: number, result: .wrong))
        records.sort { lhs, rhs in
            lhs.number == rhs.number
                ? (lhs.normalizedSubNumber ?? "") < (rhs.normalizedSubNumber ?? "")
                : lhs.number < rhs.number
        }
    }

    private func saveEditedRecord(number: Int) {
        let trimmedDetail = detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubNumber = subNumberText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let targetKey = ProblemSessionRecord(number: number, result: .correct, subNumber: trimmedSubNumber).stableKey
        records.removeAll { $0.stableKey == targetKey }
        guard editingStatus != .untouched else { return }
        records.append(
            ProblemSessionRecord(
                number: number,
                result: editingStatus.problemResult ?? .correct,
                detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
                subNumber: trimmedSubNumber
            )
        )
        records.sort { lhs, rhs in
            lhs.number == rhs.number
                ? (lhs.normalizedSubNumber ?? "") < (rhs.normalizedSubNumber ?? "")
                : lhs.number < rhs.number
        }
    }
}

private enum ProblemTileEditStatus: Hashable {
    case untouched
    case correct
    case wrong

    var problemResult: ProblemResult? {
        switch self {
        case .untouched: return nil
        case .correct: return .correct
        case .wrong: return .wrong
        }
    }
}

private extension ProblemResult {
    var editStatus: ProblemTileEditStatus {
        switch self {
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .correct
        }
    }
}

private struct ProblemTileEditTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

private struct ProblemChapterSection {
    let chapter: ProblemChapter
    let startGlobalNumber: Int
}

private struct ProblemPage {
    let start: Int
    let end: Int
}

private struct ProblemTile: View {
    let number: Int
    let label: String
    let accessibilityPrefix: String?
    let record: ProblemSessionRecord?
    let onCorrectTap: () -> Void
    let onWrongTap: () -> Void
    let onLongPress: () -> Void

    @State private var lastTapAt: Date?

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.callout.bold())
                .monospacedDigit()
            if accessibilityPrefix != nil {
                Text("#\(number)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(foreground.opacity(0.72))
            }
            if record?.detail?.nilIfBlank != nil {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .aspectRatio(1, contentMode: .fit)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: handleTap)
        .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("タップで正解、すばやく2回タップで不正解、長押しで状態とメモを編集")
    }

    private func handleTap() {
        let now = Date()
        if let lastTapAt, now.timeIntervalSince(lastTapAt) < 0.28 {
            self.lastTapAt = nil
            onWrongTap()
            return
        }
        lastTapAt = now
        onCorrectTap()
    }

    private var background: Color {
        guard let record else { return Color.secondary.opacity(0.08) }
        switch record.result {
        case .correct: return Color.accentColor.opacity(0.16)
        case .wrong: return AppColors.danger.opacity(0.18)
        case .reviewCorrect: return AppColors.warning.opacity(0.20)
        }
    }

    private var foreground: Color {
        guard let record else { return AppColors.textSecondary }
        switch record.result {
        case .correct: return Color.accentColor
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }

    private var border: Color {
        guard let record else { return Color.secondary.opacity(0.15) }
        switch record.result {
        case .correct: return Color.accentColor.opacity(0.45)
        case .wrong: return AppColors.danger.opacity(0.55)
        case .reviewCorrect: return AppColors.warning.opacity(0.60)
        }
    }

    private var accessibilityLabel: String {
        let prefix = accessibilityPrefix.map { "\($0) \(label)問目" } ?? "\(number)問目"
        guard let record else { return "\(prefix) 未着手" }
        return "\(prefix) \(record.result.title)"
    }
}
