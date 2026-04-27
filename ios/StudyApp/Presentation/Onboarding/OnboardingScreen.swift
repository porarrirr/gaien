import Foundation
import SwiftUI

// MARK: - Onboarding

struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel
    @State private var selection = 0

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "学習時間を記録", description: "タイマーと手動入力で学習履歴を残せます。", systemImage: "timer", gradient: [Color(hex: 0x4CAF50), Color(hex: 0x66BB6A)]),
        OnboardingPage(title: "教材を管理", description: "教材の進捗や関連する科目をまとめて管理できます。", systemImage: "books.vertical.fill", gradient: [Color(hex: 0x2196F3), Color(hex: 0x42A5F5)]),
        OnboardingPage(title: "目標と計画", description: "日次・週次の目標と学習計画を Android と同じ考え方で扱います。", systemImage: "flag.fill", gradient: [Color(hex: 0xFF9800), Color(hex: 0xFFA726)])
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        Image(systemName: page.systemImage)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 130, height: 130)
                            .background(
                                LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                            .shadow(color: page.gradient.first?.opacity(0.4) ?? .clear, radius: 16, y: 8)

                        Text(page.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppColors.textPrimary)

                        Text(page.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.xl)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicators
            HStack(spacing: 10) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == selection ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == selection ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: selection)
                }
            }
            .padding(.bottom, AppSpacing.lg)

            Button {
                viewModel.complete()
            } label: {
                Text(selection == pages.count - 1 ? "始める" : "スキップ")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.subtleBackground)
    }
}

// MARK: - Helpers

private struct OnboardingPage {
    var title: String
    var description: String
    var systemImage: String
    var gradient: [Color]
}
