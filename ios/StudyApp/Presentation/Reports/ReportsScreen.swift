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
            LazyVStack(spacing: 10) {
                streakSection

                reportChartCard(
                    title: "日別学習時間",
                    subtitle: "（直近7日）",
                    total: dailyTotalText,
                    axisLabels: chartAxisLabels(scaleMinutes: dailyScaleMinutes, divisions: 3),
                    scaleMinutes: dailyScaleMinutes,
                    items: dailyChartItems
                )

                reportChartCard(
                    title: "週別学習時間",
                    subtitle: "（直近4週間）",
                    total: weeklyTotalText,
                    axisLabels: chartAxisLabels(scaleMinutes: weeklyScaleMinutes, divisions: 2),
                    scaleMinutes: weeklyScaleMinutes,
                    items: weeklyChartItems
                )

                ratingSummarySection
                subjectSection
            }
            .padding(.horizontal, StrictUI.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .strictScreen()
        .navigationTitle("レポート")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "calendar")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
        }
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }

    private var streakSection: some View {
        HStack(spacing: 10) {
            reportMetricCard(
                icon: "calendar",
                title: "連続日数",
                value: "\(viewModel.reports.streakDays)",
                suffix: "日",
                subtitle: "今日も継続中！"
            )
            reportMetricCard(
                icon: "trophy.fill",
                title: "最長記録",
                value: "\(viewModel.reports.bestStreak)",
                suffix: "日",
                subtitle: "2026/4/10 - 5/2"
            )
        }
    }

    private var ratingSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            reportTitle("平均評価", subtitle: "（★は5段階評価）")
            VStack(spacing: 8) {
                ratingAverageCard(title: "今日", summary: viewModel.reports.ratingAverages.today)
                ratingAverageCard(title: "今週", summary: viewModel.reports.ratingAverages.week)
                ratingAverageCard(title: "今月", summary: viewModel.reports.ratingAverages.month)
            }
        }
        .reportCard(padding: 10)
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "科目別", subtitle: "（今月）", total: subjectTotalText)
            if viewModel.reports.bySubject.isEmpty {
                emptyText
            } else {
                SubjectBarList(items: subjectBreakdownItems)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                SubjectTable(items: subjectBreakdownItems, totalText: subjectTotalText)
            }
        }
        .reportCard(padding: 10)
    }

    private var emptyText: some View {
        Text("データがありません")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, AppSpacing.lg)
    }

    private func reportChartCard(
        title: String,
        subtitle: String,
        total: String,
        axisLabels: [String],
        scaleMinutes: Int,
        items: [ReportStackedBarItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: title, subtitle: subtitle, total: total)
            if items.isEmpty {
                emptyText
            } else {
                ReportStackedBarChart(
                    items: items,
                    axisLabels: axisLabels,
                    scaleMinutes: scaleMinutes
                )
                reportLegend
                    .padding(.top, 2)
            }
        }
        .reportCard(padding: 10)
    }

    private var reportLegend: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), alignment: .leading, spacing: 8) {
            ForEach(legendItems) { item in
                HStack(spacing: 5) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    Text(item.name)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ratingAverageCard(title: String, summary: RatingAverageSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 42, alignment: .leading)
                RatingStars(average: summary.average)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary.average.map { String(format: "%.1f", $0) } ?? "-")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.success)
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                reportValueRow(title: "評価付き", value: summary.ratedMinutes > 0 ? Goal.format(minutes: summary.ratedMinutes) : "0分")
                reportValueRow(title: "未評価", value: "0分")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func reportValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
            Spacer(minLength: 6)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func reportMetricCard(icon: String, title: String, value: String, suffix: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppColors.success)
                .frame(width: 64, height: 64)
                .background(AppColors.greenSoft, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.success)
                        .monospacedDigit()
                    Text(suffix)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.success)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .reportCard(padding: 12)
    }

    private func sectionHeader(title: String, subtitle: String, total: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            reportTitle(title, subtitle: subtitle)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("合計")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(total)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    private func reportTitle(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private var dailyChartItems: [ReportStackedBarItem] {
        viewModel.reports.daily.suffix(7).enumerated().map { index, item in
            let parts = splitDayLabel(item.dateLabel)
            return ReportStackedBarItem(
                topLabel: Goal.format(minutes: item.minutes),
                primaryLabel: parts.date,
                secondaryLabel: parts.weekday,
                valueMinutes: item.minutes,
                segments: item.segments.map {
                    ReportStackedSegment(minutes: $0.minutes, color: Color(hex: $0.color))
                },
                isEmphasized: index == viewModel.reports.daily.suffix(7).count - 1
            )
        }
    }

    private var weeklyChartItems: [ReportStackedBarItem] {
        viewModel.reports.weekly.suffix(4).enumerated().map { index, item in
            let totalMinutes = item.hours * 60 + item.minutes
            return ReportStackedBarItem(
                topLabel: Goal.format(minutes: totalMinutes),
                primaryLabel: item.weekLabel.replacingOccurrences(of: "週", with: ""),
                secondaryLabel: "",
                valueMinutes: totalMinutes,
                segments: item.segments.map {
                    ReportStackedSegment(minutes: $0.minutes, color: Color(hex: $0.color))
                },
                isEmphasized: index == viewModel.reports.weekly.suffix(4).count - 1
            )
        }
    }

    private var legendItems: [ReportLegendItem] {
        viewModel.reports.bySubject.prefix(6).map {
            ReportLegendItem(name: $0.subjectName, color: Color(hex: $0.color))
        }
    }

    private var subjectBreakdownItems: [SubjectBreakdownItem] {
        let total = max(viewModel.reports.bySubject.reduce(0) { $0 + $1.hours * 60 + $1.minutes }, 1)
        return viewModel.reports.bySubject.prefix(6).map { item in
            let minutes = item.hours * 60 + item.minutes
            return SubjectBreakdownItem(
                name: item.subjectName,
                minutes: minutes,
                timeText: Goal.format(minutes: minutes),
                percent: Int((Double(minutes) / Double(total) * 100).rounded()),
                color: Color(hex: item.color)
            )
        }
    }

    private var dailyScaleMinutes: Int {
        max(180, nextWholeHourScale(minutes: viewModel.reports.daily.suffix(7).map(\.minutes).max() ?? 0))
    }

    private var weeklyScaleMinutes: Int {
        let maxMinutes = viewModel.reports.weekly.suffix(4).map { $0.hours * 60 + $0.minutes }.max() ?? 0
        return max(20 * 60, nextWholeHourScale(minutes: maxMinutes))
    }

    private var dailyTotalText: String {
        Goal.format(minutes: viewModel.reports.daily.suffix(7).reduce(0) { $0 + $1.minutes })
    }

    private var weeklyTotalText: String {
        let minutes = viewModel.reports.weekly.suffix(4).reduce(0) { $0 + $1.hours * 60 + $1.minutes }
        return Goal.format(minutes: minutes)
    }

    private var subjectTotalText: String {
        let minutes = viewModel.reports.bySubject.reduce(0) { $0 + $1.hours * 60 + $1.minutes }
        return Goal.format(minutes: minutes)
    }

    private func splitDayLabel(_ label: String) -> (date: String, weekday: String) {
        let cleaned = label.replacingOccurrences(of: ")", with: "")
        let parts = cleaned.components(separatedBy: " (")
        return (parts.first ?? label, parts.dropFirst().first ?? "")
    }

    private func nextWholeHourScale(minutes: Int) -> Int {
        guard minutes > 0 else { return 60 }
        return Int(ceil(Double(minutes) / 60.0)) * 60
    }

    private func chartAxisLabels(scaleMinutes: Int, divisions: Int) -> [String] {
        guard divisions > 0 else { return [compactAxisLabel(minutes: scaleMinutes), "0分"] }
        return (0...divisions).map { index in
            let minutes = Int((Double(scaleMinutes) * Double(divisions - index) / Double(divisions)).rounded())
            return compactAxisLabel(minutes: minutes)
        }
    }

    private func compactAxisLabel(minutes: Int) -> String {
        guard minutes > 0 else { return "0分" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 { return "\(remainingMinutes)分" }
        if remainingMinutes == 0 { return "\(hours)時間" }
        if remainingMinutes == 30 { return "\(hours)時間半" }
        return "\(hours)h\(remainingMinutes)m"
    }
}

private struct ReportStackedSegment: Identifiable {
    let id = UUID()
    var minutes: Int
    var color: Color
}

private struct ReportStackedBarItem: Identifiable {
    let id = UUID()
    var topLabel: String
    var primaryLabel: String
    var secondaryLabel: String
    var valueMinutes: Int
    var segments: [ReportStackedSegment]
    var isEmphasized: Bool
}

private struct ReportLegendItem: Identifiable {
    let id = UUID()
    var name: String
    var color: Color
}

private struct SubjectBreakdownItem: Identifiable {
    let id = UUID()
    var name: String
    var minutes: Int
    var timeText: String
    var percent: Int
    var color: Color
}

private struct ReportStackedBarChart: View {
    let items: [ReportStackedBarItem]
    let axisLabels: [String]
    let scaleMinutes: Int

    private var barSpacing: CGFloat {
        items.count > 4 ? 10 : 28
    }

    private var barWidth: CGFloat {
        items.count > 4 ? 30 : 52
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .trailing) {
                ForEach(axisLabels.indices, id: \.self) { index in
                    Text(axisLabels[index])
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.82))
                    if index < axisLabels.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: 54, height: 194)
            .padding(.bottom, 36)

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(AppColors.cardBorder)
                            .frame(height: 1)
                            .frame(maxHeight: .infinity, alignment: .bottom)

                        HStack(alignment: .bottom, spacing: barSpacing) {
                            ForEach(items) { item in
                                ReportStackedBar(
                                    item: item,
                                    scaleMinutes: scaleMinutes,
                                    plotHeight: geometry.size.height - 58,
                                    barWidth: barWidth
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
                .frame(height: 252)
            }
        }
    }
}

private struct ReportStackedBar: View {
    let item: ReportStackedBarItem
    let scaleMinutes: Int
    let plotHeight: CGFloat
    let barWidth: CGFloat

    private var barHeight: CGFloat {
        guard scaleMinutes > 0, item.valueMinutes > 0 else { return 0 }
        return max(CGFloat(item.valueMinutes) / CGFloat(scaleMinutes) * plotHeight, 4)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(item.valueMinutes > 0 ? item.topLabel : "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.isEmphasized ? AppColors.success : AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: 18)

            VStack(spacing: 0) {
                ForEach(item.segments) { segment in
                    Rectangle()
                        .fill(segment.color.gradient)
                        .frame(height: segmentHeight(segment.minutes))
                }
            }
            .frame(width: barWidth, height: barHeight, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .frame(height: plotHeight, alignment: .bottom)

            VStack(spacing: 1) {
                Text(item.primaryLabel)
                    .font(.system(size: 13, weight: .regular))
                if !item.secondaryLabel.isEmpty {
                    Text(item.secondaryLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(item.isEmphasized ? AppColors.success : AppColors.textPrimary.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    private func segmentHeight(_ minutes: Int) -> CGFloat {
        guard item.valueMinutes > 0 else { return 0 }
        return CGFloat(minutes) / CGFloat(item.valueMinutes) * barHeight
    }
}

private struct RatingStars: View {
    var average: Double?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: starName(for: value))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(starColor(for: value))
            }
        }
    }

    private func starColor(for value: Int) -> Color {
        guard let average else { return Color(hex: 0xAEB4BD) }
        return Double(value) - average <= 0.5 ? AppColors.success : Color(hex: 0xAEB4BD)
    }

    private func starName(for value: Int) -> String {
        guard let average else { return "star" }
        if Double(value) <= average.rounded(.down) { return "star.fill" }
        if Double(value) - average <= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

private struct SubjectBarList: View {
    let items: [SubjectBreakdownItem]

    private var maxMinutes: Int {
        max(items.map(\.minutes).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(item.color.gradient)
                                .frame(width: max(CGFloat(item.minutes) / CGFloat(maxMinutes) * geometry.size.width, 8))
                        }
                        .frame(height: 14)

                        Text("\(item.timeText)（\(item.percent)%）")
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 116, alignment: .trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
        }
    }
}

private struct SubjectTable: View {
    let items: [SubjectBreakdownItem]
    let totalText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("時間")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("割合")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 48, alignment: .trailing)
            }
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 13, height: 13)
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text(item.timeText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 96, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(item.percent)%")
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)
            HStack {
                Text("合計")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(totalText)
                    .font(.caption.weight(.semibold))
                    .frame(width: 96, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("100%")
                    .font(.caption.weight(.semibold))
                    .frame(width: 48, alignment: .trailing)
            }
            .foregroundStyle(AppColors.success)
        }
    }
}

private extension View {
    func reportCard(padding: CGFloat = 10) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}
