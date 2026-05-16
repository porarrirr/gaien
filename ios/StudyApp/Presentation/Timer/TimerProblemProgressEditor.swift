import Foundation
import SwiftUI

struct TimerProblemProgressEditor: View {
    @Binding var records: [ProblemSessionRecord]
    @Binding var problemCount: String
    let material: Material
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]
    @State private var selectedSectionId = 0
    @State private var editingSubQuestionNumber: Int?
    @State private var editingSubQuestionStatus: TimerSubQuestionStatus = .correct
    @State private var editingSubQuestionLabel = ""
    @State private var editingSubQuestionDetail = ""

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if effectiveProblemCount > 0 {
                sectionSelector

                if let section = selectedProblemSection {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer(minLength: 8)
                            Text(section.rangeText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(AppColors.textSecondary)
                                .monospacedDigit()
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(section.displayStart...section.displayEnd, id: \.self) { displayNumber in
                                timerProblemTile(
                                    globalNumber: section.globalNumber(forDisplayNumber: displayNumber),
                                    label: "\(displayNumber)"
                                )
                            }
                        }
                    }
                }

                Text("※ 章の問題数に基づいて表示しています。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                problemCountControls
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            records.removeAll { $0.number > count }
            clampSelectedSection()
        }
        .onAppear {
            clampSelectedSection()
        }
        .sheet(item: Binding(
            get: { editingSubQuestionNumber.map(TimerSubQuestionEditTarget.init(number:)) },
            set: { if $0 == nil { editingSubQuestionNumber = nil } }
        )) { target in
            NavigationStack {
                Form {
                    Text("大問: \(displayTitle(for: target.number))")
                    TextField("小問（例: 1、(2)、a）", text: $editingSubQuestionLabel)
                    Picker("状態", selection: $editingSubQuestionStatus) {
                        Text("正解").tag(TimerSubQuestionStatus.correct)
                        Text("不正解").tag(TimerSubQuestionStatus.wrong)
                        Text("復習正解").tag(TimerSubQuestionStatus.reviewCorrect)
                    }
                    TextField("メモ（任意）", text: $editingSubQuestionDetail, axis: .vertical)
                }
                .navigationTitle("小問を記録")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { editingSubQuestionNumber = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveSubQuestion(for: target.number)
                            editingSubQuestionNumber = nil
                        }
                        .disabled(editingSubQuestionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var effectiveProblemCount: Int {
        materialProblemCount > 0 ? materialProblemCount : parseDraftInt(problemCount)
    }

    private var problemSections: [TimerProblemSection] {
        if !materialProblemChapters.isEmpty {
            var next = 1
            return materialProblemChapters
                .filter { $0.problemCount > 0 }
                .enumerated()
                .map { index, chapter in
                    let start = next
                    let end = next + chapter.problemCount - 1
                    next = end + 1
                    return TimerProblemSection(
                        id: index,
                        title: chapter.title,
                        start: start,
                        end: end,
                        displayStart: 1,
                        displayEnd: chapter.problemCount,
                        displayTotal: chapter.problemCount,
                        total: effectiveProblemCount
                    )
                }
        }

        guard effectiveProblemCount > 0 else { return [] }
        return stride(from: 1, through: effectiveProblemCount, by: 25).enumerated().map { index, start in
            let end = min(start + 24, effectiveProblemCount)
            return TimerProblemSection(
                id: index,
                title: "第\(index + 1)章",
                start: start,
                end: end,
                displayStart: start,
                displayEnd: end,
                displayTotal: effectiveProblemCount,
                total: effectiveProblemCount
            )
        }
    }

    private var selectedProblemSection: TimerProblemSection? {
        let sections = problemSections
        return sections.first { $0.id == selectedSectionId } ?? sections.first
    }

    @ViewBuilder
    private var sectionSelector: some View {
        let sections = problemSections
        if sections.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections) { section in
                        Button {
                            selectedSectionId = section.id
                        } label: {
                            VStack(spacing: 2) {
                                Text(section.title)
                                    .lineLimit(1)
                                Text("\(section.displayStart)〜\(section.displayEnd)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .font(.caption.bold())
                            .foregroundStyle(selectedSectionId == section.id ? Color.white : AppColors.success)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedSectionId == section.id ? AppColors.success : AppColors.success.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func timerProblemTile(globalNumber: Int, label: String) -> some View {
        Button {
            cycleRecord(globalNumber)
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tileForeground(for: globalNumber))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(tileBackground(for: globalNumber), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(tileBorder(for: globalNumber), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.45) {
            editingSubQuestionNumber = globalNumber
            editingSubQuestionStatus = .correct
            editingSubQuestionLabel = ""
            editingSubQuestionDetail = ""
        }
        .accessibilityLabel("\(label)問目 \(displayRecord(for: globalNumber)?.result.title ?? "未解答")")
        .accessibilityHint("タップで大問の状態を切り替え、長押しで小問を追加")
    }

    private func cycleRecord(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number && $0.normalizedSubNumber == nil }) {
            switch records[index].result {
            case .correct:
                records[index].result = .wrong
            case .wrong:
                records[index].result = .reviewCorrect
            case .reviewCorrect:
                records.remove(at: index)
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
        }
        sortRecords()
    }

    private func saveSubQuestion(for number: Int) {
        let subNumber = editingSubQuestionLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        guard let subNumber else { return }
        let detail = editingSubQuestionDetail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let record = ProblemSessionRecord(
            number: number,
            result: editingSubQuestionStatus.problemResult,
            detail: detail,
            subNumber: subNumber
        )
        records.removeAll { $0.stableKey == record.stableKey }
        records.append(record)
        sortRecords()
    }

    private func sortRecords() {
        records.sort { lhs, rhs in
            lhs.number == rhs.number
                ? (lhs.normalizedSubNumber ?? "") < (rhs.normalizedSubNumber ?? "")
                : lhs.number < rhs.number
        }
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

    private func displayTitle(for number: Int) -> String {
        materialProblemChapters.label(for: number)
    }

    private func tileBackground(for number: Int) -> Color {
        guard let result = displayRecord(for: number)?.result else {
            return AppColors.cardBackground
        }
        switch result {
        case .correct: return AppColors.success.opacity(0.11)
        case .wrong: return AppColors.danger.opacity(0.10)
        case .reviewCorrect: return AppColors.warning.opacity(0.12)
        }
    }

    private func tileForeground(for number: Int) -> Color {
        guard let result = displayRecord(for: number)?.result else {
            return AppColors.textPrimary
        }
        switch result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }

    private func tileBorder(for number: Int) -> Color {
        guard let result = displayRecord(for: number)?.result else {
            return Color(.systemGray5)
        }
        switch result {
        case .correct: return AppColors.success.opacity(0.62)
        case .wrong: return AppColors.danger.opacity(0.62)
        case .reviewCorrect: return AppColors.warning.opacity(0.68)
        }
    }

    private var problemCountControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Button {
                    decrementProblemCount()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(effectiveProblemCount <= 0)

                Text("全\(effectiveProblemCount)問")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)

                Button {
                    setProblemCount(effectiveProblemCount + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach([10, 20, 50], id: \.self) { count in
                    Button("\(count)問") {
                        setProblemCount(count)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.bold())
                }
            }
        }
    }

    private func setProblemCount(_ count: Int) {
        problemCount = "\(max(count, 0))"
    }

    private func decrementProblemCount() {
        setProblemCount(max(effectiveProblemCount - 1, 0))
    }

    private func clampSelectedSection() {
        let sections = problemSections
        guard !sections.isEmpty else {
            selectedSectionId = 0
            return
        }
        if !sections.contains(where: { $0.id == selectedSectionId }) {
            selectedSectionId = sections[0].id
        }
    }
}

private struct TimerProblemSection: Identifiable {
    let id: Int
    let title: String
    let start: Int
    let end: Int
    let displayStart: Int
    let displayEnd: Int
    let displayTotal: Int
    let total: Int

    var rangeText: String {
        "\(displayStart) - \(displayEnd) / \(displayTotal)問"
    }

    func globalNumber(forDisplayNumber displayNumber: Int) -> Int {
        start + displayNumber - displayStart
    }
}



private struct TimerSubQuestionEditTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

private enum TimerSubQuestionStatus: Hashable {
    case correct
    case wrong
    case reviewCorrect

    var problemResult: ProblemResult {
        switch self {
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .reviewCorrect
        }
    }
}
