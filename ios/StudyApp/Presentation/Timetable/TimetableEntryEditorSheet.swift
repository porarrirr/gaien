import SwiftUI

struct TimetableEntryEditorSheet: View {
    let context: TimetableEditorContext
    let onSave: (TimetableEntry) -> Void
    let onDelete: (TimetableEntry) -> Void
    let onCancel: () -> Void

    @State private var subjectName: String
    @State private var courseName: String
    @State private var roomName: String
    @State private var memo: String = ""
    @FocusState private var focusedField: TimetableEntryEditorField?

    init(
        context: TimetableEditorContext,
        onSave: @escaping (TimetableEntry) -> Void,
        onDelete: @escaping (TimetableEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _subjectName = State(initialValue: context.entry?.subjectName ?? "")
        _courseName = State(initialValue: context.entry?.courseName ?? "")
        _roomName = State(initialValue: context.entry?.roomName ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                topBar

                VStack(alignment: .leading, spacing: 13) {
                    Text("授業の情報")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        TimetableEntryInfoRow(
                            icon: "calendar",
                            iconColor: AppColors.green,
                            title: "学期",
                            value: context.term?.name ?? "未設定"
                        )

                        TimetableEntryDivider()

                        TimetableEntryInfoRow(
                            icon: "calendar",
                            iconColor: AppColors.blue,
                            title: "曜日",
                            value: context.day.japaneseTitle
                        )

                        TimetableEntryDivider()

                        TimetableEntryInfoRow(
                            icon: "clock",
                            iconColor: Color(hex: 0x7442D8),
                            title: "時限",
                            value: "\(context.period.name)  \(periodTimeRangeText)"
                        )
                    }
                    .background(editorCardBackground)
                    .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 13) {
                    Text("授業の詳細")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        subjectRow

                        TimetableEntryDivider()

                        TimetableEntryTextRow(
                            title: "講座名",
                            placeholder: "微分法",
                            text: $courseName,
                            focusedField: $focusedField,
                            field: .course
                        )

                        TimetableEntryDivider()

                        TimetableEntryTextRow(
                            title: "教室",
                            placeholder: "101教室",
                            text: $roomName,
                            focusedField: $focusedField,
                            field: .room
                        )

                        TimetableEntryDivider()

                        memoRow
                    }
                    .background(editorCardBackground)
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    Button(action: saveEntry) {
                        Text("保存")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.green)
                    )
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)

                    Button(action: onCancel) {
                        Text("キャンセル")
                            .font(.system(size: 19, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 55)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.green)
                    .background(editorButtonBackground)

                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
            }
            .padding(.top, 17)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(.systemGray3))
                .frame(width: 42, height: 6)

            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColors.green)
                    .frame(width: 112, alignment: .leading)

                Spacer()

                Text(context.entry == nil ? "授業を追加" : "授業を編集")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("保存", action: saveEntry)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(canSave ? AppColors.green : AppColors.textSecondary)
                    .disabled(!canSave)
                    .frame(width: 112, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }

    private var subjectRow: some View {
        HStack(spacing: 12) {
            Text("科目")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 8)

            Circle()
                .fill(subjectColor)
                .frame(width: 28, height: 28)

            TextField("数学 III", text: $subjectName)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .subject)

            Image(systemName: "chevron.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(minHeight: 68)
        .padding(.horizontal, 18)
    }

    private var memoRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("メモ")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.textPrimary)
                Text("（任意）")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $memo)
                    .font(.system(size: 18))
                    .frame(height: 122)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .memo)
                    .onChange(of: memo) { newValue in
                        if newValue.count > 200 {
                            memo = String(newValue.prefix(200))
                        }
                    }

                if memo.isEmpty {
                    Text("メモを入力（任意）")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 19)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(memo.count)/200")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let entry = context.entry {
            Button(role: .destructive) {
                onDelete(entry)
            } label: {
                Text("削除")
                    .font(.system(size: 19, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 55)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.danger)
            .background(editorButtonBackground)
        } else {
            Text("削除")
                .font(.system(size: 19, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 55)
                .foregroundStyle(AppColors.danger.opacity(0.35))
                .background(editorButtonBackground)
        }
    }

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(AppColors.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
    }

    private var editorButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppColors.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
    }

    private var canSave: Bool {
        !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var periodTimeRangeText: String {
        "\(TimetablePeriod.timeText(context.period.startMinute)) - \(TimetablePeriod.timeText(context.period.endMinute))"
    }

    private var subjectColor: Color {
        switch subjectName {
        case let value where value.contains("数学"):
            return AppColors.blue
        case let value where value.contains("英"):
            return AppColors.danger
        case let value where value.contains("化"):
            return AppColors.green
        case let value where value.contains("体育"):
            return Color(hex: 0x7442D8)
        case let value where value.contains("現代文"):
            return AppColors.orange
        default:
            return AppColors.blue
        }
    }

    private func saveEntry() {
        guard canSave else { return }
        let now = Date().epochMilliseconds
        onSave(
            TimetableEntry(
                id: context.entry?.id ?? 0,
                syncId: context.entry?.syncId ?? UUID().uuidString.lowercased(),
                termId: context.term?.id,
                termSyncId: context.term?.syncId,
                dayOfWeek: context.day,
                periodId: context.period.id,
                periodSyncId: context.period.syncId,
                subjectName: subjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                courseName: courseName.nilIfBlank,
                roomName: roomName.nilIfBlank,
                validFromDate: context.entry?.validFromDate,
                validToDate: context.entry?.validToDate,
                createdAt: context.entry?.createdAt ?? now,
                updatedAt: now,
                deletedAt: context.entry?.deletedAt,
                lastSyncedAt: context.entry?.lastSyncedAt
            )
        )
    }
}

struct TimetableEntryInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 34)

            Text(title)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 86, alignment: .leading)

            Text(value)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 68)
        .padding(.horizontal, 18)
    }
}

struct TimetableEntryTextRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focusedField: FocusState<TimetableEntryEditorField?>.Binding
    let field: TimetableEntryEditorField

    var body: some View {
        HStack(spacing: 13) {
            Text(title)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 82, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 18))
                .focused(focusedField, equals: field)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        }
        .frame(minHeight: 78)
        .padding(.horizontal, 18)
    }
}

struct TimetableEntryDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray4).opacity(0.7))
            .frame(height: 1)
            .padding(.leading, 18)
            .padding(.trailing, 18)
    }
}

enum TimetableEntryEditorField {
    case subject
    case course
    case room
    case memo
}

