import SwiftUI
import WidgetKit

private struct StudyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: StudyWidgetSnapshot
}

private struct StudyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyWidgetEntry {
        StudyWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyWidgetEntry) -> Void) {
        completion(loadEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyWidgetEntry>) -> Void) {
        let now = Date()
        let entry = loadEntry(for: now)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry(for date: Date) -> StudyWidgetEntry {
        let snapshot = (try? StudyWidgetSnapshotStore.read()) ?? .placeholder
        return StudyWidgetEntry(date: date, snapshot: snapshot)
    }
}

struct TodayStudyWidget: Widget {
    private let kind = "TodayStudyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            TodayStudyWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の学習")
        .description("今日の学習時間と進捗を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct WeeklyGoalWidget: Widget {
    private let kind = "WeeklyGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            WeeklyGoalWidgetView(entry: entry)
        }
        .configurationDisplayName("週間目標")
        .description("週間目標の達成率を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct StudyStreakWidget: Widget {
    private let kind = "StudyStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            StudyStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("連続学習")
        .description("連続学習日数と最長記録を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct ExamCountdownWidget: Widget {
    private let kind = "ExamCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            ExamCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("試験カウントダウン")
        .description("次の試験までの日数を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeeklyActivityWidget: Widget {
    private let kind = "WeeklyActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            WeeklyActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("週間アクティビティ")
        .description("直近7日間の学習推移を表示します。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DailyGoalWidget: Widget {
    private let kind = "DailyGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            DailyGoalWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の目標")
        .description("今日の学習目標までの残り時間を表示します。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct StudySummaryWidget: Widget {
    private let kind = "StudySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            StudySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("学習サマリー")
        .description("今日・今週・連続学習・試験をまとめて表示します。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct UpcomingExamListWidget: Widget {
    private let kind = "UpcomingExamListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            UpcomingExamListWidgetView(entry: entry)
        }
        .configurationDisplayName("試験一覧")
        .description("近い試験を一覧で確認できます。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WeeklyPaceWidget: Widget {
    private let kind = "WeeklyPaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyWidgetProvider()) { entry in
            WeeklyPaceWidgetView(entry: entry)
        }
        .configurationDisplayName("週間ペース")
        .description("今週の合計、平均、よく学習した日を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayStudyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.todayProgress) {
                Image(systemName: "clock.fill")
            } currentValueLabel: {
                Text(entry.snapshot.todayStudyMinutes.widgetCompactDurationText)
                    .font(.caption2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WidgetPalette.primary)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("今日の学習", systemImage: "clock.fill")
                    .font(.caption.bold())
                Text(entry.snapshot.todayStudyMinutes.widgetCompactDurationText)
                    .font(.headline.bold())
                Text(entry.snapshot.todayGoalCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .systemMedium:
            WidgetCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        WidgetHeader(title: "今日の学習", systemImage: "clock.fill")
                        Spacer()
                        Text(entry.snapshot.todaySessionText)
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }

                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            WidgetValueText(entry.snapshot.todayStudyMinutes.widgetDurationText, size: 30)
                            Text(entry.snapshot.todayGoalCaption)
                                .font(.caption)
                                .foregroundStyle(WidgetPalette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer(minLength: 0)
                        WidgetMiniProgress(progress: entry.snapshot.todayProgress, tint: WidgetPalette.primary)
                    }

                    WidgetProgressBar(progress: entry.snapshot.todayProgress, tint: WidgetPalette.primary)
                }
            }
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "今日の学習", systemImage: "clock.fill")
                    WidgetValueText(entry.snapshot.todayStudyMinutes.widgetDurationText, size: 30)
                    WidgetProgressBar(progress: entry.snapshot.todayProgress, tint: WidgetPalette.primary)
                    Text(entry.snapshot.todaySessionText)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct WeeklyGoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("週間目標", systemImage: "flag.fill")
                    .font(.caption.bold())
                Text(weeklyGoalTitle)
                    .font(.headline.bold())
                Text(weeklyGoalCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .systemMedium:
            WidgetCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        WidgetHeader(title: "週間目標", systemImage: "flag.fill")
                        Spacer()
                        Text(weeklyGoalCaption)
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 14) {
                        WidgetMiniProgress(progress: entry.snapshot.weeklyProgress, tint: WidgetPalette.primary)
                        VStack(alignment: .leading, spacing: 8) {
                            WidgetValueText(weeklyGoalTitle, size: 30)
                            Text(weeklyGoalRemainingText)
                                .font(.caption)
                                .foregroundStyle(WidgetPalette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer(minLength: 0)
                    }
                    WidgetProgressBar(progress: entry.snapshot.weeklyProgress, tint: WidgetPalette.primary)
                }
            }
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "週間目標", systemImage: "flag.fill")
                    WidgetValueText(weeklyGoalTitle, size: 30)
                    WidgetProgressBar(progress: entry.snapshot.weeklyProgress, tint: WidgetPalette.primary)
                    Text(weeklyGoalCaption)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var weeklyGoalTitle: String {
        guard let weeklyGoalMinutes = entry.snapshot.weeklyGoalMinutes, weeklyGoalMinutes > 0 else {
            return "未設定"
        }
        return "\(Int((entry.snapshot.weeklyProgress * 100).rounded()))%"
    }

    private var weeklyGoalCaption: String {
        guard let weeklyGoalMinutes = entry.snapshot.weeklyGoalMinutes, weeklyGoalMinutes > 0 else {
            return "目標を設定してください"
        }
        return "\(entry.snapshot.weeklyStudyMinutes.widgetDurationText) / \(weeklyGoalMinutes.widgetDurationText)"
    }

    private var weeklyGoalRemainingText: String {
        guard let weeklyGoalMinutes = entry.snapshot.weeklyGoalMinutes, weeklyGoalMinutes > 0 else {
            return "週間目標が未設定です"
        }
        let remaining = max(weeklyGoalMinutes - entry.snapshot.weeklyStudyMinutes, 0)
        return remaining == 0 ? "今週の目標を達成済み" : "残り \(remaining.widgetDurationText)"
    }
}

private struct DailyGoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.todayProgress) {
                Image(systemName: "target")
            } currentValueLabel: {
                Text("\(Int((entry.snapshot.todayProgress * 100).rounded()))%")
                    .font(.caption2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WidgetPalette.primary)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("今日の目標", systemImage: "target")
                    .font(.caption.bold())
                Text(goalStatusText)
                    .font(.headline.bold())
                Text(goalDetailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "今日の目標", systemImage: "target")
                    Text(goalStatusText)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    WidgetProgressBar(progress: entry.snapshot.todayProgress, tint: goalTint)
                    Text(goalDetailText)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
    }

    private var goalStatusText: String {
        guard let goal = entry.snapshot.dailyGoalMinutes, goal > 0 else {
            return "目標未設定"
        }
        let remaining = max(goal - entry.snapshot.todayStudyMinutes, 0)
        return remaining == 0 ? "達成済み" : "残り\(remaining.widgetDurationText)"
    }

    private var goalDetailText: String {
        guard let goal = entry.snapshot.dailyGoalMinutes, goal > 0 else {
            return "アプリで今日の目標を設定"
        }
        return "\(entry.snapshot.todayStudyMinutes.widgetDurationText) / \(goal.widgetDurationText)"
    }

    private var goalTint: Color {
        entry.snapshot.todayProgress >= 1 ? WidgetPalette.secondary : WidgetPalette.primary
    }
}

private struct StudyStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.streakProgress) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(entry.snapshot.streakDays)")
                    .font(.caption2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WidgetPalette.warning)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Label("連続学習", systemImage: "flame.fill")
                    .font(.caption.bold())
                Text("\(entry.snapshot.streakDays)日")
                    .font(.headline.bold())
                Text("最長 \(entry.snapshot.bestStreak)日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .systemMedium:
            WidgetCard {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        WidgetHeader(title: "連続学習", systemImage: "flame.fill")
                        WidgetValueText("\(entry.snapshot.streakDays)日", size: 34, tint: WidgetPalette.warning)
                        Text(streakMessage)
                            .font(.caption)
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetMetricTile(title: "最長", value: "\(entry.snapshot.bestStreak)日", systemImage: "trophy.fill", tint: WidgetPalette.warning)
                        WidgetMetricTile(title: "今日", value: entry.snapshot.todayStudyMinutes.widgetCompactDurationText, systemImage: "clock.fill", tint: WidgetPalette.primary)
                    }
                    .frame(maxWidth: 150)
                }
            }
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "連続学習", systemImage: "flame.fill")
                    WidgetValueText("\(entry.snapshot.streakDays)日", size: 32, tint: WidgetPalette.warning)
                    Text(streakMessage)
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                    Text("最長 \(entry.snapshot.bestStreak)日")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
    }

    private var streakMessage: String {
        entry.snapshot.streakDays > 0 ? "今日も継続中" : "今日の学習でスタート"
    }
}

private struct ExamCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            if let nextExam = entry.snapshot.upcomingExams.first {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: family == .systemMedium ? "試験カウントダウン" : "次の試験", systemImage: "book.fill")
                    Text(daysRemainingText(nextExam: nextExam))
                        .font(.system(size: family == .systemMedium ? 32 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(examColor(for: nextExam))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(nextExam.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text(dateText(for: nextExam.examDate))
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                    if family == .systemMedium {
                        ForEach(entry.snapshot.upcomingExams.dropFirst().prefix(2)) { exam in
                            CompactExamRow(exam: exam)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "試験カウントダウン", systemImage: "book.fill")
                    Spacer(minLength: 0)
                    WidgetValueText("予定なし", size: 28)
                    Text("今後の試験はありません")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct WeeklyActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            if family == .systemLarge {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        WidgetHeader(title: "週間アクティビティ", systemImage: "chart.bar.fill")
                        Spacer()
                        Text(entry.snapshot.generatedDateText)
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        WidgetMetricTile(title: "合計", value: entry.snapshot.weekTotalMinutes.widgetDurationText, systemImage: "sum", tint: WidgetPalette.primary)
                        WidgetMetricTile(title: "平均", value: entry.snapshot.weekAverageMinutes.widgetCompactDurationText, systemImage: "divide", tint: WidgetPalette.secondary)
                        WidgetMetricTile(title: "最多", value: entry.snapshot.bestActivityDayText, systemImage: "chart.bar.xaxis", tint: WidgetPalette.warning)
                    }
                    Divider()
                    WidgetBarChart(activity: entry.snapshot.weekActivity, showsValues: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        WidgetHeader(title: "今週の推移", systemImage: "chart.bar.fill")
                        Spacer()
                        Text(entry.snapshot.weekTotalMinutes.widgetDurationText)
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }
                    WidgetBarChart(activity: entry.snapshot.weekActivity, showsValues: false)
                }
            }
        }
    }
}

private struct StudySummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: family == .systemLarge ? 16 : 12) {
                HStack {
                    WidgetHeader(title: "学習サマリー", systemImage: "sparkles")
                    Spacer()
                    Text(entry.snapshot.generatedDateText)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 10) {
                    WidgetMetricTile(title: "今日", value: entry.snapshot.todayStudyMinutes.widgetDurationText, systemImage: "clock.fill", tint: WidgetPalette.primary)
                    WidgetMetricTile(title: "今週", value: entry.snapshot.weeklyStudyMinutes.widgetDurationText, systemImage: "calendar", tint: WidgetPalette.secondary)
                    WidgetMetricTile(title: "連続", value: "\(entry.snapshot.streakDays)日", systemImage: "flame.fill", tint: WidgetPalette.warning)
                    WidgetMetricTile(title: "次の試験", value: nextExamText, systemImage: "book.fill", tint: nextExamTint)
                }

                if family == .systemLarge {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("直近7日")
                                .font(.caption.bold())
                                .foregroundStyle(WidgetPalette.textSecondary)
                            Spacer()
                            Text("合計 \(entry.snapshot.weekTotalMinutes.widgetDurationText)")
                                .font(.caption2)
                                .foregroundStyle(WidgetPalette.textSecondary)
                        }
                        WidgetBarChart(activity: entry.snapshot.weekActivity)
                    }
                }
            }
        }
    }

    private var summaryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private var nextExamText: String {
        guard let exam = entry.snapshot.upcomingExams.first else { return "予定なし" }
        return daysRemainingText(nextExam: exam)
    }

    private var nextExamTint: Color {
        guard let exam = entry.snapshot.upcomingExams.first else { return WidgetPalette.textSecondary }
        return examColor(for: exam)
    }
}

private struct UpcomingExamListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 12) {
                WidgetHeader(title: "試験一覧", systemImage: "list.bullet.clipboard.fill")
                if entry.snapshot.upcomingExams.isEmpty {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("予定なし")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetPalette.textPrimary)
                        Text("登録した試験がここに表示されます")
                            .font(.caption)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entry.snapshot.upcomingExams.prefix(family == .systemLarge ? 3 : 2)) { exam in
                            ExamListRow(exam: exam)
                        }
                    }
                    if family == .systemLarge {
                        Spacer(minLength: 0)
                        Text("近い順に最大3件")
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }
                }
            }
        }
    }
}

private struct WeeklyPaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            switch family {
            case .systemMedium:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        WidgetHeader(title: "週間ペース", systemImage: "speedometer")
                        Spacer()
                        Text("平均 \(entry.snapshot.weekAverageMinutes.widgetCompactDurationText)")
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                    }
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.snapshot.weekTotalMinutes.widgetDurationText)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetPalette.textPrimary)
                            Text(bestDayText)
                                .font(.caption)
                                .foregroundStyle(WidgetPalette.textSecondary)
                        }
                        WidgetBarChart(activity: entry.snapshot.weekActivity)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "週間ペース", systemImage: "speedometer")
                    Text(entry.snapshot.weekAverageMinutes.widgetDurationText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text("1日平均")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                    Text(bestDayText)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
    }

    private var bestDayText: String {
        guard let best = entry.snapshot.bestActivityDay, best.minutes > 0 else {
            return "今週の学習はこれから"
        }
        return "最多 \(best.dayLabel)曜 \(best.minutes.widgetDurationText)"
    }
}

private struct WidgetHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(WidgetPalette.textSecondary)
    }
}

private struct WidgetValueText: View {
    let value: String
    let size: CGFloat
    let tint: Color

    init(_ value: String, size: CGFloat, tint: Color = WidgetPalette.textPrimary) {
        self.value = value
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

private struct WidgetMetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption2.bold())
                .foregroundStyle(WidgetPalette.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WidgetMiniProgress: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 72, height: 72)
    }
}

private struct ExamListRow: View {
    let exam: StudyWidgetExamSummary

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 2) {
                Text(exam.daysRemaining <= 0 ? "今日" : "\(exam.daysRemaining)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(examColor(for: exam))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if exam.daysRemaining > 0 {
                    Text("日")
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
            .frame(width: 46, height: 46)
            .background(examColor(for: exam).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(exam.name)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                Text(dateText(for: exam.examDate))
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CompactExamRow: View {
    let exam: StudyWidgetExamSummary

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(examColor(for: exam).opacity(0.16))
                .frame(width: 8, height: 8)
            Text(exam.name)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(daysRemainingText(nextExam: exam))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption2)
        .foregroundStyle(WidgetPalette.textSecondary)
    }
}

private struct WidgetProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = progress > 0 ? max(proxy.size.width * CGFloat(progress), 8) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetPalette.track)
                Capsule()
                    .fill(tint)
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }
}

private struct WidgetBarChart: View {
    let activity: [StudyWidgetActivitySummary]
    var showsValues: Bool = false

    var body: some View {
        let maxMinutes = max(activity.map(\.minutes).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(activity) { item in
                VStack(spacing: 5) {
                    if showsValues {
                        Text(item.minutes.widgetCompactDurationText)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    GeometryReader { proxy in
                        let availableHeight = max(proxy.size.height, 1)
                        let ratio = CGFloat(item.minutes) / CGFloat(maxMinutes)
                        let barHeight = max(availableHeight * ratio, item.minutes == 0 ? 4 : 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.isToday ? WidgetPalette.secondary : WidgetPalette.primary)
                            .frame(height: barHeight)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    Text(item.dayLabel)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: showsValues ? 112 : 78)
    }
}

private struct WidgetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .modifier(WidgetBackgroundModifier())
    }
}

private struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                WidgetPalette.background
            }
        } else {
            content.background(WidgetPalette.background)
        }
    }
}

enum WidgetPalette {
    static let background = Color(hex: 0xFFFFFF)
    static let primary = Color(hex: 0x4CAF50)
    static let secondary = Color(hex: 0x2196F3)
    static let warning = Color(hex: 0xFF9800)
    static let danger = Color(hex: 0xF44336)
    static let track = Color.black.opacity(0.12)
    static let textPrimary = Color.black.opacity(0.87)
    static let textSecondary = Color.black.opacity(0.65)
}

private extension StudyWidgetSnapshot {
    var todaySessionText: String {
        todaySessionCount > 0 ? "\(todaySessionCount)件のセッション" : "タップして学習開始"
    }

    var todayGoalCaption: String {
        guard let dailyGoalMinutes, dailyGoalMinutes > 0 else {
            return "今日の目標は未設定"
        }
        let remaining = max(dailyGoalMinutes - todayStudyMinutes, 0)
        return remaining == 0 ? "今日の目標を達成" : "目標まで残り \(remaining.widgetDurationText)"
    }

    var generatedDateText: String {
        Date(timeIntervalSince1970: TimeInterval(generatedAt) / 1_000)
            .formatted(date: .omitted, time: .shortened)
    }

    var streakProgress: Double {
        guard bestStreak > 0 else { return streakDays > 0 ? 1 : 0 }
        return min(max(Double(streakDays) / Double(bestStreak), 0), 1)
    }

    var weekAverageMinutes: Int {
        guard !weekActivity.isEmpty else { return 0 }
        return Int((Double(weekTotalMinutes) / Double(weekActivity.count)).rounded())
    }

    var bestActivityDay: StudyWidgetActivitySummary? {
        weekActivity.max { lhs, rhs in
            lhs.minutes < rhs.minutes
        }
    }

    var bestActivityDayText: String {
        guard let bestActivityDay, bestActivityDay.minutes > 0 else {
            return "なし"
        }
        return "\(bestActivityDay.dayLabel)曜"
    }
}

extension Color {
    init(hex: Int) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private func examColor(for exam: StudyWidgetExamSummary) -> Color {
    switch exam.daysRemaining {
    case ..<4:
        return WidgetPalette.danger
    case 4...7:
        return WidgetPalette.warning
    default:
        return WidgetPalette.primary
    }
}

private func daysRemainingText(nextExam: StudyWidgetExamSummary) -> String {
    nextExam.daysRemaining <= 0 ? "今日" : "あと\(nextExam.daysRemaining)日"
}

private func dateText(for date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
}
