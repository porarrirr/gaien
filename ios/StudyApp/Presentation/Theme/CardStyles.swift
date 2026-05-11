import SwiftUI

// MARK: - Loose (rounded) card

struct CardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(AppColors.cardBorder.opacity(0.9), lineWidth: 1)
            }
    }
}

extension View {
    func cardStyle(padding: CGFloat = AppSpacing.md) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Strict (dense settings) card

struct StrictScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.subtleBackground.ignoresSafeArea())
    }
}

struct StrictCardModifier: ViewModifier {
    var padding: CGFloat = StrictUI.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}

extension View {
    func strictScreen() -> some View {
        modifier(StrictScreenModifier())
    }

    func strictCard(padding: CGFloat = StrictUI.cardPadding) -> some View {
        modifier(StrictCardModifier(padding: padding))
    }
}
