import SwiftUI

struct CalendarDayCell: View {
    let day: Int
    let minutes: Int
    let isToday: Bool
    let isSelected: Bool
    let maxMinutes: Int

    private var level: Int {
        guard maxMinutes > 0, minutes > 0 else { return 0 }
        let ratio = Double(minutes) / Double(maxMinutes)
        switch ratio {
        case 0.75...:
            return 4
        case 0.5...:
            return 3
        case 0.25...:
            return 2
        default:
            return 1
        }
    }

    private var heatmapColor: Color {
        switch level {
        case 1:
            return Color(hex: 0xDDEEDB)
        case 2:
            return Color(hex: 0x9BD58A)
        case 3:
            return Color(hex: 0x5AAD5A)
        case 4:
            return Color(hex: 0x2E7D32)
        default:
            return Color(.systemFill).opacity(0.45)
        }
    }

    private var textColor: Color {
        if isSelected { return .white }
        if level >= 3 { return .white }
        if minutes > 0 { return AppColors.textPrimary }
        return AppColors.textSecondary
    }

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if isToday { return AppColors.textSecondary.opacity(0.8) }
        return Color(.separator).opacity(0.35)
    }

    var body: some View {
        ZStack {
            if day > 0 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : heatmapColor)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isToday || isSelected ? 2 : 1)

                Text("\(day)")
                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 6)
                    .padding(.leading, 6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct CalendarHeatmapLegend: View {
    let hasData: Bool

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("少")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: hasData ? level : 0))
                    .frame(width: 12, height: 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                    }
            }

            Text("多")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 1:
            return Color(hex: 0xDDEEDB)
        case 2:
            return Color(hex: 0x9BD58A)
        case 3:
            return Color(hex: 0x5AAD5A)
        case 4:
            return Color(hex: 0x2E7D32)
        default:
            return Color(.systemFill).opacity(0.45)
        }
    }
}
