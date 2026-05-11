import SwiftUI

struct UrgencyBadge: View {
    let daysRemaining: Int

    private var color: Color {
        if daysRemaining < 7 { return AppColors.danger }
        if daysRemaining < 30 { return AppColors.warning }
        return AppColors.success
    }

    var body: some View {
        Text("あと\(max(daysRemaining, 0))日")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

struct MetricPill: View {
    let text: String
    var color: Color = .accentColor
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.bold())
            }
            Text(text)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct ColorDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
