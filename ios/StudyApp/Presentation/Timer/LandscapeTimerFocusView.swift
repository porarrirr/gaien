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

    private var effectiveTotalProblems: Int {
        materialProblemCount > 0 ? materialProblemCount : totalProblems
    }

    private var completionText: String {
        let done = viewModel.timerProblemRecords.count
        let wrong = viewModel.timerProblemRecords.filter(\.isWrong).count
        let review = viewModel.timerProblemRecords.filter { $0.result == .reviewCorrect }.count
        if review > 0 {
            return "\(done)問 / 不正解 \(wrong) / 復習 \(review)"
        }
        return "\(done)問 / 不正解 \(wrong)"
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
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 10)
                progressLegend
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.16))
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
                .font(.system(size: timerFontSize(for: size), weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerTextGradient)
                .shadow(color: .white.opacity(0.22), radius: 2, x: 0, y: 1)
                .minimumScaleFactor(0.58)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(modeText)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x36E255))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .padding(.bottom, 18)

            progressLine
                .frame(maxWidth: .infinity)

            Text(progressText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 38) {
                focusIconButton(
                    systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                    label: "一時停止",
                    tint: Color(hex: 0x43D648),
                    foreground: .white,
                    size: controlButtonSize(for: size),
                    action: onPauseToggle
                )

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: min(88, size.height * 0.24))

                focusIconButton(
                    systemImage: "stop.fill",
                    label: "停止",
                    tint: Color(hex: 0x2C2C2E),
                    foreground: .white,
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
                    .fill(.white.opacity(0.16))
                Capsule()
                    .fill(progressGradient)
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 10))
            }
        }
        .frame(height: 13)
    }

    private var materialProgressSubtitle: String {
        if materialProblemCount > 0 {
            if materialProblemChapters.isEmpty {
                return "全\(materialProblemCount)問"
            }
            return "全\(materialProblemCount)問 ・ \(materialProblemChapters.count)章"
        }
        return "タップで正解、すばやく2回タップで不正解、長押しで詳細"
    }

    private var landscapeBackground: some View {
        Color.black
        .ignoresSafeArea()
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: 0x40DB4E))
                    .frame(width: 22, height: 22)
                Text(selectedSubjectName)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x45EA57))
                    .lineLimit(1)
            }
            Text(material?.name ?? "教材なし")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x111113).opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
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
            legendItem(color: resultColor(.reviewCorrect), title: "復習正解")
            legendItem(color: unansweredColor, title: "未解答")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func chapterProgressSection(_ section: LandscapeProblemSection, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(chapterLabelGradient)
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
            shadow: tileShadow(for: record),
            borderWidth: record == nil ? 1.5 : 2,
            onCorrectTap: { toggleCorrect(globalNumber) },
            onWrongTap: { setResult(.wrong, for: globalNumber) },
            onLongPress: { cycleDetailedResult(for: globalNumber) }
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

    private func cycleDetailedResult(for number: Int) {
        let current = viewModel.timerProblemRecords.first { $0.number == number }?.result
        switch current {
        case .reviewCorrect:
            removeResult(for: number)
        default:
            setResult(.reviewCorrect, for: number)
        }
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
        min(max(size.width * 0.105, 72), 120)
    }

    private func controlButtonSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.22, 86), 112)
    }

    private func focusIconButton(
        systemImage: String,
        label: String,
        tint: Color,
        foreground: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint)
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 2)
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.36, weight: .black))
                        .foregroundStyle(foreground)
                }
                .frame(width: size, height: size)
                .shadow(color: tint.opacity(0.44), radius: 7, x: 0, y: 0)

                Text(label)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var timerTextGradient: LinearGradient {
        LinearGradient(
            colors: [.white, Color(hex: 0xE9E9EA), .white],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x58D957), Color(hex: 0x45C949)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var chapterLabelGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x148918), Color(hex: 0x0A4C12)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func tileFill(for record: ProblemSessionRecord?) -> LinearGradient {
        let baseColor = record.map { resultColor($0.result) } ?? unansweredColor
        return LinearGradient(
            colors: [
                baseColor.opacity(record == nil ? 0.70 : 0.92),
                baseColor.opacity(record == nil ? 0.42 : 0.70)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func tileBorder(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return .white.opacity(0.22) }
        return resultColor(record.result).opacity(0.95)
    }

    private func tileShadow(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return .clear }
        return resultColor(record.result).opacity(0.30)
    }

    private func resultColor(_ result: ProblemResult) -> Color {
        switch result {
        case .correct: return Color(hex: 0x22B52B)
        case .wrong: return Color(hex: 0xEF493D)
        case .reviewCorrect: return Color(hex: 0x2D83E6)
        }
    }

    private var unansweredColor: Color {
        Color(hex: 0x3A3A3C)
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
    let fill: LinearGradient
    let border: Color
    let shadow: Color
    let borderWidth: CGFloat
    let onCorrectTap: () -> Void
    let onWrongTap: () -> Void
    let onLongPress: () -> Void

    @State private var lastTapAt: Date?

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
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
            .shadow(color: shadow, radius: 4, x: 0, y: 0)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onTapGesture(perform: handleTap)
            .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("タップで正解、すばやく2回タップで不正解、長押しで復習正解")
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

