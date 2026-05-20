import Foundation
import SwiftUI

// MARK: - Onboarding

struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(app: app))
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            step: "1.",
            title: "科目を作成する",
            description: "自分の勉強に合わせた科目を\n作成しましょう。",
            caption: "例）数学III、英語、化学 など",
            systemImage: "book",
            captionImage: "tag.fill",
            color: AppColors.success,
            softColor: AppColors.greenSoft
        ),
        OnboardingPage(
            step: "2.",
            title: "教材を追加する（任意）",
            description: "使っている問題集や参考書を登録して、\n進捗を管理できます。",
            caption: "後からいつでも追加できます",
            systemImage: "book.closed.fill",
            captionImage: "tag.fill",
            color: AppColors.blue,
            softColor: AppColors.blueSoft
        ),
        OnboardingPage(
            step: "3.",
            title: "学習を記録する",
            description: "タイマーで記録を開始して、\n学習を可視化していきましょう。",
            caption: "履歴・カレンダー・レポートで確認できます",
            systemImage: "timer",
            captionImage: "timer",
            color: AppColors.warning,
            softColor: AppColors.orangeSoft
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 16)

                    setupCard

                    dataStorageCard

                    actions
                        .padding(.top, 14)
                }
                .frame(maxWidth: min(proxy.size.width - 60, 380))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 26)
            }
            .background(onboardingBackground)
        }
    }

    private func onboardingStep(_ page: OnboardingPage) -> some View {
        HStack(spacing: 16) {
            Image(systemName: page.systemImage)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(page.color)
                .frame(width: 70, height: 70)
                .background(page.softColor.opacity(0.82), in: Circle())
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(page.step) \(page.title)")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(page.color)
                Text(page.description)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                MetricPill(text: page.caption, color: page.color, systemImage: page.captionImage)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x149529), Color(hex: 0x1DBA32)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "book.fill")
                    .font(.system(size: 39, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: -8, y: 6)

                Image(systemName: "pencil")
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-2))
                    .offset(x: 17, y: 1)
            }
            .padding(.bottom, 2)

            Text("StudyTrail")
                .font(.system(size: 43, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.success)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text("学習を記録して、積み重ねを見える化")
                .font(.system(size: 15.5, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("はじめに設定しましょう")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("最初にいくつか設定するだけで、すぐに学習記録を\n始められます。")
                .font(.system(size: 14.5))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(pages) { page in
                    onboardingStep(page)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private var dataStorageCard: some View {
        HStack(spacing: 15) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.success)

            VStack(alignment: .leading, spacing: 3) {
                Text("データは端末内に保存されます")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text("クラウド同期は後から設定できます（設定から）。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
            Image(systemName: "chevron.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(AppColors.greenSoft.opacity(0.66), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.success.opacity(0.18), lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.complete()
            } label: {
                Text("はじめる")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x0B9F25), Color(hex: 0x20B638)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.complete()
            } label: {
                Text("あとで設定する")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.success)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.clear, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppColors.success, lineWidth: 1.4)
                    }
            }
            .buttonStyle(.plain)

            Text("すべての設定は後から変更できます")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 7)
        }
        .padding(.horizontal, 8)
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [AppColors.subtleBackground, AppColors.cardBackground, AppColors.subtleBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Helpers

private struct OnboardingPage: Identifiable {
    var id: String { title }
    var step: String
    var title: String
    var description: String
    var caption: String
    var systemImage: String
    var captionImage: String
    var color: Color
    var softColor: Color
}
