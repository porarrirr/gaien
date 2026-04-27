import Foundation
import SwiftUI

// MARK: - ReportsScreen

struct ReportsScreen: View {
    @StateObject private var viewModel: ReportsViewModel

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Streak Section
                streakSection
                    .padding(.horizontal, AppSpacing.md)

                // Daily Chart
                dailyChartSection
                    .padding(.horizontal, AppSpacing.md)

                // Weekly Chart
                weeklyChartSection
                    .padding(.horizontal, AppSpacing.md)

                // Rating Summary
                ratingSummarySection
                    .padding(.horizontal, AppSpacing.md)

                // Subject Breakdown
                subjectSection
                    .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("レポート")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }

    private var streakSection: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.sm) {
                Text("🔥")
                    .font(.system(size: 36))
                Text("\(viewModel.reports.streakDays)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.reports.streakDays > 0 ? AppColors.warning : AppColors.textSecondary)
                Text("連続日数")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            VStack(spacing: AppSpacing.sm) {
                Text("🏆")
                    .font(.system(size: 36))
                Text("\(viewModel.reports.bestStreak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.success)
                Text("最長記録")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }

    private var dailyChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "日別学習時間", icon: "chart.bar.fill")
            if viewModel.reports.daily.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                StackedBarChart(
                    data: viewModel.reports.daily.suffix(7).map { item in
                        (
                            label: String(item.dateLabel.suffix(3)),
                            value: Double(item.minutes),
                            segments: item.segments.map { segment in
                                StackedBarSegment(value: Double(segment.minutes), color: Color(hex: segment.color))
                            }
                        )
                    },
                    maxBarHeight: 140
                )
            }
        }
        .cardStyle()
    }

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "週別学習時間", icon: "calendar")
            if viewModel.reports.weekly.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                StackedBarChart(
                    data: viewModel.reports.weekly.suffix(4).map { item in
                        (
                            label: item.weekLabel,
                            value: Double(item.hours * 60 + item.minutes),
                            segments: item.segments.map { segment in
                                StackedBarSegment(value: Double(segment.minutes), color: Color(hex: segment.color))
                            }
                        )
                    },
                    maxBarHeight: 120
                )
            }
        }
        .cardStyle()
    }

    private var ratingSummarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "平均評価", icon: "star.fill")
            VStack(spacing: AppSpacing.sm) {
                ratingAverageCard(title: "今日", summary: viewModel.reports.ratingAverages.today)
                ratingAverageCard(title: "今週", summary: viewModel.reports.ratingAverages.week)
                ratingAverageCard(title: "今月", summary: viewModel.reports.ratingAverages.month)
            }
        }
        .cardStyle()
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(title: "科目別", icon: "square.grid.2x2.fill")
            if viewModel.reports.bySubject.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                HorizontalBarChart(
                    data: viewModel.reports.bySubject.map { item in
                        (
                            label: item.subjectName,
                            value: Double(item.hours * 60 + item.minutes),
                            color: Color(hex: item.color)
                        )
                    }
                )

                Divider()

                ForEach(viewModel.reports.bySubject) { item in
                    HStack(spacing: AppSpacing.sm) {
                        ColorDot(color: Color(hex: item.color), size: 12)
                        Text(item.subjectName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.hours)時間\(item.minutes)分")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func ratingAverageCard(title: String, summary: RatingAverageSummary) -> some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(summary.ratedMinutes > 0 ? "評価対象 \(Goal.format(minutes: summary.ratedMinutes))" : "評価データなし")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            if let average = summary.average {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppColors.warning)
                    Text(String(format: "%.1f / 5", average))
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                }
            } else {
                Text("未評価")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemFill))
        )
    }
}
