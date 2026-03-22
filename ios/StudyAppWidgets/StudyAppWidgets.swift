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

private struct WidgetHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
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

private enum WidgetPalette {
    static let background = Color(hex: 0xFFFFFF)
    static let primary = Color(hex: 0x4CAF50)
    static let secondary = Color(hex: 0x2196F3)
    static let warning = Color(hex: 0xFF9800)
    static let danger = Color(hex: 0xF44336)
    static let track = Color.black.opacity(0.12)
    static let textPrimary = Color.black.opacity(0.87)
    static let textSecondary = Color.black.opacity(0.65)
}

private extension Color {
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
