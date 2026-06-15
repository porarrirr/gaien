import Foundation
import SwiftUI

struct LandscapeTimerFocusView: View {
    @ObservedObject var viewModel: TimerViewModel
    let material: Material?
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]
    let totalProblems: Int
    let timerText: String
    let modeText: String
    let progress: Double
    let onPauseToggle: () -> Void
    let onStop: () -> Void

    // 暗背景に映える落ち着いたアクセント（蛍光色を避けた抑えめのグリーン）。
    private let accent = Color(hex: 0x4CAF6E)
    private let stopColor = Color(hex: 0xD9534F)

    private var effectiveTotalProblems: Int {
        materialProblemCount > 0 ? materialProblemCount : totalProblems
    }

    var body: some View {
        GeometryReader { geometry in
            let leftWidth = min(max(geometry.size.width * 0.38, 330), 430)

            HStack(alignment: .top, spacing: 28) {
                timerPane(size: geometry.size)
                    .frame(width: leftWidth)
                    .frame(maxHeight: .infinity)

                problemInputPane(size: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(landscapeBackground)
        .preferredColorScheme(.dark)
    }

    private func problemInputPane(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Text("問題進捗（仮）")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 10)
                progressLegend
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
                    .offset(y: 9)
            }

            if effectiveTotalProblems > 0 {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(landscapeSections.indices, id: \.self) { index in
                            let section = landscapeSections[index]
                            chapterProgressSection(section, availableWidth: rightPaneWidth(for: size))
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 46, height: 2)
                    Text("教材に問題数を設定すると、ここで番号タップ記録を使えます")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 360, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func timerPane(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            subjectCard
                .padding(.bottom, max(18, size.height * 0.08))

            Text(timerText)
                .font(.system(size: timerFontSize(for: size), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.58)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(modeText)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .padding(.bottom, 18)

            progressLine
                .frame(maxWidth: .infinity)

            Text(progressText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 38) {
                focusIconButton(
                    systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                    label: viewModel.isRunning ? "一時停止" : "再開",
                    tint: accent,
                    size: controlButtonSize(for: size),
                    action: onPauseToggle
                )

                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 1, height: min(72, size.height * 0.2))

                focusIconButton(
                    systemImage: "stop.fill",
                    label: "停止",
                    tint: stopColor,
                    size: controlButtonSize(for: size),
                    action: onStop
                )
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                Capsule()
                    .fill(accent)
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 8))
            }
        }
        .frame(height: 10)
    }

    private var landscapeBackground: some View {
        Color(hex: 0x101216)
            .ignoresSafeArea()
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent)
                    .frame(width: 16, height: 16)
                Text(selectedSubjectName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Text(material?.name ?? "教材なし")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var selectedSubjectName: String {
        if let subjectId = viewModel.effectiveSelectedSubjectId,
           let subject = viewModel.subjects.first(where: { $0.id == subjectId }) {
            return subject.name
        }
        return "科目未選択"
    }

    private var progressText: String {
        guard materialProblemCount > 0 else {
            return "\(viewModel.timerProblemRecords.count) ページ"
        }
        let completed = Int((Double(materialProblemCount) * min(max(progress, 0), 1)).rounded())
        return "\(completed) / \(materialProblemCount) ページ"
    }

    private var progressLegend: some View {
        HStack(spacing: 18) {
            legendItem(color: resultColor(.correct), title: "正解")
            legendItem(color: resultColor(.wrong), title: "不正解")
            legendItem(color: unansweredColor, title: "未解答")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    private func chapterProgressSection(_ section: LandscapeProblemSection, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.16))
                )

            LazyVGrid(columns: gridColumns(for: availableWidth), spacing: 8) {
                ForEach(1...section.count, id: \.self) { localNumber in
                    let globalNumber = section.startNumber + localNumber - 1
                    problemProgressTile(globalNumber: globalNumber, label: "\(localNumber)", chapterTitle: section.title)
                }
            }
        }
    }

    private func problemProgressTile(globalNumber: Int, label: String, chapterTitle: String) -> some View {
        let record = viewModel.timerProblemRecords.first { $0.number == globalNumber }

        return LandscapeProblemProgressTile(
            label: label,
            accessibilityLabel: "\(chapterTitle) \(label)問目 \(record?.result.title ?? "未解答")",
            fill: tileFill(for: record),
            border: tileBorder(for: record),
            borderWidth: record == nil ? 1 : 1.5,
            textColor: record == nil ? .white.opacity(0.55) : .white,
            onCorrectTap: { toggleCorrect(globalNumber) },
            onWrongTap: { setResult(.wrong, for: globalNumber) },
            onLongPress: { removeResult(for: globalNumber) }
        )
    }

    private var landscapeSections: [LandscapeProblemSection] {
        if materialProblemChapters.totalProblemCount > 0 {
            var start = 1
            return materialProblemChapters.filter { $0.problemCount > 0 }.map { chapter in
                defer { start += chapter.problemCount }
                return LandscapeProblemSection(
                    title: chapter.title,
                    startNumber: start,
                    count: chapter.problemCount
                )
            }
        }

        guard effectiveTotalProblems > 0 else { return [] }
        return stride(from: 1, through: effectiveTotalProblems, by: 50).map { start in
            let end = min(start + 49, effectiveTotalProblems)
            return LandscapeProblemSection(
                title: "\(start)〜\(end)",
                startNumber: start,
                count: end - start + 1
            )
        }
    }

    private func toggleCorrect(_ number: Int) {
        var records = viewModel.timerProblemRecords
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].result == .correct {
                records.remove(at: index)
            } else {
                records[index].result = .correct
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
        }
        saveLandscapeRecords(records)
    }

    private func setResult(_ result: ProblemResult, for number: Int) {
        var records = viewModel.timerProblemRecords
        if let index = records.firstIndex(where: { $0.number == number }) {
            records[index].result = result
        } else {
            records.append(ProblemSessionRecord(number: number, result: result))
        }
        saveLandscapeRecords(records)
    }

    private func removeResult(for number: Int) {
        var records = viewModel.timerProblemRecords
        records.removeAll { $0.number == number }
        saveLandscapeRecords(records)
    }

    private func saveLandscapeRecords(_ records: [ProblemSessionRecord]) {
        viewModel.updateTimerProblemRecords(
            records.sorted { $0.number < $1.number },
            totalProblems: effectiveTotalProblems
        )
    }

    private func gridColumns(for availableWidth: CGFloat) -> [GridItem] {
        let minimumTileWidth: CGFloat = 54
        let spacing: CGFloat = 8
        let columnCount = max(4, min(7, Int((availableWidth + spacing) / (minimumTileWidth + spacing))))
        return Array(repeating: GridItem(.flexible(minimum: minimumTileWidth), spacing: spacing), count: columnCount)
    }

    private func rightPaneWidth(for size: CGSize) -> CGFloat {
        let leftWidth = min(max(size.width * 0.38, 330), 430)
        return max(280, size.width - leftWidth - 88)
    }

    private func timerFontSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.095, 64), 104)
    }

    private func controlButtonSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.16, 56), 72)
    }

    private func focusIconButton(
        systemImage: String,
        label: String,
        tint: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                    Circle()
                        .stroke(tint.opacity(0.4), lineWidth: 1.5)
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: size, height: size)

                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
    }

    private func tileFill(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return Color.white.opacity(0.06) }
        return resultColor(record.result)
    }

    private func tileBorder(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return .white.opacity(0.18) }
        return resultColor(record.result)
    }

    private func resultColor(_ result: ProblemResult) -> Color {
        switch result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.blue
        }
    }

    private var unansweredColor: Color {
        Color(.systemGray)
    }
}

private struct LandscapeProblemSection {
    let title: String
    let startNumber: Int
    let count: Int
}

private struct LandscapeProblemProgressTile: View {
    let label: String
    let accessibilityLabel: String
    let fill: Color
    let border: Color
    let borderWidth: CGFloat
    let textColor: Color
    let onCorrectTap: () -> Void
    let onWrongTap: () -> Void
    let onLongPress: () -> Void

    @State private var lastTapAt: Date?

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onTapGesture(perform: handleTap)
            .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("タップで正解、すばやく2回タップで不正解、長押しで未解答")
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
}
