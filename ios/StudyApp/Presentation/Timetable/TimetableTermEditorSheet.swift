import SwiftUI

struct TimetableTermEditorSheet: View {
    let term: TimetableTerm?
    let onSave: (TimetableTerm) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorMessage: String?

    init(term: TimetableTerm?, onSave: @escaping (TimetableTerm) -> Void, onCancel: @escaping () -> Void) {
        self.term = term
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: term?.name ?? "新しい学期")
        _startDate = State(initialValue: term?.startDateValue ?? Date().startOfDay)
        _endDate = State(initialValue: term?.endDateValue ?? (Calendar.current.date(byAdding: .month, value: 6, to: Date().startOfDay) ?? Date().startOfDay))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sheetHeader
                    .padding(.top, 48)

                Text("学期の期間を設定します。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, 18)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.redSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(spacing: 0) {
                    termNameRow
                    TimetableTermEditorDivider()
                    TimetableTermDateRow(title: "開始日", date: $startDate)
                    TimetableTermEditorDivider()
                    TimetableTermDateRow(title: "終了日", date: $endDate)
                }
                .padding(.horizontal, 18)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }

                Text("※ 終了日は学期の最終日を設定してください。")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, -4)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sheetHeader: some View {
        ZStack {
            Text(term == nil ? "学期を追加" : "学期を編集")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(.label))

            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.green)

                Spacer()

                Button("保存", action: saveTerm)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.green)
            }
        }
    }

    private var termNameRow: some View {
        HStack(spacing: 16) {
            Text("学期名")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 74, alignment: .leading)

            TextField("学期名", text: $name)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
        }
        .frame(height: 73)
    }

    private func saveTerm() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "学期名を入力してください"
            return
        }
        guard startDate.startOfDay <= endDate.startOfDay else {
            errorMessage = "終了日は開始日以降にしてください"
            return
        }
        let now = Date().epochMilliseconds
        onSave(
            TimetableTerm(
                id: term?.id ?? 0,
                syncId: term?.syncId ?? UUID().uuidString.lowercased(),
                name: trimmed,
                startDate: startDate.startOfDay.epochDay,
                endDate: endDate.startOfDay.epochDay,
                isActive: true,
                createdAt: term?.createdAt ?? now,
                updatedAt: now,
                deletedAt: term?.deletedAt,
                lastSyncedAt: term?.lastSyncedAt
            )
        )
    }
}

struct TimetableTermDateRow: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .frame(width: 74, alignment: .leading)

            ZStack {
                HStack {
                    Text(StudyFormatters.yearMonthDayWithWeekdayHalf.string(from: date))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(.label))

                    Spacer(minLength: 8)

                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.green)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .opacity(0.02)
            }
        }
        .frame(height: 73)
    }
}

struct TimetableTermEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.cardBorder)
            .frame(height: 1)
            .padding(.leading, 74)
    }
}
