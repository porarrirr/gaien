import SwiftUI

struct HistorySessionIntervalDraft: Identifiable, Hashable {
    let id: UUID
    var index: Int
    var startDate: Date
    var endDate: Date

    init(interval: StudySessionInterval, index: Int) {
        id = UUID()
        self.index = index
        startDate = Date(epochMilliseconds: interval.startTime)
        endDate = Date(epochMilliseconds: interval.endTime)
    }

    init(startDate: Date, endDate: Date, index: Int) {
        id = UUID()
        self.index = index
        self.startDate = startDate
        self.endDate = endDate
    }

    var interval: StudySessionInterval {
        StudySessionInterval(startTime: startDate.epochMilliseconds, endTime: endDate.epochMilliseconds)
    }
}

struct HistorySessionEditorSheet: View {
    let session: StudySession
    let chapters: [ProblemChapter]
    let totalProblems: Int
    @Binding var intervalDrafts: [HistorySessionIntervalDraft]
    @Binding var note: String
    @Binding var rating: Int?
    @Binding var problemStart: String
    @Binding var problemEnd: String
    @Binding var wrongProblemCount: String
    @Binding var problemCount: String
    @Binding var problemRecords: [ProblemSessionRecord]
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    private var totalDurationMilliseconds: Int64 {
        intervalDrafts.reduce(0) { $0 + max($1.interval.duration, 0) }
    }

    private var canSave: Bool {
        guard !intervalDrafts.isEmpty else { return false }
        let intervals = intervalDrafts.map(\.interval)
        guard intervals.allSatisfy({ $0.endTime > $0.startTime }) else { return false }
        for index in intervals.indices.dropFirst() where intervals[index].startTime < intervals[index - 1].endTime {
            return false
        }
        return true
    }

    private var saveDisabledMessage: String? {
        canSave ? nil : "無効な区間があります"
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sessionSummary
                    intervalsSection
                    ratingSection
                    problemSection
                    noteSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            bottomBar
        }
        .background(Color(.systemBackground))
        .onChange(of: problemRecords) { records in
            guard !records.isEmpty else { return }
            wrongProblemCount = "\(records.filter(\.isWrong).count)"
        }
        .onChange(of: note) { newValue in
            if newValue.count > 300 {
                note = String(newValue.prefix(300))
            }
        }
    }

    private var editorHeader: some View {
        HStack {
            Button("キャンセル", action: onCancel)
                .font(.title3.weight(.medium))
                .foregroundStyle(AppColors.success)
            Spacer()
            Text("履歴を編集")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button("保存", action: onSave)
                .font(.title3.weight(.medium))
                .foregroundStyle(canSave ? AppColors.success : AppColors.textSecondary.opacity(0.55))
                .disabled(!canSave)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                if !session.materialName.isEmpty {
                    Text("|")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.65))
                    Text(session.materialName)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                }
            }
            Text("区間数: \(intervalDrafts.count)    合計予定時間: \(durationJapaneseText(totalDurationMilliseconds))")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .historyEditorCard()
    }

    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("区間 (ドラフト)")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    addInterval()
                } label: {
                    Label("区間を追加", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.success)
            }

            VStack(spacing: 10) {
                ForEach($intervalDrafts) { $interval in
                    intervalCard(interval: $interval)
                }
            }

            HStack {
                Spacer()
                Text("合計予定時間: \(durationJapaneseText(totalDurationMilliseconds))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .historyEditorCard()
    }

    private func intervalCard(interval: Binding<HistorySessionIntervalDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("区間 \(interval.wrappedValue.index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    removeInterval(interval.wrappedValue)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(AppColors.danger)
                }
                .buttonStyle(.plain)
                .disabled(intervalDrafts.count <= 1)
                .opacity(intervalDrafts.count <= 1 ? 0.35 : 1)
            }
            Divider()
            HistoryEditorDateRow(title: "開始時刻", date: interval.startDate)
            HistoryEditorDateRow(title: "終了時刻", date: interval.endDate)
            Divider()
            HStack {
                Text("予定時間")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(durationJapaneseText(max(interval.wrappedValue.interval.duration, 0)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価")
                .font(.headline.weight(.semibold))
            HStack(spacing: 18) {
                Spacer()
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = rating == value ? nil : value
                    } label: {
                        Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(value <= (rating ?? 0) ? AppColors.warning : AppColors.textSecondary.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            if let rating {
                Text("\(rating)")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
        }
        .historyEditorCard(padding: 0)
        .padding(.top, 0)
    }

    private var problemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("問題集の記録")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(problemProgressHeaderText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if totalProblems > 0 {
                ProblemTileSelector(
                    totalProblems: totalProblems,
                    chapters: chapters,
                    records: $problemRecords
                )
                Text(problemRecordSummary)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                problemCountControls

                if effectiveProblemCount > 0 {
                    ProblemTileSelector(
                        totalProblems: effectiveProblemCount,
                        chapters: chapters,
                        records: $problemRecords
                    )
                    Text(problemRecordSummary)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("教材に問題数が未設定です。全問題数を入力すると、タイマーと同じ番号タップで記録できます。")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .historyEditorCard(padding: 0)
    }

    private var problemProgressHeaderText: String {
        if totalProblems > 0 {
            return chapters.isEmpty ? "全\(totalProblems)問" : "全\(totalProblems)問 ・ \(chapters.count)章"
        }
        return effectiveProblemCount > 0 ? "全\(effectiveProblemCount)問" : "問題数未設定"
    }

    private var problemRecordSummary: String {
        let done = problemRecords.count
        let correct = problemRecords.filter { $0.result == .correct }.count
        let wrong = problemRecords.filter(\.isWrong).count
        let review = problemRecords.filter { $0.result == .reviewCorrect }.count
        return "タップで正解、すばやく2回タップで不正解、長押しで状態とメモを編集。選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
    }

    private var effectiveProblemCount: Int {
        totalProblems > 0 ? totalProblems : parseDraftInt(problemCount)
    }

    private var problemCountControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Button {
                    setProblemCount(max(effectiveProblemCount - 1, 0))
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
        problemCount = count > 0 ? "\(count)" : ""
        problemEnd = count > 0 ? "\(count)" : ""
        problemRecords.removeAll { $0.number > count }
    }

    private var problemControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                problemRangeControls
                Spacer()
                wrongCountControls
            }
            VStack(alignment: .leading, spacing: 10) {
                problemRangeControls
                wrongCountControls
            }
        }
    }

    private var problemRangeControls: some View {
        HStack(spacing: 10) {
            Text("問題範囲")
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            NumberDraftField(text: $problemStart, width: 64)
            Text("~")
                .foregroundStyle(AppColors.textSecondary)
            NumberDraftField(text: $problemEnd, width: 64)
        }
    }

    private var wrongCountControls: some View {
        HStack(spacing: 10) {
            Text("不正解数")
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            HistoryEditorStepper(valueText: $wrongProblemCount)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メモ")
                .font(.headline.weight(.semibold))
            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 104)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
            HStack {
                Spacer()
                Text("\(note.count)/300")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .historyEditorCard(padding: 0)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.danger)

            Spacer()

            if let saveDisabledMessage {
                Text(saveDisabledMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Button("保存", action: onSave)
                .font(.title3.weight(.semibold))
                .foregroundStyle(canSave ? .white : AppColors.textSecondary.opacity(0.55))
                .frame(width: 96, height: 48)
                .background(canSave ? AppColors.success : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(!canSave)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)
        }
    }

    private var problemRangeDisplay: String {
        let range = problemDisplayRange
        guard let first = range.first, let last = range.last else { return "未入力" }
        return first == last ? "p.\(first)" : "p.\(first) - \(last)"
    }

    private var problemDisplayRange: [Int] {
        let explicitStart = parseDraftInt(problemStart)
        let explicitEnd = parseDraftInt(problemEnd)
        if explicitStart > 0, explicitEnd >= explicitStart {
            return Array(explicitStart...explicitEnd)
        }
        let numbers = problemRecords.map(\.number).sorted()
        if let first = numbers.first, let last = numbers.last {
            return Array(first...last)
        }
        let count = totalProblems > 0 ? totalProblems : parseDraftInt(problemCount)
        guard count > 0 else { return [] }
        return Array(1...min(count, 50))
    }

    private func addInterval() {
        let start = intervalDrafts.last?.endDate ?? Date()
        let end = Calendar.current.date(byAdding: .minute, value: 50, to: start) ?? start.addingTimeInterval(3_000)
        intervalDrafts.append(HistorySessionIntervalDraft(startDate: start, endDate: end, index: intervalDrafts.count))
        reindexIntervals()
    }

    private func removeInterval(_ interval: HistorySessionIntervalDraft) {
        guard intervalDrafts.count > 1 else { return }
        intervalDrafts.removeAll { $0.id == interval.id }
        reindexIntervals()
    }

    private func reindexIntervals() {
        intervalDrafts = intervalDrafts.enumerated().map { index, draft in
            HistorySessionIntervalDraft(startDate: draft.startDate, endDate: draft.endDate, index: index)
        }
    }

    private func durationJapaneseText(_ milliseconds: Int64) -> String {
        let minutes = Int(milliseconds / 60_000)
        return Goal.format(minutes: minutes)
    }
}

private struct HistoryEditorDateRow: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}

private struct NumberDraftField: View {
    @Binding var text: String
    let width: CGFloat

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit())
            .frame(width: width, height: 36)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

private struct HistoryEditorStepper: View {
    @Binding var valueText: String

    var body: some View {
        HStack(spacing: 8) {
            Button {
                valueText = "\(max(parseDraftInt(valueText) - 1, 0))"
            } label: {
                Image(systemName: "minus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6), in: Circle())
            }
            .buttonStyle(.plain)
            TextField("", text: $valueText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .frame(width: 40, height: 34)
            Button {
                valueText = "\(parseDraftInt(valueText) + 1)"
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HistoryProblemRecordGrid: View {
    let range: [Int]
    let chapters: [ProblemChapter]
    @Binding var records: [ProblemSessionRecord]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(range, id: \.self) { number in
                    HistoryProblemTile(
                        number: number,
                        label: tileLabel(for: number),
                        record: records.first(where: { $0.number == number }),
                        onTap: { toggleCorrect(number) },
                        onWrong: { setResult(.wrong, for: number) }
                    )
                }
            }

            HStack(spacing: 18) {
                legend("circle", "正解", AppColors.success)
                legend("xmark", "不正解", AppColors.danger)
                legend("triangle", "復習正解", AppColors.warning)
                legend("minus", "未解答", AppColors.textSecondary)
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
        }
    }

    private func tileLabel(for number: Int) -> String {
        chapters.location(for: number).map { "\($0.localNumber)" } ?? "\(number)"
    }

    private func legend(_ systemName: String, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
            Text(title)
        }
        .foregroundStyle(color)
    }

    private func toggleCorrect(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].result == .correct {
                records.remove(at: index)
            } else {
                records[index].result = .correct
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
        }
        records.sort { $0.number < $1.number }
    }

    private func setResult(_ result: ProblemResult, for number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            records[index].result = result
        } else {
            records.append(ProblemSessionRecord(number: number, result: result))
        }
        records.sort { $0.number < $1.number }
    }
}

private struct HistoryProblemTile: View {
    let number: Int
    let label: String
    let record: ProblemSessionRecord?
    let onTap: () -> Void
    let onWrong: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("正解", action: onTap)
            Button("不正解", action: onWrong)
        }
    }

    private var iconName: String {
        guard let record else { return "minus" }
        switch record.result {
        case .correct: return "circle"
        case .wrong: return "xmark"
        case .reviewCorrect: return "triangle"
        }
    }

    private var iconColor: Color {
        guard let record else { return AppColors.textSecondary }
        switch record.result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }
}

private struct HistoryEditorCardModifier: ViewModifier {
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

private extension View {
    func historyEditorCard(padding: CGFloat = 12) -> some View {
        modifier(HistoryEditorCardModifier(padding: padding))
    }
}
