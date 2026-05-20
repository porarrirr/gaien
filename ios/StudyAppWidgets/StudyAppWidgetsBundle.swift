import SwiftUI
import WidgetKit

@main
struct StudyAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayStudyWidget()
        WeeklyGoalWidget()
        StudyStreakWidget()
        ExamCountdownWidget()
        WeeklyActivityWidget()
        DailyGoalWidget()
        StudySummaryWidget()
        UpcomingExamListWidget()
        WeeklyPaceWidget()
        #if !LIVE_ACTIVITY_DISABLED
        if #available(iOSApplicationExtension 16.1, *) {
            StudyTimerLiveActivityWidget()
        }
        #endif
    }
}
