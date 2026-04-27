import SwiftUI

struct ProblemTileSelector: View {
    let totalProblems: Int
    @Binding var records: [ProblemSessionRecord]
    @State private var editingNumber: Int?
    @State private var editingStatus: ProblemTileEditStatus = .untouched
    @State private var detailText = ""

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 10), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...totalProblems, id: \.self) { number in
                ProblemTile(
                    number: number,
                    record: records.first(where: { $0.number == number }),
                    onCorrectTap: { toggleCorrect(number) },
                    onWrongDoubleTap: { toggleWrong(number) },
                    onLongPress: {
                        let record = records.first(where: { $0.number == number })
                        if let record {
                            editingStatus = record.result.editStatus
                        } else {
                            editingStatus = .untouched
                        }
                        detailText = record?.detail ?? ""
                        editingNumber = number
                    }
                )
            }
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
                        Text("復習正解").tag(ProblemTileEditStatus.reviewCorrect)
                    }
                    TextField("大問・小問メモ（例: 大問2の(4)、計算ミス）", text: $detailText, axis: .vertical)
                        .keyboardType(.default)
                }
                .navigationTitle("\(target.number)問目")
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

    private func toggleCorrect(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].result == .wrong {
                records[index].result = .correct
            } else {
                records.remove(at: index)
            }
        } else {
            records.append(ProblemSessionRecord(number: number, isWrong: false))
            records.sort { $0.number < $1.number }
        }
    }

    private func toggleWrong(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].isWrong {
                records.remove(at: index)
            } else {
                records[index].isWrong = true
            }
        } else {
            records.append(ProblemSessionRecord(number: number, isWrong: true))
            records.sort { $0.number < $1.number }
        }
    }

    private func saveEditedRecord(number: Int) {
        let trimmed = detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        records.removeAll { $0.number == number }
        guard editingStatus != .untouched else { return }
        records.append(
            ProblemSessionRecord(
                number: number,
                result: editingStatus.problemResult ?? .correct,
                detail: trimmed.isEmpty ? nil : trimmed
            )
        )
        records.sort { $0.number < $1.number }
    }
}

private enum ProblemTileEditStatus: Hashable {
    case untouched
    case correct
    case wrong
    case reviewCorrect

    var problemResult: ProblemResult? {
        switch self {
        case .untouched: return nil
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .reviewCorrect
        }
    }
}

private extension ProblemResult {
    var editStatus: ProblemTileEditStatus {
        switch self {
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .reviewCorrect
        }
    }
}

private struct ProblemTileEditTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

private struct ProblemTile: View {
    let number: Int
    let record: ProblemSessionRecord?
    let onCorrectTap: () -> Void
    let onWrongDoubleTap: () -> Void
    let onLongPress: () -> Void

    @State private var pendingSingleTap: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 2) {
            Text("\(number)")
                .font(.callout.bold())
                .monospacedDigit()
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
        .onTapGesture(count: 2, perform: handleDoubleTap)
        .onTapGesture(count: 1, perform: handleSingleTap)
        .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("タップで正解、ダブルタップで不正解、長押しで復習正解とメモを編集")
    }

    private func handleSingleTap() {
        pendingSingleTap?.cancel()
        let task = DispatchWorkItem {
            onCorrectTap()
        }
        pendingSingleTap = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
    }

    private func handleDoubleTap() {
        pendingSingleTap?.cancel()
        pendingSingleTap = nil
        onWrongDoubleTap()
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
        guard let record else { return "\(number)問目 未着手" }
        return "\(number)問目 \(record.result.title)"
    }
}
