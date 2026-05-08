import SwiftUI

struct ManualEntrySheet: View {
    let viewModel: TimerViewModel
    @Binding var manualNote: String
    @Binding var isPresented: Bool
    @State private var manualEntryMode: ManualEntryTimeMode = .duration
    @State private var manualHours = "00"
    @State private var manualMinutes = "25"
    @State private var manualStartTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) ?? Date()
    @State private var manualEndTime = Date()
    @State private var manualRating: Int?
    @State private var correctCount = "0"
    @State private var wrongCount = "0"
    @State private var reviewCorrectCount = "0"
    @State private var unansweredCount = "0"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                selectionCard
                timeCard
                noteCard
                ratingCard
                problemCard
                Text("※ 問題の詳細な記録は、保存後に編集できます。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("手動入力")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.success)
                    .disabled(!canSave)
            }
        }
        .onChange(of: manualNote) { _ in
            if manualNote.count > 300 {
                manualNote = String(manualNote.prefix(300))
            }
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("科目")
                    .manualSectionTitle()
                Menu {
                    ForEach(viewModel.subjects) { subject in
                        Button(subject.name) {
                            viewModel.selectedSubjectId = subject.id
                            viewModel.handleSubjectSelectionChange()
                        }
                    }
                } label: {
                    ManualSelectionRow(
                        title: selectedSubject?.name ?? "未設定",
                        subtitle: nil,
                        leading: {
                            Circle()
                                .fill(subjectColor)
                                .frame(width: 16, height: 16)
                        }
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("教材（任意）")
                        .manualSectionTitle()
                    Spacer()
                    if selectedMaterial != nil {
                        Button {
                            viewModel.selectedMaterialId = nil
                            viewModel.handleMaterialSelectionChange()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Menu {
                    Button("教材なし") {
                        viewModel.selectedMaterialId = nil
                        viewModel.handleMaterialSelectionChange()
                    }
                    ForEach(viewModel.materialsForSelectedSubject()) { material in
                        Button(material.name) {
                            viewModel.selectedMaterialId = material.id
                            viewModel.handleMaterialSelectionChange()
                        }
                    }
                } label: {
                    ManualSelectionRow(
                        title: selectedMaterial?.name ?? "教材なし",
                        subtitle: selectedMaterialSubtitle,
                        leading: {
                            ManualBookThumbnail()
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .manualCard()
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("学習時間")
                .manualSectionTitle()
            ManualSegmentedControl(
                selection: $manualEntryMode,
                items: [
                    (.duration, "時間を入力"),
                    (.range, "開始・終了時刻を入力")
                ]
            )

            if manualEntryMode == .duration {
                HStack(spacing: 12) {
                    Text("学習時間")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 74, alignment: .leading)
                    manualNumberField(text: $manualHours, width: 64)
                    Text("時間")
                        .font(.subheadline.weight(.semibold))
                    manualNumberField(text: $manualMinutes, width: 64)
                    Text("分")
                        .font(.subheadline.weight(.semibold))
                }
                Text("5分〜12時間")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                DatePicker("開始時刻", selection: $manualStartTime, displayedComponents: .hourAndMinute)
                DatePicker("終了時刻", selection: $manualEndTime, displayedComponents: .hourAndMinute)
            }
        }
        .manualCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メモ（任意）")
                .manualSectionTitle()
            ZStack(alignment: .topLeading) {
                TextEditor(text: $manualNote)
                    .frame(minHeight: 82)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                if manualNote.isEmpty {
                    Text("メモを入力（任意）")
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
            Text("\(manualNote.count)/300")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -6)
        }
        .manualCard()
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価（任意）")
                .manualSectionTitle()
            HStack(spacing: 22) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        manualRating = value
                    } label: {
                        Image(systemName: value <= (manualRating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(value <= (manualRating ?? 0) ? AppColors.warning : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            Text("タップして評価（1〜5）")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .manualCard()
    }

    private var problemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("問題集の記録（任意）")
                .manualSectionTitle()
            problemSummary
            ManualSegmentedControl(
                selection: .constant(ManualProblemEntryMode.summary),
                items: [
                    (.summary, "まとめて入力"),
                    (.perProblem, "問題ごとに入力")
                ]
            )
            HStack(alignment: .top, spacing: 12) {
                problemCountField(title: "正解", text: $correctCount, color: AppColors.success)
                problemCountField(title: "不正解", text: $wrongCount, color: AppColors.danger)
                problemCountField(title: "復習正解", text: $reviewCorrectCount, color: AppColors.warning)
                problemCountField(title: "未解答", text: $unansweredCount, color: Color(.systemGray3))
            }
        }
        .manualCard()
    }

    private var problemSummary: some View {
        HStack(spacing: 0) {
            summaryColumn(title: "正解", value: correctTotal, color: AppColors.success)
            summaryColumn(title: "不正解", value: wrongTotal, color: AppColors.danger)
            summaryColumn(title: "復習正解", value: reviewCorrectTotal, color: AppColors.warning)
            summaryColumn(title: "未解答", value: unansweredTotal, color: AppColors.textSecondary)
            summaryColumn(title: "合計", value: totalProblemCount, color: AppColors.textPrimary)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func summaryColumn(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(value)")
                .font(.title3.weight(.medium))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func problemCountField(title: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                manualNumberField(text: text, width: 54)
                    .onChange(of: text.wrappedValue) { _ in
                        limitNumeric(text)
                    }
                Text("問")
                    .font(.caption.weight(.semibold))
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 11, height: 11)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func manualNumberField(text: Binding<String>, width: CGFloat) -> some View {
        TextField("0", text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .regular, design: .rounded))
            .monospacedDigit()
            .frame(width: width, height: 48)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
            .onChange(of: text.wrappedValue) { _ in
                limitNumeric(text)
            }
    }

    private var selectedSubject: Subject? {
        viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectId })
    }

    private var selectedMaterial: Material? {
        viewModel.materials.first(where: { $0.id == viewModel.selectedMaterialId })
    }

    private var subjectColor: Color {
        Color(hex: selectedSubject?.color ?? 0x1F5FD1)
    }

    private var selectedMaterialSubtitle: String? {
        guard let material = selectedMaterial else { return nil }
        let pageText = material.currentPage > 0 ? "p.\(material.currentPage)" : nil
        let problemText = material.effectiveTotalProblems > 0 ? "例題 \(material.effectiveTotalProblems)" : nil
        return [pageText, problemText].compactMap { $0 }.joined(separator: " ")
    }

    private var durationMinutes: Int {
        (Int(manualHours) ?? 0) * 60 + (Int(manualMinutes) ?? 0)
    }

    private var canSave: Bool {
        guard viewModel.selectedSubjectId != nil else { return false }
        if manualEntryMode == .duration {
            return durationMinutes >= 5 && durationMinutes <= 12 * 60
        }
        return manualEndTime > manualStartTime
    }

    private var correctTotal: Int { Int(correctCount) ?? 0 }
    private var wrongTotal: Int { Int(wrongCount) ?? 0 }
    private var reviewCorrectTotal: Int { Int(reviewCorrectCount) ?? 0 }
    private var unansweredTotal: Int { Int(unansweredCount) ?? 0 }
    private var totalProblemCount: Int {
        correctTotal + wrongTotal + reviewCorrectTotal + unansweredTotal
    }

    private var aggregateProblemRecords: [ProblemSessionRecord] {
        var nextNumber = 1
        var records: [ProblemSessionRecord] = []
        for _ in 0..<correctTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .correct))
            nextNumber += 1
        }
        for _ in 0..<wrongTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .wrong))
            nextNumber += 1
        }
        for _ in 0..<reviewCorrectTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .reviewCorrect))
            nextNumber += 1
        }
        return records
    }

    private func save() {
        guard let subjectId = viewModel.selectedSubjectId else { return }
        let endDate: Date
        let startDate: Date
        if manualEntryMode == .duration {
            endDate = Date()
            startDate = endDate.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        } else {
            startDate = manualStartTime
            endDate = manualEndTime
        }
        viewModel.saveManualSession(
            subjectId: subjectId,
            materialId: viewModel.selectedMaterialId,
            startTime: startDate.epochMilliseconds,
            endTime: endDate.epochMilliseconds,
            note: manualNote,
            rating: manualRating,
            problemRecords: aggregateProblemRecords,
            problemStart: totalProblemCount > 0 ? 1 : nil,
            problemEnd: totalProblemCount > 0 ? totalProblemCount : nil,
            wrongProblemCount: totalProblemCount > 0 ? wrongTotal : nil
        )
        manualNote = ""
        isPresented = false
    }

    private func limitNumeric(_ text: Binding<String>) {
        let filtered = text.wrappedValue.filter(\.isNumber)
        if filtered != text.wrappedValue {
            text.wrappedValue = filtered
        }
    }
}

private enum ManualEntryTimeMode: Hashable {
    case duration
    case range
}

private enum ManualProblemEntryMode: Hashable {
    case summary
    case perProblem
}

private struct ManualSegmentedControl<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(Selection, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == item.0 ? AppColors.success : AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if selection == item.0 {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppColors.success, lineWidth: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(1)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ManualSelectionRow<Leading: View>: View {
    let title: String
    let subtitle: String?
    private let leading: () -> Leading

    init(title: String, subtitle: String?, @ViewBuilder leading: @escaping () -> Leading) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.title3.weight(.regular))
                .foregroundStyle(Color(.systemGray2))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct ManualBookThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x0F3D91), Color(hex: 0x1A5CC8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 34, height: 48)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.white.opacity(0.88))
                    .frame(width: 22, height: 6)
                    .padding(.top, 8)
            }
    }
}

private extension View {
    func manualCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }

    func manualSectionTitle() -> some View {
        self
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
    }
}
