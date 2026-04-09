#if canImport(ActivityKit) && !LIVE_ACTIVITY_DISABLED
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct StudyTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerActivityAttributes.self) { context in
            StudyTimerLiveActivityView(context: context)
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(WidgetPalette.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.subjectName)
                            .font(.headline.bold())
                            .foregroundStyle(WidgetPalette.textPrimary)
                            .lineLimit(1)
                        if let detail = expandedDetailText(for: context), !detail.isEmpty {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(WidgetPalette.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        LiveActivityTimerText(state: context.state)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(WidgetPalette.textPrimary)
                        LiveActivityStatusBadge(isRunning: context.state.isRunning)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        liveActivityBottomSummary(for: context)
                        Spacer(minLength: 8)
                        Text(context.attributes.displayPreset.title)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(WidgetPalette.primary, in: Capsule())
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(WidgetPalette.primary)
            } compactTrailing: {
                LiveActivityTimerText(state: context.state)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(WidgetPalette.textPrimary)
            } minimal: {
                Image(systemName: context.state.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(WidgetPalette.primary)
            }
        }
    }

    @ViewBuilder
    private func liveActivityBottomSummary(
        for context: ActivityViewContext<StudyTimerActivityAttributes>
    ) -> some View {
        switch context.attributes.displayPreset {
        case .focus:
            Text(context.state.isRunning ? "集中中" : "一時停止中")
                .font(.caption)
                .foregroundStyle(WidgetPalette.textSecondary)
        case .progress:
            Text(progressSummaryText(state: context.state))
                .font(.caption)
                .foregroundStyle(WidgetPalette.textSecondary)
        case .subjectDetail:
            Text(startedAtText(state: context.state))
                .font(.caption)
                .foregroundStyle(WidgetPalette.textSecondary)
        case .standard:
            Text(materialSummaryText(materialName: context.attributes.materialName))
                .font(.caption)
                .foregroundStyle(WidgetPalette.textSecondary)
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct StudyTimerLiveActivityView: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(context.state.isRunning ? "学習タイマー" : "学習タイマー 一時停止", systemImage: context.state.isRunning ? "timer" : "pause.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(WidgetPalette.textSecondary)
                    Text(context.attributes.displayPreset.title)
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetPalette.primary)
                }
                Spacer()
                LiveActivityStatusBadge(isRunning: context.state.isRunning)
            }

            HStack(alignment: .bottom, spacing: 12) {
                LiveActivityTimerText(state: context.state)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                trailingSummary
            }

            detailContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var trailingSummary: some View {
        switch context.attributes.displayPreset {
        case .focus:
            VStack(alignment: .trailing, spacing: 4) {
                Text("今の記録")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
                Text(context.state.isRunning ? "進行中" : "停止中")
                    .font(.subheadline.bold())
                    .foregroundStyle(WidgetPalette.primary)
            }
        case .progress:
            VStack(alignment: .trailing, spacing: 4) {
                Text("今日の記録")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
                Text(liveActivityMinutesText(context.state.todayCommittedMinutes))
                    .font(.subheadline.bold())
                    .foregroundStyle(WidgetPalette.textPrimary)
            }
        case .subjectDetail:
            VStack(alignment: .trailing, spacing: 4) {
                Text("開始")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
                Text(startedAtText(state: context.state))
                    .font(.subheadline.bold())
                    .foregroundStyle(WidgetPalette.textPrimary)
            }
        case .standard:
            VStack(alignment: .trailing, spacing: 4) {
                Text("科目")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
                Text(context.attributes.subjectName)
                    .font(.subheadline.bold())
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch context.attributes.displayPreset {
        case .focus:
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.subjectName)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                if !context.attributes.materialName.isEmpty {
                    Text(context.attributes.materialName)
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        case .progress:
            VStack(alignment: .leading, spacing: 6) {
                Text(progressSummaryText(state: context.state))
                    .font(.subheadline)
                    .foregroundStyle(WidgetPalette.textPrimary)
                if !context.attributes.materialName.isEmpty {
                    Text(context.attributes.materialName)
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        case .subjectDetail:
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.subjectName)
                    .font(.headline.bold())
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                if !context.attributes.materialName.isEmpty {
                    Text(context.attributes.materialName)
                        .font(.subheadline)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
                Text("開始 \(startedAtText(state: context.state))")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.textSecondary)
            }
        case .standard:
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.subjectName)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .lineLimit(1)
                if !context.attributes.materialName.isEmpty {
                    Text(context.attributes.materialName)
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct LiveActivityStatusBadge: View {
    let isRunning: Bool

    var body: some View {
        Text(isRunning ? "記録中" : "一時停止")
            .font(.caption2.bold())
            .foregroundStyle(isRunning ? WidgetPalette.primary : WidgetPalette.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isRunning ? WidgetPalette.primary : WidgetPalette.warning).opacity(0.14), in: Capsule())
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct LiveActivityTimerText: View {
    let state: StudyTimerActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isRunning, let timerReferenceDate = state.timerReferenceDate {
                Text(timerReferenceDate, style: .timer)
            } else {
                Text(durationString(milliseconds: state.accumulatedMilliseconds))
            }
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
private func expandedDetailText(
    for context: ActivityViewContext<StudyTimerActivityAttributes>
) -> String? {
    switch context.attributes.displayPreset {
    case .focus:
        return context.attributes.materialName.isEmpty ? "経過時間を優先表示" : context.attributes.materialName
    case .progress:
        return progressSummaryText(state: context.state)
    case .subjectDetail:
        return startedAtText(state: context.state)
    case .standard:
        return materialSummaryText(materialName: context.attributes.materialName)
    }
}

private func materialSummaryText(materialName: String) -> String {
    materialName.isEmpty ? "教材未選択" : materialName
}

private func progressSummaryText(state: StudyTimerActivityAttributes.ContentState) -> String {
    let today = liveActivityMinutesText(state.todayCommittedMinutes)
    if let dailyGoalMinutes = state.dailyGoalMinutes, dailyGoalMinutes > 0 {
        return "今日 \(today) / \(liveActivityMinutesText(dailyGoalMinutes))"
    }
    return "今日 \(today)"
}

private func startedAtText(state: StudyTimerActivityAttributes.ContentState) -> String {
    guard let startedAt = state.startedAt else {
        return "停止中"
    }
    let date = Date(timeIntervalSince1970: TimeInterval(startedAt) / 1_000)
    return date.formatted(date: .omitted, time: .shortened)
}

private func liveActivityMinutesText(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours > 0 && remainder > 0 {
        return "\(hours)時間\(remainder)分"
    }
    if hours > 0 {
        return "\(hours)時間"
    }
    return "\(remainder)分"
}

private func durationString(milliseconds: Int64) -> String {
    let totalSeconds = Int(milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}
#endif
