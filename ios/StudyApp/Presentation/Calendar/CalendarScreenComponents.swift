import SwiftUI

struct CalendarSummaryGridDay: Identifiable, Hashable {
    var date: Date
    var day: Int
    var weekday: Int
    var isCurrentMonth: Bool
    var minutes: Int

    var id: Int64 {
        date.startOfDay.epochMilliseconds
    }
}

struct CalendarSummaryDayCell: View {
    let item: CalendarSummaryGridDay
    let isSelected: Bool

    var body: some View {
        Text("\(item.day)")
            .font(.system(size: 17, weight: isSelected ? .bold : .regular))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? AppColors.success : Self.fillColor(minutes: item.minutes).opacity(item.isCurrentMonth ? 1 : 0.28))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white, lineWidth: 2)
                        .padding(2)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.success, lineWidth: 2)
                        .padding(0)
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabel("\(item.day)日 \(item.minutes)分")
    }

    static func fillColor(minutes: Int) -> Color {
        switch minutes {
        case 120...:
            return Color(hex: 0x08944A)
        case 60...119:
            return Color(hex: 0x58BE75)
        case 30...59:
            return Color(hex: 0x9EDFB0)
        case 1...29:
            return Color(hex: 0xE8F6EB)
        default:
            return Color(hex: 0xF8F9FA)
        }
    }

    private var textColor: Color {
        guard item.isCurrentMonth else { return AppColors.textSecondary.opacity(0.62) }
        if isSelected { return .white }
        if item.weekday == 1 { return Color(hex: 0xFF1D25) }
        if item.weekday == 7 { return Color(hex: 0x0A63C9) }
        return AppColors.textPrimary
    }
}

struct CalendarSummaryLegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                }
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CalendarMonthlyStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 18)
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer()
                    .frame(width: 18)
            }

            Text(value)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(AppColors.success)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

struct ProblemRecordDisplayGroup: Identifiable {
    let id: String
    let title: String
    let color: Color
    let labelsText: String
}

enum CalendarDetailDisplayMode: String, CaseIterable, Identifiable {
    case summary
    case timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "集計"
        case .timeline: return "時系列"
        }
    }
}
