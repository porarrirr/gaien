package com.studyapp.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StackStudyWidgetSnapshotMapperTest {

    private val mapper = StackStudyWidgetSnapshotMapper()

    @Test
    fun `map respects selected order`() {
        val cards = mapper.map(
            snapshot = sampleSnapshot(),
            enabledCards = listOf(
                StudyWidgetCardType.STREAK,
                StudyWidgetCardType.TODAY,
                StudyWidgetCardType.EXAM_COUNTDOWN
            )
        )

        assertEquals(
            listOf(
                StudyWidgetCardType.STREAK,
                StudyWidgetCardType.TODAY,
                StudyWidgetCardType.EXAM_COUNTDOWN
            ),
            cards.map { it.type }
        )
    }

    @Test
    fun `map builds empty states safely`() {
        val cards = mapper.map(
            snapshot = StudyWidgetSnapshot.Empty,
            enabledCards = listOf(
                StudyWidgetCardType.WEEKLY_GOAL,
                StudyWidgetCardType.EXAM_COUNTDOWN,
                StudyWidgetCardType.WEEKLY_ACTIVITY
            )
        )

        val weeklyGoal = cards[0] as StackStudyWidgetCard.WeeklyGoal
        val exam = cards[1] as StackStudyWidgetCard.ExamCountdown
        val activity = cards[2] as StackStudyWidgetCard.WeeklyActivity

        assertTrue(weeklyGoal.emptyState)
        assertEquals("予定なし", exam.value)
        assertTrue(activity.bars.isEmpty())
    }

    private fun sampleSnapshot(): StudyWidgetSnapshot {
        return StudyWidgetSnapshot(
            generatedAt = 1L,
            todayStudyMinutes = 90L,
            todaySessionCount = 2,
            dailyGoalMinutes = 120,
            weeklyGoalMinutes = 600,
            weeklyStudyMinutes = 240L,
            streakDays = 4,
            bestStreak = 7,
            upcomingExams = listOf(
                WidgetExamSummary(name = "数学", epochDay = 0L, daysRemaining = 2L),
                WidgetExamSummary(name = "英語", epochDay = 0L, daysRemaining = 5L)
            ),
            weekActivity = listOf(
                WidgetActivitySummary("月", 10L, false),
                WidgetActivitySummary("火", 20L, false),
                WidgetActivitySummary("水", 30L, false),
                WidgetActivitySummary("木", 40L, false),
                WidgetActivitySummary("金", 50L, false),
                WidgetActivitySummary("土", 60L, false),
                WidgetActivitySummary("日", 70L, true)
            )
        )
    }
}
