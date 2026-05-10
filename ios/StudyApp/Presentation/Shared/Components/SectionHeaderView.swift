import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var icon: String?
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.success)
                    .font(.subheadline.bold())
                    .frame(width: 24, height: 24)
                    .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

struct GradientCard<Content: View>: View {
    let colors: [Color]
    @ViewBuilder var content: Content

    init(colors: [Color] = [Color(hex: 0x4CAF50), Color(hex: 0x2196F3)], @ViewBuilder content: () -> Content) {
        self.colors = colors
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
    }
}
