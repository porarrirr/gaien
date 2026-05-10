import SwiftUI

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
