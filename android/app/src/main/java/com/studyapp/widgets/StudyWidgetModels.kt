package com.studyapp.widgets

import java.time.DayOfWeek

data class WidgetExamSummary(
    val name: String,
    val epochDay: Long,
    val daysRemaining: Long
)

data class WidgetActivitySummary(
    val dayLabel: String,
    val minutes: Long,
    val isToday: Boolean
)

data class StudyWidgetSnapshot(
    val generatedAt: Long,
    val todayStudyMinutes: Long,
    val todaySessionCount: Int,
    val dailyGoalMinutes: Int?,
    val weeklyGoalMinutes: Int?,
    val weeklyStudyMinutes: Long,
    val streakDays: Int,
    val bestStreak: Int,
    val upcomingExams: List<WidgetExamSummary>,
    val weekActivity: List<WidgetActivitySummary>
) {
    val todayProgress: Float
        get() = percentage(todayStudyMinutes, dailyGoalMinutes)

    val weeklyProgress: Float
        get() = percentage(weeklyStudyMinutes, weeklyGoalMinutes)

    val weekTotalMinutes: Long
        get() = weekActivity.sumOf { it.minutes }

    companion object {
        val Empty = StudyWidgetSnapshot(
            generatedAt = 0L,
            todayStudyMinutes = 0L,
            todaySessionCount = 0,
            dailyGoalMinutes = null,
            weeklyGoalMinutes = null,
            weeklyStudyMinutes = 0L,
            streakDays = 0,
            bestStreak = 0,
            upcomingExams = emptyList(),
            weekActivity = emptyList()
        )

        private fun percentage(actualMinutes: Long, targetMinutes: Int?): Float {
            val safeTarget = targetMinutes?.takeIf { it > 0 } ?: return 0f
            return (actualMinutes.toFloat() / safeTarget.toFloat()).coerceIn(0f, 1f)
        }
    }
}

internal fun Long.toDurationText(): String {
    val hours = this / 60
    val minutes = this % 60
    return when {
        hours > 0 && minutes > 0 -> "${hours}時間${minutes}分"
        hours > 0 -> "${hours}時間"
        else -> "${minutes}分"
    }
}

internal fun DayOfWeek.toJapaneseShortLabel(): String {
    return when (this) {
        DayOfWeek.MONDAY -> "月"
        DayOfWeek.TUESDAY -> "火"
        DayOfWeek.WEDNESDAY -> "水"
        DayOfWeek.THURSDAY -> "木"
        DayOfWeek.FRIDAY -> "金"
        DayOfWeek.SATURDAY -> "土"
        DayOfWeek.SUNDAY -> "日"
    }
}
