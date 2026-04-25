import SwiftUI

// MARK: - Color Extensions

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

extension ColorTheme {
    var primaryColor: Color {
        Color(hex: hex)
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }
}

// MARK: - AppSpacing

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - AppColors

enum AppColors {
    static var cardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
    static var subtleBackground: Color {
        Color(.systemGroupedBackground)
    }
    static var textPrimary: Color {
        Color(.label)
    }
    static var textSecondary: Color {
        Color(.secondaryLabel)
    }
    static let success = Color(hex: 0x4CAF50)
    static let warning = Color(hex: 0xFF9800)
    static let danger = Color(hex: 0xF44336)
}

// MARK: - Typography Modifiers

struct HeroTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 42, weight: .bold, design: .rounded))
    }
}

struct SectionTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3.bold())
            .foregroundStyle(AppColors.textPrimary)
    }
}

struct BodyLargeStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(AppColors.textPrimary)
    }
}

struct BodySmallStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
    }
}

struct CaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
    }
}

struct StatValueStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .bold, design: .rounded))
    }
}

extension View {
    func heroTitleStyle() -> some View { modifier(HeroTitleStyle()) }
    func sectionTitleStyle() -> some View { modifier(SectionTitleStyle()) }
    func bodyLargeStyle() -> some View { modifier(BodyLargeStyle()) }
    func bodySmallStyle() -> some View { modifier(BodySmallStyle()) }
    func captionStyle() -> some View { modifier(CaptionStyle()) }
    func statValueStyle() -> some View { modifier(StatValueStyle()) }
}

// MARK: - CardStyle ViewModifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

extension View {
    func cardStyle(padding: CGFloat = AppSpacing.md) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - GradientCard

struct GradientCard<Content: View>: View {
    let colors: [Color]
    @ViewBuilder var content: Content

    init(colors: [Color] = [Color(hex: 0x4CAF50), Color(hex: 0x2196F3)], @ViewBuilder content: () -> Content) {
        self.colors = colors
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: colors.first?.opacity(0.3) ?? .clear, radius: 12, y: 6)
    }
}

// MARK: - ProgressRing

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var ringColor: Color = .accentColor
    var trackColor: Color = Color.secondary.opacity(0.15)
    var showPercentage: Bool = true
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - AnimatedProgressBar

struct AnimatedProgressBar: View {
    let value: Double
    var total: Double = 1.0
    var height: CGFloat = 10
    var barColor: Color = .accentColor
    var trackColor: Color = Color.secondary.opacity(0.15)
    @State private var animatedValue: Double = 0

    private var fraction: Double {
        total > 0 ? min(value / total, 1.0) : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor)
                    .frame(width: geometry.size.width * animatedValue, height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = fraction
            }
        }
        .onChange(of: value) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedValue = fraction
            }
        }
    }
}

// MARK: - StatCard

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
                .frame(width: 40, height: 40)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .padding(.bottom, AppSpacing.sm)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppColors.textPrimary)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            if let buttonTitle, let onAction {
                Button(action: onAction) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 12)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - SectionHeaderView

struct SectionHeaderView: View {
    let title: String
    var icon: String?
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                    .font(.subheadline.bold())
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .font(.subheadline.bold())
            }
        }
    }
}

// MARK: - StudySectionCard (legacy, updated)

struct StudySectionCard<Content: View>: View {
    let title: String
    let systemImage: String?
    @ViewBuilder var content: Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.tint)
                }
                Text(title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - PrimaryButtonStyle

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.tint)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Urgency Badge

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

// MARK: - QuickNavButton

struct QuickNavButton<Destination: View>: View {
    let icon: String
    let label: String
    let destination: Destination

    init(icon: String, label: String, @ViewBuilder destination: () -> Destination) {
        self.icon = icon
        self.label = label
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Simple BarChart

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

// MARK: - Stacked BarChart

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

// MARK: - HorizontalBarChart

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

// MARK: - Calendar Day Cell

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

// MARK: - ColorDot

struct ColorDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
