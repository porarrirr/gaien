import Foundation
import SwiftUI

struct MaterialHistoryScreen: View {
    @StateObject private var viewModel: MaterialHistoryViewModel
    @State private var selectedTab: MaterialDetailTab = .history

    init(app: StudyAppContainer, materialId: Int64) {
        _viewModel = StateObject(wrappedValue: MaterialHistoryViewModel(app: app, materialId: materialId))
    }

    var body: some View {
        Group {
            if let material = viewModel.material {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        MaterialHistorySummaryCard(
                            material: material,
                            subject: viewModel.subject,
                            totalMinutes: viewModel.totalMinutes,
                            sessionCount: viewModel.sessions.count,
                            sessions: viewModel.sessions
                        )
                        detailTabPicker
                        switch selectedTab {
                        case .history:
                            historyList
                        case .problems:
                            MaterialProblemProgressCard(
                                totalProblems: material.effectiveTotalProblems,
                                chapters: material.problemChapters,
                                sessions: viewModel.sessions,
                                reviewRecords: viewModel.problemReviewRecords
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            } else {
                EmptyStateView(
                    icon: "book.closed",
                    title: "教材が見つかりません",
                    description: "教材一覧からもう一度選択してください。"
                )
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(viewModel.material?.name ?? "教材の履歴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
    }

    private var detailTabPicker: some View {
        Picker("表示", selection: $selectedTab) {
            ForEach(MaterialDetailTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("教材詳細の表示切り替え")
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("学習履歴")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("（新しい順）")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button {
                } label: {
                    Label("編集", systemImage: "square.and.pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if viewModel.sessions.isEmpty {
                Text("記録はありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.sessions.enumerated()), id: \.offset) { index, session in
                        MaterialHistorySessionCard(session: session, chapters: viewModel.material?.problemChapters ?? [])
                        if index != viewModel.sessions.count - 1 {
                            Divider()
                                .padding(.leading, 22)
                        }
                    }
                }
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
            }
        }
    }
}

enum MaterialDetailTab: String, CaseIterable, Identifiable {
    case history
    case problems

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "履歴"
        case .problems: return "問題集"
        }
    }

    var systemImage: String {
        switch self {
        case .history: return "calendar"
        case .problems: return "square.grid.3x3.fill"
        }
    }
}

struct MaterialHistorySummaryCard: View {
    let material: Material
    let subject: Subject?
    let totalMinutes: Int
    let sessionCount: Int
    let sessions: [StudySession]

    private var answerRate: Int {
        let totalProblems = material.effectiveTotalProblems
        guard totalProblems > 0 else { return 0 }
        let latestResults = sessions
            .sorted { $0.sessionStartTime < $1.sessionStartTime }
            .reduce(into: [Int: ProblemResult]()) { result, session in
                for record in session.problemRecords {
                    guard (1...totalProblems).contains(record.number) else { continue }
                    result[record.number] = record.result
                }
            }
        let correct = latestResults.values.filter { $0 == .correct || $0 == .reviewCorrect }.count
        return Int((Double(correct) / Double(totalProblems) * 100).rounded())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MaterialBookCoverView(material: material)
                .frame(width: 64, height: 90)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: material.color ?? subject?.color ?? 0x1DBBE8))
                        .frame(width: 11, height: 11)
                    Text(subject?.name ?? "科目未設定")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Text(material.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("正誤率")
                        Spacer()
                        Text("\(answerRate)%")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 8) {
                        AnimatedProgressBar(
                            value: Double(answerRate),
                            total: 100,
                            height: 4,
                            barColor: AppColors.blue,
                            trackColor: Color(.systemGray5)
                        )
                        Text("\(answerRate)%")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                    }
                }

                HStack {
                    Text("問題数（合計）")
                    Spacer()
                    Text("\(material.effectiveTotalProblems)問")
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

}

struct MaterialBookCoverView: View {
    let material: Material

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: 0xFAFAF8), Color(hex: 0xE6EBEC), Color(hex: 0x004257)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(Color(hex: 0xD79B21))
                .frame(width: 24)
                .rotationEffect(.degrees(34))
                .offset(x: 58, y: 18)
            Rectangle()
                .fill(Color(hex: 0x18A8C9))
                .frame(width: 12)
                .rotationEffect(.degrees(34))
                .offset(x: 84, y: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Gold")
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                Text(material.name.replacingOccurrences(of: "Focus Gold", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 5, weight: .semibold))
                    .lineLimit(2)
            }
            .foregroundStyle(Color.black)
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
    }
}

struct MaterialProblemRecordSummaryCard: View {
    let material: Material
    let sessions: [StudySession]
    let reviewRecords: [ProblemReviewRecord]
    let latestStudyDate: Date?
    let totalMinutes: Int

    private var totalProblems: Int {
        material.effectiveTotalProblems
    }

    private var snapshot: MaterialProblemProgressSnapshot {
        MaterialProblemProgressSnapshot(
            sessions: sessions,
            reviewRecords: reviewRecords,
            totalProblems: totalProblems
        )
    }

    private var correctCount: Int { snapshot.correctNumbers.count }
    private var wrongCount: Int { snapshot.wrongNumbers.count }
    private var reviewCorrectCount: Int { snapshot.reviewCorrectNumbers.count }
    private var untouchedCount: Int { max(totalProblems - snapshot.doneNumbers.count, 0) }
    private var answerRate: Int {
        guard totalProblems > 0 else { return 0 }
        return Int((Double(correctCount + reviewCorrectCount) / Double(totalProblems) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("問題集の記録")
                    .font(.system(size: 16, weight: .bold))
                Text("（累計）")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(latestStudyDate.map { "\(dateText($0)) 時点" } ?? "記録なし")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(alignment: .center, spacing: 14) {
                MaterialProblemDonutChart(
                    correct: correctCount,
                    wrong: wrongCount,
                    reviewCorrect: reviewCorrectCount,
                    untouched: untouchedCount
                )
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 8) {
                    legendRow("正解", color: AppColors.success, value: correctCount)
                    legendRow("不正解", color: AppColors.danger, value: wrongCount)
                    legendRow("復習正解", color: AppColors.warning, value: reviewCorrectCount)
                    legendRow("未解答", color: Color(.systemGray3), value: untouchedCount)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 1, height: 82)

                VStack(spacing: 5) {
                    Text("正答率")
                        .font(.system(size: 14))
                    Text("\(answerRate)%")
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                }
                .frame(width: 62)
                .foregroundStyle(AppColors.textPrimary)
            }

            HStack(spacing: 10) {
                MaterialHistoryInfoTile(
                    icon: "checkmark.circle",
                    iconColor: AppColors.blue,
                    title: "正誤率",
                    primary: "\(correctCount + reviewCorrectCount) / \(totalProblems)問",
                    progress: Double(answerRate) / 100,
                    trailing: "\(answerRate)%"
                )
                MaterialHistoryInfoTile(
                    icon: "list.bullet",
                    iconColor: AppColors.success,
                    title: "学習回数",
                    primary: "\(sessions.count)回（総学習時間 \(Goal.format(minutes: totalMinutes))）",
                    progress: nil,
                    trailing: nil
                )
            }
        }
        .padding(16)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func legendRow(_ title: String, color: Color, value: Int) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 56, alignment: .leading)
            Text("\(value)問 (\(percent(value))%)")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
    }

    private func percent(_ value: Int) -> Int {
        guard totalProblems > 0 else { return 0 }
        return Int((Double(value) / Double(totalProblems) * 100).rounded())
    }

    private func dateText(_ date: Date) -> String {
        StudyFormatters.slashDate.string(from: date)
    }
}

struct MaterialProblemDonutChart: View {
    let correct: Int
    let wrong: Int
    let reviewCorrect: Int
    let untouched: Int

    var body: some View {
        ZStack {
            ForEach(segments) { segment in
                PieSliceShape(startFraction: segment.start, endFraction: segment.end)
                    .fill(segment.color)
            }
            Circle()
                .fill(AppColors.cardBackground)
                .frame(width: 44, height: 44)
        }
    }

    private var segments: [PieSegment] {
        let values = [
            PieSegment(id: 0, value: correct, color: AppColors.success),
            PieSegment(id: 1, value: wrong, color: AppColors.danger),
            PieSegment(id: 2, value: reviewCorrect, color: AppColors.warning),
            PieSegment(id: 3, value: untouched, color: Color(.systemGray3))
        ]
        let total = values.reduce(0) { $0 + max($1.value, 0) }
        guard total > 0 else { return [] }
        var start = 0.0
        return values.compactMap { segment in
            guard segment.value > 0 else { return nil }
            let fraction = Double(segment.value) / Double(total)
            let visibleSegment = PieSegment(
                id: segment.id,
                value: segment.value,
                color: segment.color,
                start: start,
                end: min(start + fraction, 1.0)
            )
            start += fraction
            return visibleSegment
        }
    }
}

struct MaterialHistoryInfoTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let primary: String
    let progress: Double?
    let trailing: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                Text(primary)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let progress {
                    HStack(spacing: 7) {
                        AnimatedProgressBar(
                            value: progress,
                            total: 1,
                            height: 4,
                            barColor: AppColors.blue,
                            trackColor: Color(.systemGray5)
                        )
                        if let trailing {
                            Text(trailing)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textPrimary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 51, alignment: .topLeading)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

struct MaterialHistoryMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct MaterialProblemProgressCard: View {
    let totalProblems: Int
    let chapters: [ProblemChapter]
    let sessions: [StudySession]
    let reviewRecords: [ProblemReviewRecord]

    @State private var selectedNumber: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "問題集の進捗", icon: "square.grid.3x3.fill")

            if totalProblems <= 0 {
                EmptyStateView(
                    icon: "number.square",
                    title: "全問題数が未設定です",
                    description: "教材編集から問題数を設定すると、ここに進捗が表示されます。"
                )
                .padding(.vertical, AppSpacing.sm)
            } else {
                LazyVGrid(columns: metricColumns, spacing: AppSpacing.sm) {
                    MaterialHistoryMetric(label: "正解", value: "\(snapshot.correctNumbers.count)")
                    MaterialHistoryMetric(label: "不正解", value: "\(snapshot.wrongNumbers.count)")
                    MaterialHistoryMetric(label: "復習正解", value: "\(snapshot.reviewCorrectNumbers.count)")
                    MaterialHistoryMetric(label: "未実施", value: "\(max(totalProblems - snapshot.doneNumbers.count, 0))")
                }

                HStack(spacing: AppSpacing.sm) {
                    MaterialProblemLegendItem(label: "未着手", color: Color.secondary.opacity(0.12), textColor: AppColors.textSecondary)
                    MaterialProblemLegendItem(label: "正解", color: AppColors.success.opacity(0.18), textColor: AppColors.success)
                    MaterialProblemLegendItem(label: "不正解", color: AppColors.danger.opacity(0.18), textColor: AppColors.danger)
                    MaterialProblemLegendItem(label: "復習正解", color: AppColors.warning.opacity(0.20), textColor: AppColors.warning)
                }

                Text("誤答履歴を含む問題は、赤から黄緑へ寄る5段階の色で復調度を表示します。")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)

                progressGrid

                if !snapshot.wrongNumbers.isEmpty {
                    Text("不正解: \(snapshot.wrongNumbers.sorted().prefix(30).map { chapters.label(for: $0) }.joined(separator: ", "))\(snapshot.wrongNumbers.count > 30 ? " ..." : "")")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    private var snapshot: MaterialProblemProgressSnapshot {
        MaterialProblemProgressSnapshot(
            sessions: sessions,
            reviewRecords: reviewRecords,
            totalProblems: totalProblems
        )
    }

    private var problemRows: [[Int]] {
        guard totalProblems > 0 else { return [] }
        return stride(from: 1, through: totalProblems, by: 5).map { start in
            Array(start...min(start + 4, totalProblems))
        }
    }

    @ViewBuilder
    private var progressGrid: some View {
        if chapters.totalProblemCount > 0 {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(chapterSections, id: \.chapter.id) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(section.chapter.title)
                                .font(.caption.bold())
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("\(section.chapter.problemCount)問")
                                .font(.caption2.bold())
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        ForEach(Array(problemRows(start: section.startGlobalNumber, count: section.chapter.problemCount).enumerated()), id: \.offset) { rowInfo in
                            progressRow(rowInfo.element)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(Array(problemRows.enumerated()), id: \.offset) { rowInfo in
                    progressRow(rowInfo.element)
                }
            }
        }
    }

    private var chapterSections: [MaterialProblemChapterSection] {
        var start = 1
        return chapters.filter { $0.problemCount > 0 }.map { chapter in
            defer { start += chapter.problemCount }
            return MaterialProblemChapterSection(chapter: chapter, startGlobalNumber: start)
        }
    }

    private func problemRows(start: Int, count: Int) -> [[Int]] {
        guard count > 0 else { return [] }
        let end = start + count - 1
        return stride(from: start, through: end, by: 5).map { rowStart in
            Array(rowStart...min(rowStart + 4, end))
        }
    }

    private func progressRow(_ row: [Int]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(row, id: \.self) { number in
                    let item = snapshot.item(for: number)
                    MaterialProblemStatusTile(
                        number: number,
                        label: tileLabel(for: number),
                        showsGlobalNumber: chapters.totalProblemCount > 0,
                        appearance: item.appearance,
                        isSelected: selectedNumber == number,
                        hasDetail: item.detail != nil,
                        hasHistory: !item.entries.isEmpty,
                        isLatestWrong: item.latestResult == .wrong,
                        onTap: {
                            guard !item.entries.isEmpty else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedNumber = selectedNumber == number ? nil : number
                            }
                        }
                    )
                }

                ForEach(0..<emptyTileCount(for: row), id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .aspectRatio(1, contentMode: .fit)
                }
            }

            if let selectedNumber, row.contains(selectedNumber) {
                let item = snapshot.item(for: selectedNumber)
                if !item.entries.isEmpty {
                    MaterialProblemHistoryAccordion(
                        title: chapters.label(for: selectedNumber),
                        entries: item.entries
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func tileLabel(for number: Int) -> String {
        chapters.location(for: number).map { "\($0.localNumber)" } ?? "\(number)"
    }

    private var metricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 2)
    }

    private func emptyTileCount(for row: [Int]) -> Int {
        max(5 - row.count, 0)
    }
}

enum MaterialProblemStatus: Hashable {
    case untouched
    case correct
    case wrong
    case reviewCorrect

    init(result: ProblemResult) {
        switch result {
        case .correct:
            self = .correct
        case .wrong:
            self = .wrong
        case .reviewCorrect:
            self = .reviewCorrect
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .untouched:
            return "未着手"
        case .correct:
            return "正解"
        case .wrong:
            return "不正解"
        case .reviewCorrect:
            return "復習正解"
        }
    }
}

private extension ProblemResult {
    init(reviewRating: ProblemReviewRating) {
        switch reviewRating {
        case .again:
            self = .wrong
        case .good:
            self = .correct
        }
    }
}

struct MaterialProblemAppearance {
    let status: MaterialProblemStatus
    let recoveryStage: MaterialProblemRecoveryStage?
}

struct MaterialProblemProgressSnapshot {
    private let itemsByNumber: [Int: MaterialProblemProgressItem]

    init(sessions: [StudySession], reviewRecords: [ProblemReviewRecord], totalProblems: Int) {
        guard totalProblems > 0 else {
            itemsByNumber = [:]
            return
        }

        var entriesByNumber = sessions.reduce(into: [Int: [ProblemHistoryEntry]]()) { result, session in
            for record in session.problemRecords {
                guard (1...totalProblems).contains(record.number) else { continue }
                result[record.number, default: []].append(
                    ProblemHistoryEntry(
                        date: session.startDate,
                        result: record.result,
                        detail: record.detail?.nilIfBlank,
                        subNumber: record.normalizedSubNumber
                    )
                )
            }
        }

        let sessionEntryKeys = Set(entriesByNumber.flatMap { number, entries in
            entries.map { entry in "\(number)-\(entry.date.epochMilliseconds)-\(entry.result.rawValue)" }
        })
        for review in reviewRecords where (1...totalProblems).contains(review.problemNumber) {
            let result = ProblemResult(reviewRating: review.rating)
            let entryDate = Date(epochMilliseconds: review.reviewedAt)
            let key = "\(review.problemNumber)-\(entryDate.epochMilliseconds)-\(result.rawValue)"
            guard !sessionEntryKeys.contains(key) else { continue }
            entriesByNumber[review.problemNumber, default: []].append(
                ProblemHistoryEntry(
                    date: entryDate,
                    result: result,
                    detail: nil,
                    subNumber: nil
                )
            )
        }

        itemsByNumber = entriesByNumber.mapValues { entries in
            MaterialProblemProgressItem(entries: entries.sorted { $0.date > $1.date })
        }
    }

    var doneNumbers: Set<Int> {
        Set(itemsByNumber.keys)
    }

    var correctNumbers: Set<Int> {
        numbers(matching: .correct)
    }

    var wrongNumbers: Set<Int> {
        numbers(matching: .wrong)
    }

    var reviewCorrectNumbers: Set<Int> {
        numbers(matching: .reviewCorrect)
    }

    func item(for number: Int) -> MaterialProblemProgressItem {
        itemsByNumber[number] ?? MaterialProblemProgressItem(entries: [])
    }

    private func numbers(matching status: MaterialProblemStatus) -> Set<Int> {
        Set(itemsByNumber.compactMap { number, item in
            item.status == status ? number : nil
        })
    }
}

struct MaterialProblemProgressItem {
    let entries: [ProblemHistoryEntry]

    var latestResult: ProblemResult? {
        entries.first?.result
    }

    var status: MaterialProblemStatus {
        latestResult.map(MaterialProblemStatus.init(result:)) ?? .untouched
    }

    var detail: String? {
        entries.first?.detail
    }

    var appearance: MaterialProblemAppearance {
        MaterialProblemAppearance(
            status: status,
            recoveryStage: Self.recoveryStage(for: entries)
        )
    }

    private static func recoveryStage(for entries: [ProblemHistoryEntry]) -> MaterialProblemRecoveryStage? {
        let observedResults = entries.map(\.result)
        let wrongCount = observedResults.filter { $0 == .wrong }.count
        guard wrongCount > 0 else { return nil }

        let positiveScore = observedResults.reduce(0.0) { partialResult, result in
            switch result {
            case .correct:
                return partialResult + 1.0
            case .reviewCorrect:
                return partialResult + 1.15
            case .wrong:
                return partialResult
            }
        }

        guard positiveScore > 0 else { return .allWrong }

        let recoveryRatio = positiveScore / (Double(wrongCount) + positiveScore)
        switch recoveryRatio {
        case ..<0.18:
            return .allWrong
        case ..<0.36:
            return .startingToRecover
        case ..<0.54:
            return .halfRecovered
        case ..<0.74:
            return .mostlyRecovered
        default:
            return .almostStable
        }
    }
}

enum MaterialProblemRecoveryStage: Int {
    case allWrong
    case startingToRecover
    case halfRecovered
    case mostlyRecovered
    case almostStable

    var accentColor: Color {
        switch self {
        case .allWrong:
            return AppColors.danger
        case .startingToRecover:
            return Color(hex: 0xE26631)
        case .halfRecovered:
            return Color(hex: 0xD8902C)
        case .mostlyRecovered:
            return Color(hex: 0xB6A53A)
        case .almostStable:
            return Color(hex: 0x8DBA48)
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .allWrong:
            return "復調度1/5"
        case .startingToRecover:
            return "復調度2/5"
        case .halfRecovered:
            return "復調度3/5"
        case .mostlyRecovered:
            return "復調度4/5"
        case .almostStable:
            return "復調度5/5"
        }
    }
}

struct MaterialProblemLegendItem: View {
    let label: String
    let color: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(textColor.opacity(0.45), lineWidth: 1)
                )
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MaterialProblemStatusTile: View {
    let number: Int
    let label: String
    let showsGlobalNumber: Bool
    let appearance: MaterialProblemAppearance
    let isSelected: Bool
    let hasDetail: Bool
    let hasHistory: Bool
    let isLatestWrong: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.callout.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if showsGlobalNumber {
                Text("#\(number)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(foreground.opacity(0.72))
            }
            HStack(spacing: 4) {
                if hasHistory {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                if hasDetail {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .aspectRatio(1, contentMode: .fit)
        .foregroundStyle(foreground)
        .background(tileBackground)
        .overlay(tileBorder)
        .overlay(alignment: .topTrailing) {
            if isLatestWrong {
                Circle()
                    .fill(AppColors.danger)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    private var tileBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let recoveryStage = appearance.recoveryStage {
            shape.fill(
                LinearGradient(
                    colors: [
                        AppColors.danger.opacity(0.22),
                        recoveryStage.accentColor.opacity(0.26)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            shape.fill(backgroundColor)
        }
    }

    @ViewBuilder
    private var tileBorder: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let recoveryStage = appearance.recoveryStage {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        AppColors.danger.opacity(0.75),
                        recoveryStage.accentColor.opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 2 : 1
            )
        } else {
            shape.strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
        }
    }

    private var backgroundColor: Color {
        switch appearance.status {
        case .untouched:
            return Color.secondary.opacity(0.08)
        case .correct:
            return AppColors.success.opacity(0.18)
        case .wrong:
            return AppColors.danger.opacity(0.18)
        case .reviewCorrect:
            return AppColors.warning.opacity(0.20)
        }
    }

    private var foreground: Color {
        if let recoveryStage = appearance.recoveryStage {
            return recoveryStage.accentColor
        }
        switch appearance.status {
        case .untouched:
            return AppColors.textSecondary
        case .correct:
            return AppColors.success
        case .wrong:
            return AppColors.danger
        case .reviewCorrect:
            return AppColors.warning
        }
    }

    private var borderColor: Color {
        switch appearance.status {
        case .untouched:
            return Color.secondary.opacity(0.15)
        case .correct:
            return AppColors.success.opacity(0.45)
        case .wrong:
            return AppColors.danger.opacity(0.55)
        case .reviewCorrect:
            return AppColors.warning.opacity(0.60)
        }
    }

    private var accessibilityLabel: String {
        let problemName = showsGlobalNumber ? "\(label)問目（通番 \(number)）" : "\(number)問目"
        if let recoveryStage = appearance.recoveryStage {
            return "\(problemName) \(appearance.status.accessibilityTitle) \(recoveryStage.accessibilityTitle)\(isLatestWrong ? " 最新は不正解" : "")"
        }
        return "\(problemName) \(appearance.status.accessibilityTitle)\(isLatestWrong ? " 最新は不正解" : "")"
    }

    private var accessibilityHint: String {
        hasHistory ? "タップで履歴を表示" : "履歴はありません"
    }
}

struct ProblemHistoryEntry: Identifiable {
    let date: Date
    let result: ProblemResult
    let detail: String?
    let subNumber: String?

    var id: String {
        "\(date.timeIntervalSince1970)-\(result.rawValue)-\(subNumber ?? "")-\(detail ?? "")"
    }

    var subNumberLabel: String? {
        subNumber.map { "小問(\($0))" }
    }
}

struct MaterialProblemHistoryAccordion: View {
    let title: String
    let entries: [ProblemHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Label(title, systemImage: "clock.arrow.circlepath")
                    .font(.caption.bold())
                Spacer()
                Text("\(entries.count)回")
                    .font(.caption2.bold())
                    .foregroundStyle(AppColors.textSecondary)
                if let latestEntry = entries.first {
                    Text(latestEntry.result.title)
                        .font(.caption2.bold())
                        .foregroundStyle(color(for: latestEntry.result))
                }
            }

            if let detail = entries.first?.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Divider()
                .overlay(Color.secondary.opacity(0.16))

            ForEach(entries.prefix(6)) { entry in
                HStack(spacing: AppSpacing.xs) {
                    Text(dateText(entry.date))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary)
                    Text(entry.result.title)
                        .font(.caption2.bold())
                        .foregroundStyle(color(for: entry.result))
                    if let subNumberLabel = entry.subNumberLabel {
                        Text(subNumberLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    if let detail = entry.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            if entries.count > 6 {
                Text("他 \(entries.count - 6) 件")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    private func dateText(_ date: Date) -> String {
        StudyFormatters.shortDateTime.string(from: date)
    }

    private func color(for result: ProblemResult) -> Color {
        switch result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }
}

struct MaterialHistoryCalendarView: View {
    let displayedMonth: Date
    let selectedDate: Date
    let studyMinutesByDay: [Int: Int]
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells.indices, id: \.self) { index in
                    if let date = calendarCells[index] {
                        let day = Calendar.current.component(.day, from: date)
                        MaterialHistoryDayCell(
                            day: day,
                            minutes: studyMinutesByDay[day] ?? 0,
                            maxMinutes: studyMinutesByDay.values.max() ?? 0,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        ) {
                            onSelectDate(date)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var monthTitle: String {
        StudyFormatters.yearMonthSpaced.string(from: displayedMonth)
    }

    private var calendarCells: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let days = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        var cells = Array<Date?>(repeating: nil, count: firstWeekday)
        for dayOffset in 0..<days {
            cells.append(calendar.date(byAdding: .day, value: dayOffset, to: firstDay))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }
}

struct MaterialHistoryDayCell: View {
    let day: Int
    let minutes: Int
    let maxMinutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.caption.bold())
                if minutes > 0 {
                    Text("\(minutes)分")
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(isSelected || heatLevel >= 3 ? .white : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heatLevel: Int {
        guard minutes > 0, maxMinutes > 0 else { return 0 }
        let ratio = Double(minutes) / Double(maxMinutes)
        if ratio >= 0.75 { return 4 }
        if ratio >= 0.5 { return 3 }
        if ratio >= 0.25 { return 2 }
        return 1
    }

    private var backgroundColor: Color {
        if isSelected { return .accentColor }
        switch heatLevel {
        case 1: return Color(hex: 0xDDEEDB)
        case 2: return Color(hex: 0x9BD58A)
        case 3: return Color(hex: 0x5AAD5A)
        case 4: return Color(hex: 0x2E7D32)
        default: return Color.secondary.opacity(0.08)
        }
    }
}

struct MaterialHistorySessionCard: View {
    let session: StudySession
    let chapters: [ProblemChapter]

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 9) {
                    Text(dateAndTimeText)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Label("\(session.durationMinutes)分", systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 8)
                    ratingStars
                }

                Text("範囲： \(pageRangeText) \(chapterText)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("問題： \(problemRangeDisplay)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if !wrongNumbersText.isEmpty {
                    Text("不正解： \(wrongNumbersText)")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Text("メモ： \(session.note?.nilIfBlank ?? "メモはありません")")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    countColumn(title: "正解", value: correctCount, color: AppColors.success)
                    countColumn(title: "不正解", value: wrongCount, color: AppColors.danger)
                    countColumn(title: "復習正解", value: reviewCorrectCount, color: AppColors.warning)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 150)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var ratingStars: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= (session.rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(value <= (session.rating ?? 0) ? AppColors.warning : Color(.systemGray2))
            }
        }
    }

    private func countColumn(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(value)")
                .font(.system(size: 15))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(width: 44)
    }

    private var correctCount: Int {
        session.problemRecords.filter { $0.result == .correct }.count
    }

    private var wrongCount: Int {
        if !session.problemRecords.isEmpty {
            return session.problemRecords.filter { $0.result == .wrong }.count
        }
        return session.wrongProblemCount ?? 0
    }

    private var reviewCorrectCount: Int {
        session.problemRecords.filter { $0.result == .reviewCorrect }.count
    }

    private var wrongNumbersText: String {
        session.problemRecords
            .filter { $0.result == .wrong }
            .map { "\($0.number)" }
            .joined(separator: ", ")
    }

    private var dateAndTimeText: String {
        "\(dateText)  \(timeText)"
    }

    private var dateText: String {
        StudyFormatters.slashDateWithWeekday.string(from: session.startDate)
    }

    private var timeText: String {
        let formatter = StudyFormatters.clock
        return "\(formatter.string(from: session.startDate)) - \(formatter.string(from: session.endDate))"
    }

    private var pageRangeText: String {
        guard let range = session.problemRangeText else { return "未入力" }
        let numbers = range
            .replacingOccurrences(of: "問", with: "")
            .split(separator: "-")
            .compactMap { Int(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard let first = numbers.first, let last = numbers.last else { return range }
        return "p.\(pageForProblem(first)) - p.\(pageForProblem(last))"
    }

    private var chapterText: String {
        let numbers = session.problemRecords.map(\.number).sorted()
        guard let first = numbers.first,
              let location = chapters.location(for: first) else {
            return ""
        }
        return "（\(location.chapterTitle)）"
    }

    private var problemRangeDisplay: String {
        if !session.problemRecords.isEmpty {
            let numbers = session.problemRecords.map(\.number).sorted()
            guard let first = numbers.first, let last = numbers.last else { return "未入力" }
            return first == last ? "\(first)" : "\(first)-\(last)"
        }
        guard let range = session.problemRangeText else { return "未入力" }
        return range.replacingOccurrences(of: "問", with: "")
    }

    private func pageForProblem(_ number: Int) -> Int {
        number
    }
}

struct LegacyMaterialHistorySessionCard: View {
    let session: StudySession
    let chapters: [ProblemChapter]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(intervalText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(session.durationJapaneseText)
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
                Spacer()
            }

            Divider()

            Text(session.note?.nilIfBlank ?? "メモはありません")
                .font(.subheadline)
                .foregroundStyle(session.note?.nilIfBlank == nil ? AppColors.textSecondary : AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.problemRangeText != nil || session.wrongProblemCount != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(problemRangeText, systemImage: "list.number")
                        Spacer()
                        Text("不正解 \(session.effectiveWrongProblemCount ?? 0)")
                    }
                    if !session.problemRecords.isEmpty {
                        Text(problemNumbersText(for: session.problemRecords))
                            .lineLimit(2)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }
            if !session.problemRecords.filter({ $0.detail?.nilIfBlank != nil }).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.problemRecords.filter { $0.detail?.nilIfBlank != nil }) { record in
                        Text("\(chapters.label(for: record.number)): \(record.detail ?? "")")
                    }
                }
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }

    private var intervalText: String {
        let formatter = StudyFormatters.clock
        return session.effectiveIntervals.map { interval in
            "\(formatter.string(from: Date(epochMilliseconds: interval.startTime))) - \(formatter.string(from: Date(epochMilliseconds: interval.endTime)))"
        }
        .joined(separator: "\n")
    }

    private func problemNumbersText(for records: [ProblemSessionRecord]) -> String {
        let correct = records.filter { $0.result == .correct }.map { chapters.label(for: $0.number) }
        let wrong = records.filter(\.isWrong).map { chapters.label(for: $0.number) }
        let review = records.filter { $0.result == .reviewCorrect }.map { chapters.label(for: $0.number) }
        var parts: [String] = []
        if !wrong.isEmpty {
            parts.append("不正解 \(wrong.map { String(describing: $0) }.joined(separator: ", "))")
        }
        if !correct.isEmpty {
            parts.append("正解 \(correct.map { String(describing: $0) }.joined(separator: ", "))")
        }
        if !review.isEmpty {
            parts.append("復習 \(review.map { String(describing: $0) }.joined(separator: ", "))")
        }
        return parts.joined(separator: " / ")
    }

    private var problemRangeText: String {
        if !session.problemRecords.isEmpty {
            let numbers = session.problemRecords.map(\.number).sorted()
            guard let first = numbers.first, let last = numbers.last else { return "範囲未入力" }
            return first == last ? chapters.label(for: first) : "\(chapters.label(for: first)) - \(chapters.label(for: last))"
        }
        guard let start = session.problemStart, let end = session.problemEnd else { return session.problemRangeText ?? "範囲未入力" }
        return start == end ? chapters.label(for: start) : "\(chapters.label(for: start)) - \(chapters.label(for: end))"
    }
}

