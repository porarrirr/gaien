import Foundation
import SwiftUI

struct IsbnSearchSheet: View {
    @Binding var isbn: String
    let onScan: () -> Void
    let onSearch: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ISBN検索")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.bottom, 14)

                isbnInputCard
                    .padding(.bottom, 24)

                scanButton
                    .padding(.bottom, 16)

                Text("ISBNコードは書籍の裏表紙のバーコード付近に記載されています")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.top, 28)
            .padding(.horizontal, 22)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .tint(AppColors.success)
        .navigationTitle("ISBN検索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる", action: onClose)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("検索", action: onSearch)
                    .disabled(isbn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var isbnInputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                Text("ISBN")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 76, alignment: .leading)

                TextField("例）978406XXXXXXX", text: $isbn)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .tint(AppColors.success)
            }
            .padding(.top, 8)

            Divider()
                .background(Color(.systemGray3))

            Text("ハイフンなしの13桁または10桁のISBNを入力してください")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }

    private var scanButton: some View {
        Button {
            onScan()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 27, weight: .medium))

                Text("バーコードをスキャン")
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(AppColors.success)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.success.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MaterialCardNew: View {
    let material: Material
    let subjectName: String
    let subjectColor: Int
    let progressSummary: MaterialListProgressSummary?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onOpenHistory: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let accent = Color(hex: material.color ?? subjectColor)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accent)
                                .frame(width: 14, height: 14)
                            Text(subjectName.isEmpty ? "科目なし" : subjectName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Text(material.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Button(action: onMoveUp) {
                            Label("上へ移動", systemImage: "arrow.up")
                        }
                        .disabled(!canMoveUp)
                        Button(action: onMoveDown) {
                            Label("下へ移動", systemImage: "arrow.down")
                        }
                        .disabled(!canMoveDown)
                        Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 34, height: 28)
                    }
                }

                if hasProblemTracking {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("正誤率")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer(minLength: 8)
                                Text(answerAccuracyText)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .monospacedDigit()
                            }

                            HStack(spacing: 8) {
                                AnimatedProgressBar(
                                    value: Double(answerAccuracyPercent),
                                    total: 100,
                                    height: 7,
                                    barColor: accent,
                                    trackColor: Color(.systemGray5)
                                )
                                Text("\(answerAccuracyPercent)%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                            }

                            HStack {
                                Text("問題数")
                                Text("\(material.effectiveTotalProblems)問")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(chapterText)
                                Spacer(minLength: 8)
                                Text("進捗")
                                Text("\(progressSummary?.progressedCount ?? 0)問")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.success)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary)
                        }

                        MaterialPageProgressRing(
                            progress: Double(answerAccuracyPercent) / 100,
                            color: accent
                        )
                        .frame(width: 78, height: 78)
                    }
                }
            }
            .padding(12)

            if hasProblemTracking {
                Divider()

                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 8) {
                        MaterialCountTile(title: "正解", value: progressSummary?.correctCount ?? 0, color: AppColors.success)
                        MaterialCountTile(title: "誤答", value: progressSummary?.wrongCount ?? 0, color: AppColors.danger)
                        MaterialCountTile(title: "復習済", value: progressSummary?.reviewCorrectCount ?? 0, color: AppColors.warning)
                    }
                    .frame(maxWidth: .infinity)

                    if let progressSummary {
                        MaterialProblemPieChart(summary: progressSummary)
                            .frame(width: 58, height: 58)
                        MaterialProblemLegend(summary: progressSummary)
                            .frame(width: 92)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider()

            HStack(spacing: 10) {
                MaterialCardActionButton(title: "履歴", systemImage: "clock", color: AppColors.success, action: onOpenHistory)
                MaterialCardActionButton(title: "編集", systemImage: "pencil", color: AppColors.success, action: onEdit)
                Spacer(minLength: 4)
                MaterialIconOnlyButton(systemImage: "arrow.up", color: AppColors.success, disabled: !canMoveUp, action: onMoveUp)
                MaterialIconOnlyButton(systemImage: "arrow.down", color: AppColors.success, disabled: !canMoveDown, action: onMoveDown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var answerAccuracyPercent: Int {
        progressSummary?.answerAccuracyPercent ?? 0
    }

    private var answerAccuracyText: String {
        guard let progressSummary, progressSummary.totalProblems > 0 else { return "記録なし" }
        return "\(progressSummary.correctCount + progressSummary.reviewCorrectCount) / \(progressSummary.totalProblems) 問"
    }

    private var hasProblemTracking: Bool {
        material.effectiveTotalProblems > 0
    }

    private var chapterText: String {
        material.problemChapters.isEmpty ? "" : "（全\(material.problemChapters.count)章）"
    }
}

struct MaterialPageProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                Text("正誤率")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
    }
}

struct MaterialCountTile: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
            Text("\(value)問")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

struct MaterialProblemLegend: View {
    let summary: MaterialListProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow("正解", color: AppColors.success, percent: summary.correctPercent)
            legendRow("誤答", color: AppColors.danger, percent: summary.wrongPercent)
            legendRow("復習正解", color: AppColors.warning, percent: summary.reviewCorrectPercent)
            legendRow("未解答", color: Color(.systemGray3), percent: summary.untouchedPercent)
        }
    }

    private func legendRow(_ title: String, color: Color, percent: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("\(percent)%")
                .font(.caption2)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
    }
}

struct MaterialProblemPieChart: View {
    let summary: MaterialListProgressSummary

    var body: some View {
        ZStack {
            ForEach(segments) { segment in
                PieSliceShape(startFraction: segment.start, endFraction: segment.end)
                    .fill(segment.color)
            }
            Circle()
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        }
    }

    private var segments: [PieSegment] {
        guard summary.totalProblems > 0 else { return [] }
        var start = 0.0
        return [
            PieSegment(id: 0, value: summary.correctCount, color: AppColors.success),
            PieSegment(id: 1, value: summary.wrongCount, color: AppColors.danger),
            PieSegment(id: 2, value: summary.reviewCorrectCount, color: AppColors.warning),
            PieSegment(id: 3, value: summary.untouchedCount, color: Color(.systemGray3))
        ].compactMap { segment in
            guard segment.value > 0 else { return nil }
            let fraction = Double(segment.value) / Double(summary.totalProblems)
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

struct MaterialCardActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(minWidth: 68, minHeight: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct MaterialIconOnlyButton: View {
    let systemImage: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(disabled ? AppColors.textSecondary.opacity(0.35) : color)
                .frame(width: 36, height: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct PieSegment: Identifiable {
    let id: Int
    let value: Int
    let color: Color
    var start: Double = 0
    var end: Double = 0
}

struct PieSliceShape: Shape {
    let startFraction: Double
    let endFraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sweep = max(endFraction - startFraction, 0)
        let stepCount = max(Int(ceil(sweep * 96)), 1)

        var path = Path()
        path.move(to: center)
        for step in 0...stepCount {
            let fraction = startFraction + sweep * Double(step) / Double(stepCount)
            let angle = fraction * 2 * Double.pi
            let point = CGPoint(
                x: center.x + radius * Darwin.sin(angle),
                y: center.y - radius * Darwin.cos(angle)
            )
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct MaterialProblemChapterSection {
    let chapter: ProblemChapter
    let startGlobalNumber: Int
}

