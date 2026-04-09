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
        #if !LIVE_ACTIVITY_DISABLED
        if #available(iOSApplicationExtension 18.0, *) {
            StudyTimerLiveActivityWidget()
        }
        #endif
    }
}
