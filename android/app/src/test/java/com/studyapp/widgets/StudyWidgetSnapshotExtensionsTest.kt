package com.studyapp.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class StudyWidgetSnapshotExtensionsTest {

    @Test
    fun weekAverageMinutes_dividesBySevenDays() {
        val snapshot = sampleSnapshot(
            weekActivity = listOf(
                WidgetActivitySummary("月", 60, false),
                WidgetActivitySummary("火", 30, false),
                WidgetActivitySummary("水", 0, false),
                WidgetActivitySummary("木", 0, false),
                WidgetActivitySummary("金", 0, false),
                WidgetActivitySummary("土", 0, false),
                WidgetActivitySummary("日", 0, true)
            )
        )

        assertEquals(13L, snapshot.weekAverageMinutes)
    }

    @Test
    fun bestActivityDayText_returnsNoneWhenNoStudy() {
        val snapshot = sampleSnapshot(
            weekActivity = listOf(
                WidgetActivitySummary("月", 0, false),
                WidgetActivitySummary("火", 0, true)
            )
        )

        assertEquals("なし", snapshot.bestActivityDayText)
        assertEquals("今週の学習はこれから", snapshot.weeklyPaceBestDayText)
    }

    @Test
    fun bestActivityDayText_returnsDayLabel() {
        val snapshot = sampleSnapshot(
            weekActivity = listOf(
                WidgetActivitySummary("月", 10, false),
                WidgetActivitySummary("火", 40, true)
            )
        )

        assertEquals("火曜", snapshot.bestActivityDayText)
        assertEquals("最多 火曜 40分", snapshot.weeklyPaceBestDayText)
    }

    @Test
    fun streakProgress_scalesAgainstBestStreak() {
        val snapshot = sampleSnapshot(streakDays = 3, bestStreak = 6)

        assertEquals(0.5f, snapshot.streakProgress)
    }

    @Test
    fun compactDurationText_formatsHoursAndMinutes() {
        assertEquals("1h30m", 90L.toCompactDurationText())
        assertEquals("45m", 45L.toCompactDurationText())
    }

    private fun sampleSnapshot(
        streakDays: Int = 0,
        bestStreak: Int = 0,
        weekActivity: List<WidgetActivitySummary> = emptyList()
    ): StudyWidgetSnapshot {
        return StudyWidgetSnapshot(
            generatedAt = 1_700_000_000_000L,
            todayStudyMinutes = 0L,
            todaySessionCount = 0,
            dailyGoalMinutes = null,
            weeklyGoalMinutes = null,
            weeklyStudyMinutes = 0L,
            streakDays = streakDays,
            bestStreak = bestStreak,
            upcomingExams = emptyList(),
            weekActivity = weekActivity
        )
    }
}
