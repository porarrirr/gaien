import SwiftUI

struct SessionRatingBadge: View {
    let rating: Int
    var font: Font = .caption2.bold()
    var paddingHorizontal: CGFloat = 8
    var paddingVertical: CGFloat = 4

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(font)
            Text("\(rating)/5")
                .font(font)
        }
        .foregroundStyle(AppColors.warning)
        .padding(.horizontal, paddingHorizontal)
        .padding(.vertical, paddingVertical)
        .background(AppColors.warning.opacity(0.12), in: Capsule())
        .accessibilityLabel("評価 \(rating) / 5")
    }
}

struct SessionRatingSelector: View {
    @Binding var rating: Int?
    var allowsClearing = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                                .font(.title3)
                            Text("\(value)")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(value <= (rating ?? 0) ? AppColors.warning : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(value == rating ? AppColors.warning.opacity(0.14) : Color(.secondarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("評価 \(value)")
                }
            }

            if allowsClearing {
                Button("評価を外す") {
                    rating = nil
                }
                .font(.caption.bold())
                .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
