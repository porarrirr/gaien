import SwiftUI

struct SessionEvaluationSheet: View {
    let session: StudySession
    @Binding var rating: Int?
    @Binding var note: String
    @Binding var problemStart: String
    @Binding var problemEnd: String
    @Binding var wrongProblemCount: String
    @Binding var problemRecords: [ProblemSessionRecord]
    @Binding var problemCount: String
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sessionInfoCard
                ratingCard
                problemRecordCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .background(Color(hex: 0xF7F8FA))
        .navigationTitle("セッション評価")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.headline.weight(.semibold))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .font(.headline.weight(.semibold))
                    .disabled(rating == nil)
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            problemRecords.removeAll { $0.number > count }
        }
        .onChange(of: note) { newValue in
            if newValue.count > 300 {
                note = String(newValue.prefix(300))
            }
        }
    }

    private var sessionInfoCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                SessionInfoColumn(
                    icon: "circle.fill",
                    iconColor: AppColors.blue,
                    title: "科目",
                    value: session.subjectName.isEmpty ? "未設定" : session.subjectName
                )
                verticalDivider
                SessionInfoColumn(
                    icon: "book",
                    iconColor: AppColors.orange,
                    title: "教材",
                    value: session.materialName.isEmpty ? "未設定" : session.materialName
                )
                verticalDivider
                SessionInfoColumn(
                    icon: "clock",
                    iconColor: AppColors.success,
                    title: "学習時間",
                    value: session.durationJapaneseText
                )
            }

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 24)
                Text("学習区間")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text(sessionPeriodText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
        }
        .evaluationPanel()
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("評価")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 22) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(value <= (rating ?? 0) ? AppColors.warning : Color(hex: 0x8F9299))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("評価 \(value)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            Text("1〜5 の星で評価してください")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .evaluationPanel()
    }

    private var problemRecordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("問題集の記録")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 26) {
                ProblemLegendItem(symbol: "○", title: "正解", color: AppColors.success)
                ProblemLegendItem(symbol: "×", title: "不正解", color: AppColors.danger)
                ProblemLegendItem(symbol: "△", title: "復習正解", color: AppColors.orange)
                ProblemLegendItem(symbol: "−", title: "未解答", color: Color(hex: 0x9A9DA3))
            }
            .frame(maxWidth: .infinity)

            problemGrid

            Divider()
                .padding(.horizontal, -16)

            NumericEvaluationRow(title: "問題数（合計）", text: $problemCount, valueIfLocked: materialProblemCount > 0 ? "\(materialProblemCount)" : nil)
            NumericEvaluationRow(title: "開始問題", text: $problemStart)
            NumericEvaluationRow(title: "終了問題", text: $problemEnd)
            NumericEvaluationRow(title: "不正解数", text: $wrongProblemCount)

            VStack(alignment: .leading, spacing: 10) {
                Text("メモ")
                    .font(.headline.weight(.semibold))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white)
                    if note.isEmpty {
                        Text("メモを入力してください（任意）")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x9A9DA3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    Text("\(note.count)/300")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 14)
                        .padding(.bottom, 12)
                        .allowsHitTesting(false)
                }
                .frame(height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xCDD0D6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .evaluationPanel()
    }

    private var effectiveProblemCount: Int {
        materialProblemCount > 0 ? materialProblemCount : parseDraftInt(problemCount)
    }

    private var problemGrid: some View {
        VStack(spacing: 0) {
            ForEach(problemSections) { section in
                ProblemChapterRecordRow(
                    section: section,
                    records: $problemRecords
                )
                if section.id != problemSections.last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var problemSections: [EvaluationProblemSection] {
        let chapters = materialProblemChapters.filter { $0.problemCount > 0 }
        if !chapters.isEmpty {
            var start = 1
            return chapters.map { chapter in
                defer { start += chapter.problemCount }
                return EvaluationProblemSection(title: chapter.title, problemCount: chapter.problemCount, startNumber: start)
            }
        }

        let total = max(effectiveProblemCount, 0)
        guard total > 0 else { return [] }
        return [EvaluationProblemSection(title: "問題", problemCount: total, startNumber: 1)]
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder)
            .frame(width: 1, height: 58)
            .padding(.horizontal, 10)
    }

    private var sessionPeriodText: String {
        "\(StudyFormatters.slashDateWithWeekdayHalf.string(from: session.startDate)) \(StudyFormatters.clock.string(from: session.startDate)) 〜 \(StudyFormatters.clock.string(from: session.endDate))"
    }
}

private struct SessionInfoColumn: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProblemLegendItem: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(symbol)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct NumericEvaluationRow: View {
    let title: String
    @Binding var text: String
    var valueIfLocked: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Group {
                if let valueIfLocked {
                    Text(valueIfLocked)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 118, height: 44)
                        .background(Color.white)
                } else {
                    TextField("", text: $text)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 118, height: 44)
                        .background(Color.white)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            Text("問")
                .font(.headline.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

private struct EvaluationProblemSection: Identifiable, Hashable {
    let title: String
    let problemCount: Int
    let startNumber: Int

    var id: Int {
        startNumber
    }

    var endNumber: Int {
        startNumber + problemCount - 1
    }
}

private struct ProblemChapterRecordRow: View {
    let section: EvaluationProblemSection
    @Binding var records: [ProblemSessionRecord]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("p.\(section.startNumber)-\(section.endNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(section.startNumber...section.endNumber, id: \.self) { number in
                    EvaluationProblemTile(
                        number: number,
                        record: records.first(where: { $0.number == number }),
                        onTap: { advanceRecord(number) }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private func advanceRecord(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
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
            records.sort { $0.number < $1.number }
        }
    }
}

private struct EvaluationProblemTile: View {
    let number: Int
    let record: ProblemSessionRecord?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number)問 \(accessibilityStatus)")
    }

    private var symbol: String {
        guard let record else { return "−" }
        switch record.result {
        case .correct: return "○"
        case .wrong: return "×"
        case .reviewCorrect: return "△"
        }
    }

    private var tint: Color {
        guard let record else { return Color(hex: 0x9A9DA3) }
        switch record.result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.orange
        }
    }

    private var background: Color {
        guard let record else { return Color(hex: 0xF8F9FB) }
        switch record.result {
        case .correct: return AppColors.greenSoft
        case .wrong: return AppColors.redSoft
        case .reviewCorrect: return AppColors.orangeSoft
        }
    }

    private var border: Color {
        guard let record else { return AppColors.cardBorder }
        switch record.result {
        case .correct: return AppColors.success.opacity(0.35)
        case .wrong: return AppColors.danger.opacity(0.35)
        case .reviewCorrect: return AppColors.orange.opacity(0.35)
        }
    }

    private var accessibilityStatus: String {
        record?.result.title ?? "未解答"
    }
}

private extension View {
    func evaluationPanel() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}
