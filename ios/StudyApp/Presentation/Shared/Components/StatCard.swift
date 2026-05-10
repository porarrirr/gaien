import SwiftUI

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12), in: Circle())

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}
