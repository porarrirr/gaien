import SwiftUI

struct StrictSheetHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

struct StrictRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: StrictUI.rowHeight)
    }
}

struct StrictIcon: View {
    let systemName: String
    var color: Color = AppColors.success

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct StrictSectionTitle: View {
    let title: String
    var icon: String?
    var color: Color = AppColors.success

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                StrictIcon(systemName: icon, color: color)
            }
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Spacer()
        }
    }
}

struct StrictSegmentedButton: View {
    let title: String
    let selected: Bool
    var color: Color = AppColors.success
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? .white : color)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(selected ? color : color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? Color.clear : color.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct StrictMetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    var icon: String?
    var color: Color = AppColors.success

    var body: some View {
        HStack(spacing: 9) {
            if let icon {
                StrictIcon(systemName: icon, color: color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .strictCard(padding: 9)
    }
}
