import SwiftUI

struct SimpleBarChart: View {
    let data: [(label: String, value: Double)]
    var barColor: Color = .accentColor
    var maxBarHeight: CGFloat = 120

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    if item.value > 0 {
                        Text("\(Int(item.value))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.gradient)
                        .frame(height: max(maxValue > 0 ? CGFloat(item.value / maxValue) * maxBarHeight : 0, item.value > 0 ? 4 : 0))
                    Text(item.label)
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct StackedBarSegment {
    var value: Double
    var color: Color
}

struct StackedBarChart: View {
    let data: [(label: String, value: Double, segments: [StackedBarSegment])]
    var maxBarHeight: CGFloat = 120

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    if item.value > 0 {
                        Text("\(Int(item.value))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(item.segments.enumerated()), id: \.offset) { _, segment in
                            Rectangle()
                                .fill(segment.color.gradient)
                                .frame(height: segmentHeight(segment.value, totalValue: item.value))
                        }
                    }
                    .frame(height: barHeight(item.value), alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text(item.label)
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(_ value: Double) -> CGFloat {
        max(maxValue > 0 ? CGFloat(value / maxValue) * maxBarHeight : 0, value > 0 ? 4 : 0)
    }

    private func segmentHeight(_ value: Double, totalValue: Double) -> CGFloat {
        guard totalValue > 0 else { return 0 }
        return CGFloat(value / totalValue) * barHeight(totalValue)
    }
}

struct HorizontalBarChart: View {
    let data: [(label: String, value: Double, color: Color)]

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                HStack(spacing: AppSpacing.sm) {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 70, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color.gradient)
                            .frame(width: maxValue > 0 ? max(CGFloat(item.value / maxValue) * geometry.size.width, item.value > 0 ? 4 : 0) : 0)
                    }
                    .frame(height: 14)

                    Text("\(Int(item.value))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}
