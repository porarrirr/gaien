import Foundation
import SwiftUI

// MARK: - Onboarding

struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "学習時間を記録", description: "タイマーと手動入力で学習履歴を残せます。", systemImage: "timer", gradient: [Color(hex: 0x4CAF50), Color(hex: 0x66BB6A)]),
        OnboardingPage(title: "教材を管理", description: "教材の進捗や関連する科目をまとめて管理できます。", systemImage: "books.vertical.fill", gradient: [Color(hex: 0x2196F3), Color(hex: 0x42A5F5)]),
        OnboardingPage(title: "目標と計画", description: "日次・週次の目標と学習計画を Android と同じ考え方で扱います。", systemImage: "flag.fill", gradient: [Color(hex: 0xFF9800), Color(hex: 0xFFA726)])
    ]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: AppSpacing.lg)

            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text("StudyApp")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)

                Text("毎日の学習を、記録から復習までひとつに。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(pages) { page in
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: page.systemImage)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(page.title)
                                .font(.headline)
                            Text(page.description)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .cardStyle(padding: AppSpacing.md)
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Button {
                viewModel.complete()
            } label: {
                Text("はじめる")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)

            Button {
                viewModel.complete()
            } label: {
                Text("あとで設定する")
                    .font(.subheadline.bold())
            }

            Spacer(minLength: AppSpacing.lg)
        }
        .background(AppColors.subtleBackground)
    }
}

// MARK: - Helpers

private struct OnboardingPage: Identifiable {
    var id: String { title }
    var title: String
    var description: String
    var systemImage: String
    var gradient: [Color]
}
