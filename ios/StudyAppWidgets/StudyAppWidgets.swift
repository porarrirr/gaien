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
        .supportedFamilies([.systemSmall, .accessoryCircular])
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
        .supportedFamilies([.systemSmall])
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
        .supportedFamilies([.systemSmall, .accessoryRectangular])
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
        .supportedFamilies([.systemMedium])
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
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(title: "今日の学習", systemImage: "clock.fill")
                    Text(entry.snapshot.todayStudyMinutes.widgetDurationText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    WidgetProgressBar(progress: entry.snapshot.todayProgress, tint: WidgetPalette.primary)
                    Text(entry.snapshot.todaySessionCount > 0 ? "\(entry.snapshot.todaySessionCount)件のセッション" : "タップして学習開始")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
    }
}

private struct WeeklyGoalWidgetView: View {
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "週間目標", systemImage: "flag.fill")
                if let weeklyGoalMinutes = entry.snapshot.weeklyGoalMinutes, weeklyGoalMinutes > 0 {
                    Text("\(Int((entry.snapshot.weeklyProgress * 100).rounded()))%")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    WidgetProgressBar(progress: entry.snapshot.weeklyProgress, tint: WidgetPalette.primary)
                    Text("\(entry.snapshot.weeklyStudyMinutes.widgetDurationText) / \(weeklyGoalMinutes.widgetDurationText)")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                } else {
                    Text("未設定")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text("目標を設定してください")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
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
        default:
            WidgetCard {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "連続学習", systemImage: "flame.fill")
                    Text("\(entry.snapshot.streakDays)日")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text(entry.snapshot.streakDays > 0 ? "今日も継続中" : "今日の学習でスタート")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                    Text("最長 \(entry.snapshot.bestStreak)日")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
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
                    Text(nextExam.name)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text(dateText(for: nextExam.examDate))
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                    if family == .systemMedium {
                        ForEach(entry.snapshot.upcomingExams.dropFirst().prefix(2)) { exam in
                            HStack {
                                Text(exam.name)
                                    .lineLimit(1)
                                Spacer()
                                Text(daysRemainingText(nextExam: exam))
                            }
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.textSecondary)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(title: "試験カウントダウン", systemImage: "book.fill")
                    Text("予定なし")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    Text("今後の試験はありません")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
            }
        }
    }
}

private struct WeeklyActivityWidgetView: View {
    let entry: StudyWidgetEntry

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    WidgetHeader(title: "今週の推移", systemImage: "chart.bar.fill")
                    Spacer()
                    Text(entry.snapshot.weekTotalMinutes.widgetDurationText)
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
                WidgetBarChart(activity: entry.snapshot.weekActivity)
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

    var body: some View {
        let maxMinutes = max(activity.map(\.minutes).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(activity) { item in
                VStack(spacing: 6) {
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
            }
        }
        .frame(height: 78)
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
    var generatedDateText: String {
        Date(timeIntervalSince1970: TimeInterval(generatedAt) / 1_000)
            .formatted(date: .omitted, time: .shortened)
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
