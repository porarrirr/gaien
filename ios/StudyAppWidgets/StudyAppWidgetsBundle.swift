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
    }
}
