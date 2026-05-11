import SwiftUI

struct PlanItemEditorSheet: View {
    let subjects: [Subject]
    let activePlanId: Int64
    let item: PlanItem?
    let onSave: (PlanItem) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    @State private var draft: DraftPlanItem

    init(
        subjects: [Subject],
        activePlanId: Int64,
        item: PlanItem?,
        onSave: @escaping (PlanItem) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.subjects = subjects
        self.activePlanId = activePlanId
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _draft = State(initialValue: DraftPlanItem(item: item, fallbackSubjectId: subjects.first?.id ?? 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("計画項目の内容を編集します。")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.top, 20)

                    editorCard

                    inputGuide

                    if item != nil, let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            HStack(spacing: 13) {
                                Image(systemName: "trash")
                                    .font(.system(size: 24, weight: .regular))
                                Text("計画項目を削除")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: 0xFF3B30))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.hidden)
        .tint(AppColors.green)
    }

    private var selectedSubject: Subject? {
        subjects.first { $0.id == draft.subjectId } ?? subjects.first
    }

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 35, height: 5)
                .padding(.top, 20)
                .padding(.bottom, 29)

            ZStack {
                Text(item == nil ? "計画項目を追加" : "計画項目を編集")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(.label))

                HStack {
                    Button("キャンセル", action: onCancel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.green)

                    Spacer()

                    Button("保存", action: saveItem)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.green)
                        .disabled(subjects.isEmpty)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 25)
        .background(Color(.systemBackground))
    }

    private var editorCard: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(subjects) { subject in
                    Button {
                        draft.subjectId = subject.id
                    } label: {
                        Text(subject.name)
                    }
                }
            } label: {
                PlanItemEditorMenuRow(
                    title: "科目",
                    value: selectedSubject?.name ?? "未設定",
                    color: selectedSubject.map { Color(hex: $0.color) }
                )
            }
            .buttonStyle(.plain)

            PlanItemEditorDivider()

            Menu {
                ForEach(StudyWeekday.allCases) { day in
                    Button {
                        draft.dayOfWeek = day
                    } label: {
                        Text(day.japaneseTitle)
                    }
                }
            } label: {
                PlanItemEditorMenuRow(
                    title: "曜日",
                    value: draft.dayOfWeek.japaneseTitle,
                    color: nil
                )
            }
            .buttonStyle(.plain)

            PlanItemEditorDivider()

            HStack(spacing: 12) {
                Text("目標時間 （分）")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(.label))

                Spacer(minLength: 16)

                TextField("", text: $draft.targetMinutes)
                    .keyboardType(.numberPad)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 15)
                    .frame(width: 142, height: 47)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                    }

                Text("分")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .frame(height: 78)

            PlanItemEditorDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("時間帯")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(.label))

                    Spacer(minLength: 16)

                    TextField("", text: $draft.timeSlot)
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 15)
                        .frame(width: 210, height: 47)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
                        }
                }

                Text("例：19:00-20:30")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.leading, 190)
            }
            .frame(height: 103)
        }
        .padding(.horizontal, 18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xDADDE3), lineWidth: 1)
        }
    }

    private var inputGuide: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 14) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.green)
                Text("入力のガイド")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.green)
            }

            VStack(alignment: .leading, spacing: 15) {
                Text("・ 目標時間は 1 分以上で入力してください。")
                Text("・ 時間帯は 24 時間形式で入力してください。")
                Text("   例：19:00-20:30、07:30-08:15")
            }
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Color(.secondaryLabel))
            .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.greenSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.green.opacity(0.16), lineWidth: 1)
        }
    }

    private func saveItem() {
        guard let minutes = Int(draft.targetMinutes), minutes > 0 else { return }
        onSave(
            PlanItem(
                id: item?.id ?? 0,
                planId: item?.planId ?? activePlanId,
                subjectId: draft.subjectId,
                dayOfWeek: draft.dayOfWeek,
                targetMinutes: minutes,
                actualMinutes: item?.actualMinutes ?? 0,
                timeSlot: draft.timeSlot.nilIfBlank,
                createdAt: item?.createdAt ?? Date().epochMilliseconds,
                updatedAt: Date().epochMilliseconds
            )
        )
    }
}

private struct PlanItemEditorMenuRow: View {
    let title: String
    let value: String
    let color: Color?

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.label))

            Spacer(minLength: 16)

            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
            }

            Text(value)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.label))

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.systemGray3))
        }
        .frame(height: 76)
        .contentShape(Rectangle())
    }
}

private struct PlanItemEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xE4E5E8))
            .frame(height: 1)
    }
}

