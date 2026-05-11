import SwiftUI
import UniformTypeIdentifiers

struct TimetablePeriodSettingsSheet: View {
    let onSave: ([TimetablePeriodDraft]) -> Void
    let onCancel: () -> Void
    @State private var drafts: [TimetablePeriodDraft]
    @State private var errorMessage: String?
    @State private var draggingPeriodId: String?

    init(periods: [TimetablePeriod], onSave: @escaping ([TimetablePeriodDraft]) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        _drafts = State(initialValue: periods.map(TimetablePeriodDraft.init(period:)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("授業の時限名と開始・終了時刻を設定します。")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 18)
                    .padding(.horizontal, 15)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.danger)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.redSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.danger.opacity(0.22), lineWidth: 1)
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("時限一覧")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 15)

                    VStack(spacing: 0) {
                        ForEach(drafts.indices, id: \.self) { index in
                            TimetablePeriodSettingsRow(
                                orderTitle: "\(index + 1)限",
                                draft: $drafts[index],
                                canDelete: drafts.count > 1,
                                onDelete: {
                                    deletePeriod(id: drafts[index].id)
                                }
                            )
                            .onDrag {
                                draggingPeriodId = drafts[index].id
                                return NSItemProvider(object: drafts[index].id as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: TimetablePeriodDropDelegate(
                                    targetId: drafts[index].id,
                                    drafts: $drafts,
                                    draggingId: $draggingPeriodId
                                )
                            )
                            .padding(.vertical, 11)

                            if index < drafts.count - 1 {
                                Divider()
                                    .opacity(0)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.cardBorder.opacity(0.85), lineWidth: 1)
                    }
                }

                Button(action: addPeriod) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 19, weight: .semibold))
                        Text("時限を追加")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppColors.cardBorder.opacity(0.85), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                TimetablePeriodSettingsInfoCard()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 34)
        }
        .background(Color(.systemBackground))
        .navigationTitle("時限設定")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: validateAndSave)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }
        }
    }

    private func validateAndSave() {
        for index in drafts.indices {
            drafts[index].name = drafts[index].name.nilIfBlank ?? "\(index + 1)限"
            drafts[index].period.sortOrder = index + 1
        }
        if let invalid = drafts.first(where: { $0.startMinute >= $0.endMinute }) {
            errorMessage = "\(invalid.name) の終了時刻は開始時刻より後にしてください"
        } else {
            onSave(drafts)
        }
    }

    private func addPeriod() {
        let order = drafts.count + 1
        let lastEnd = drafts.last?.endMinute ?? (8 * 60 + 40)
        let startMinute = Swift.min(lastEnd + 10, 22 * 60)
        let endMinute = Swift.min(startMinute + 50, 23 * 60 + 55)
        drafts.append(TimetablePeriodDraft(order: order, startMinute: startMinute, endMinute: endMinute))
    }

    private func deletePeriod(id: String) {
        guard drafts.count > 1 else { return }
        drafts.removeAll { $0.id == id }
        for index in drafts.indices {
            drafts[index].period.sortOrder = index + 1
        }
    }
}

struct TimetablePeriodDropDelegate: DropDelegate {
    let targetId: String
    @Binding var drafts: [TimetablePeriodDraft]
    @Binding var draggingId: String?

    func dropEntered(info: DropInfo) {
        guard
            let draggingId,
            draggingId != targetId,
            let fromIndex = drafts.firstIndex(where: { $0.id == draggingId }),
            let toIndex = drafts.firstIndex(where: { $0.id == targetId })
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            let item = drafts.remove(at: fromIndex)
            drafts.insert(item, at: toIndex)
            for index in drafts.indices {
                drafts[index].period.sortOrder = index + 1
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }
}

struct TimetablePeriodSettingsRow: View {
    let orderTitle: String
    @Binding var draft: TimetablePeriodDraft
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 22)

            Text(orderTitle)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 38, alignment: .leading)

            TextField("", text: $draft.name)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(width: 78, height: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }

            TimetableCompactTimePicker(selection: $draft.startDate)
                .frame(width: 54, height: 34)

            Text("-")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 10)

            TimetableCompactTimePicker(selection: $draft.endDate)
                .frame(width: 54, height: 34)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.danger)
                    .frame(width: 26, height: 34)
            }
            .buttonStyle(.plain)
            .opacity(canDelete ? 1 : 0.35)
            .disabled(!canDelete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimetableCompactTimePicker: View {
    @Binding var selection: Date

    var body: some View {
        Menu {
            Picker("時", selection: hourBinding) {
                ForEach(0..<24, id: \.self) { hour in
                    Text("\(hour)時").tag(hour)
                }
            }
            Picker("分", selection: minuteBinding) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                    Text("\(minute)分").tag(minute)
                }
            }
        } label: {
            Text(timeText)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var timeText: String {
        let calendar = Calendar.current
        return "\(calendar.component(.hour, from: selection)):\(String(format: "%02d", calendar.component(.minute, from: selection)))"
    }

    private var hourBinding: Binding<Int> {
        Binding {
            Calendar.current.component(.hour, from: selection)
        } set: { hour in
            update(hour: hour, minute: Calendar.current.component(.minute, from: selection))
        }
    }

    private var minuteBinding: Binding<Int> {
        Binding {
            let minute = Calendar.current.component(.minute, from: selection)
            return (minute / 5) * 5
        } set: { minute in
            update(hour: Calendar.current.component(.hour, from: selection), minute: minute)
        }
    }

    private func update(hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: selection)
        if let date = calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: hour,
                minute: minute
            )
        ) {
            selection = date
        }
    }
}

struct TimetablePeriodSettingsInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                Text("設定について")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(AppColors.green)

            VStack(alignment: .leading, spacing: 12) {
                Text("・時限名は自由に変更できます。")
                Text("・時刻は5分単位で設定してください。")
                Text("・時限はドラッグして並べ替えできます。")
            }
            .font(.system(size: 15))
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.greenSoft.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.green.opacity(0.18), lineWidth: 1)
        }
    }
}
