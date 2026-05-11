import SwiftUI

struct TimetableReviewEditorSheet: View {
    let occurrence: TimetableReviewOccurrence
    let onSave: (Bool, String?) -> Void
    let onExclude: () -> Void
    let onRestore: () -> Void
    let onCancel: () -> Void

    @State private var note: String
    @State private var isReviewed: Bool
    private let noteLimit = 300

    init(
        occurrence: TimetableReviewOccurrence,
        onSave: @escaping (Bool, String?) -> Void,
        onExclude: @escaping () -> Void,
        onRestore: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.occurrence = occurrence
        self.onSave = onSave
        self.onExclude = onExclude
        self.onRestore = onRestore
        self.onCancel = onCancel
        _note = State(initialValue: occurrence.record?.note ?? "")
        _isReviewed = State(initialValue: occurrence.isReviewed)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCopy
                    .padding(.top, 10)

                lessonCard

                reviewStateCard

                memoCard
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("復習記録")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.green)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(isReviewed, normalizedNote)
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.green)
                .disabled(!occurrence.canReview && isReviewed)
            }
        }
    }

    private var headerCopy: some View {
        Text("この授業の復習を記録します。\n問題集の記録ではありません。")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .lineSpacing(3)
    }

    private var lessonCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 16) {
                TimetableReviewSectionTitle("授業情報")

                HStack(alignment: .center, spacing: 14) {
                    Circle()
                        .fill(Color(hex: 0x5B8FF9))
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(occurrence.entry.subjectName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        VStack(alignment: .leading, spacing: 12) {
                            TimetableReviewInfoRow(
                                icon: "clock",
                                primary: occurrence.period.name,
                                secondary: occurrence.period.timeRangeText
                            )

                            if let course = occurrence.entry.courseName, !course.isEmpty {
                                TimetableReviewInfoRow(icon: "book", primary: "講座名", secondary: course)
                            }

                            if let room = occurrence.entry.roomName, !room.isEmpty {
                                TimetableReviewInfoRow(icon: "building.2", primary: "教室", secondary: room)
                            }
                        }
                    }

                    Spacer(minLength: 6)

                    VStack(spacing: 7) {
                        Image(systemName: "calendar")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColors.green)
                            .frame(width: 34, height: 28)
                            .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(shortDateText)
                            .font(.caption.weight(.semibold))
                        Text(occurrence.term.name)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 84, height: 84)
                    .background(AppColors.greenSoft.opacity(0.85), in: Circle())
                }
            }
        }
    }

    private var reviewStateCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 18) {
                TimetableReviewSectionTitle("復習の状態")

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("復習済みにする")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("この授業を復習済みとして記録します。")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 14)

                    Toggle("", isOn: $isReviewed)
                        .labelsHidden()
                        .tint(AppColors.green)
                        .disabled(!occurrence.canReview && !occurrence.isReviewed)
                        .scaleEffect(1.08)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isReviewed ? "checkmark.circle" : statusIcon)
                        .font(.title3.weight(.semibold))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isReviewed ? "復習済み" : statusText)
                            .font(.headline.weight(.bold))
                        Text(reviewStateDescription)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(statusPanelColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusPanelColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(statusPanelColor.opacity(0.22), lineWidth: 1)
                }
            }
        }
    }

    private var memoCard: some View {
        TimetableReviewCard {
            VStack(alignment: .leading, spacing: 14) {
                TimetableReviewSectionTitle("メモ（任意）")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .frame(minHeight: 116)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        }

                    if note.isEmpty {
                        Text("授業の内容や復習したことをメモしてください...")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }

                    Text("\(note.count) / \(noteLimit)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, 18)
                        .allowsHitTesting(false)
                }
                .onChange(of: note) { newValue in
                    if newValue.count > noteLimit {
                        note = String(newValue.prefix(noteLimit))
                    }
                }

                Button(action: onExclude) {
                    TimetableReviewActionRow(
                        icon: "nosign",
                        title: "対象外にする",
                        subtitle: "この授業を復習の対象から外します。",
                        color: AppColors.danger,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(occurrence.isExcluded)
                .opacity(occurrence.isExcluded ? 0.55 : 1)

                Button(action: onRestore) {
                    TimetableReviewActionRow(
                        icon: "arrow.counterclockwise",
                        title: "対象外を戻す",
                        subtitle: "対象外にした状態を元に戻します。",
                        color: AppColors.orange,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(!occurrence.isExcluded)
                .opacity(occurrence.isExcluded ? 1 : 0.72)

                Text("※ 対象外にすると、この授業は復習の集計に含まれなくなります。")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
            }
        }
    }

    private var normalizedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var formattedDate: String {
        occurrence.date.formatted(date: .abbreviated, time: .omitted)
    }

    private var shortDateText: String {
        StudyFormatters.monthDayWithWeekday.string(from: occurrence.date)
    }

    private var statusText: String {
        switch occurrence.status {
        case .notAvailable: return "授業後に記録可"
        case .pending: return "未復習"
        case .overdue: return "期限超過"
        case .reviewed: return "復習済み"
        case .excluded: return "対象外"
        }
    }

    private var reviewStateDescription: String {
        if isReviewed {
            return "授業内容を振り返り、理解を確認した場合にオンにしてください。"
        }
        if occurrence.isExcluded {
            return "この授業は現在、復習の集計対象から外れています。"
        }
        return "復習が終わったらオンにして、右上の保存を押してください。"
    }

    private var statusColor: Color {
        switch occurrence.status {
        case .notAvailable: return AppColors.textSecondary
        case .pending, .overdue: return AppColors.danger
        case .reviewed: return AppColors.success
        case .excluded: return .secondary
        }
    }

    private var statusPanelColor: Color {
        isReviewed ? AppColors.green : statusColor
    }

    private var statusIcon: String {
        switch occurrence.status {
        case .notAvailable: return "clock"
        case .pending: return "exclamationmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .reviewed: return "checkmark.circle.fill"
        case .excluded: return "slash.circle.fill"
        }
    }
}

struct TimetableReviewCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

struct TimetableReviewSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(AppColors.green)
    }
}

struct TimetableReviewInfoRow: View {
    let icon: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .frame(width: 22)
            Text(primary)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .frame(minWidth: 44, alignment: .leading)
            Text(secondary)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

struct TimetableReviewActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }
}

