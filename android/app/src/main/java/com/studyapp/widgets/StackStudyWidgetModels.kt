package com.studyapp.widgets

import javax.inject.Inject
import javax.inject.Singleton

enum class StudyWidgetCardType(val displayName: String) {
    TODAY("今日の学習"),
    WEEKLY_GOAL("週間目標"),
    STREAK("連続学習"),
    EXAM_COUNTDOWN("試験カウントダウン"),
    WEEKLY_ACTIVITY("今週の推移");

    companion object {
        fun defaultOrder(): List<StudyWidgetCardType> {
            return listOf(
                TODAY,
                WEEKLY_GOAL,
                STREAK,
                EXAM_COUNTDOWN,
                WEEKLY_ACTIVITY
            )
        }
    }
}

sealed interface StackStudyWidgetCard {
    val type: StudyWidgetCardType

    data class Today(
        val title: String,
        val value: String,
        val progress: Float,
        val caption: String
    ) : StackStudyWidgetCard {
        override val type: StudyWidgetCardType = StudyWidgetCardType.TODAY
    }

    data class WeeklyGoal(
        val title: String,
        val value: String,
        val progress: Float,
        val caption: String,
        val emptyState: Boolean
    ) : StackStudyWidgetCard {
        override val type: StudyWidgetCardType = StudyWidgetCardType.WEEKLY_GOAL
    }

    data class Streak(
        val title: String,
        val value: String,
        val body: String,
        val caption: String
    ) : StackStudyWidgetCard {
        override val type: StudyWidgetCardType = StudyWidgetCardType.STREAK
    }

    data class ExamCountdown(
        val title: String,
        val value: String,
        val valueColor: Int,
        val body: String,
        val extraLines: List<String>
    ) : StackStudyWidgetCard {
        override val type: StudyWidgetCardType = StudyWidgetCardType.EXAM_COUNTDOWN
    }

    data class WeeklyActivity(
        val title: String,
        val total: String,
        val bars: List<ActivityBar>
    ) : StackStudyWidgetCard {
        override val type: StudyWidgetCardType = StudyWidgetCardType.WEEKLY_ACTIVITY
    }
}

data class ActivityBar(
    val dayLabel: String,
    val heightDp: Int,
    val highlightToday: Boolean
)

@Singleton
class StackStudyWidgetSnapshotMapper @Inject constructor() {
    fun map(
        snapshot: StudyWidgetSnapshot,
        enabledCards: List<StudyWidgetCardType>
    ): List<StackStudyWidgetCard> {
        val cards = enabledCards.ifEmpty { StudyWidgetCardType.defaultOrder() }
        return cards.map { type ->
            when (type) {
                StudyWidgetCardType.TODAY -> snapshot.toTodayCard()
                StudyWidgetCardType.WEEKLY_GOAL -> snapshot.toWeeklyGoalCard()
                StudyWidgetCardType.STREAK -> snapshot.toStreakCard()
                StudyWidgetCardType.EXAM_COUNTDOWN -> snapshot.toExamCountdownCard()
                StudyWidgetCardType.WEEKLY_ACTIVITY -> snapshot.toWeeklyActivityCard()
            }
        }
    }

    private fun StudyWidgetSnapshot.toTodayCard(): StackStudyWidgetCard.Today {
        val caption = if (todaySessionCount > 0) {
            "${todaySessionCount}件のセッション"
        } else {
            "タップして学習を始める"
        }
        return StackStudyWidgetCard.Today(
            title = "今日の学習",
            value = todayStudyMinutes.toDurationText(),
            progress = todayProgress,
            caption = caption
        )
    }

    private fun StudyWidgetSnapshot.toWeeklyGoalCard(): StackStudyWidgetCard.WeeklyGoal {
        val goalMinutes = weeklyGoalMinutes
        return if (goalMinutes == null || goalMinutes <= 0) {
            StackStudyWidgetCard.WeeklyGoal(
                title = "週間目標",
                value = "未設定",
                progress = 0f,
                caption = "目標を設定してください",
                emptyState = true
            )
        } else {
            StackStudyWidgetCard.WeeklyGoal(
                title = "週間目標",
                value = "${(weeklyProgress * 100f).toInt()}%",
                progress = weeklyProgress,
                caption = "${weeklyStudyMinutes.toDurationText()} / ${goalMinutes.toLong().toDurationText()}",
                emptyState = false
            )
        }
    }

    private fun StudyWidgetSnapshot.toStreakCard(): StackStudyWidgetCard.Streak {
        return StackStudyWidgetCard.Streak(
            title = "連続学習",
            value = "${streakDays}日",
            body = if (streakDays > 0) "今日も継続中" else "今日の学習でスタート",
            caption = "最長 ${bestStreak}日"
        )
    }

    private fun StudyWidgetSnapshot.toExamCountdownCard(): StackStudyWidgetCard.ExamCountdown {
        val nextExam = upcomingExams.firstOrNull()
        return if (nextExam == null) {
            StackStudyWidgetCard.ExamCountdown(
                title = "試験カウントダウン",
                value = "予定なし",
                valueColor = WIDGET_TEXT_PRIMARY_COLOR,
                body = "今後の試験はありません",
                extraLines = emptyList()
            )
        } else {
            StackStudyWidgetCard.ExamCountdown(
                title = "試験カウントダウン",
                value = examDaysText(nextExam.daysRemaining),
                valueColor = examColorInt(nextExam.daysRemaining),
                body = nextExam.name,
                extraLines = upcomingExams.drop(1).take(2).map { exam ->
                    "${exam.name} ${examDaysText(exam.daysRemaining)}"
                }
            )
        }
    }

    private fun StudyWidgetSnapshot.toWeeklyActivityCard(): StackStudyWidgetCard.WeeklyActivity {
        val maxMinutes = weekActivity.maxOfOrNull { it.minutes }?.coerceAtLeast(1L) ?: 1L
        val bars = weekActivity.map { summary ->
            val ratio = if (maxMinutes == 0L) 0f else {
                (summary.minutes.toFloat() / maxMinutes.toFloat()).coerceIn(0f, 1f)
            }
            val minHeight = 10
            val maxHeight = 54
            val height = if (summary.minutes == 0L) {
                minHeight
            } else {
                (minHeight + ((maxHeight - minHeight) * ratio)).toInt().coerceAtMost(maxHeight)
            }
            ActivityBar(
                dayLabel = summary.dayLabel,
                heightDp = height,
                highlightToday = summary.isToday
            )
        }
        return StackStudyWidgetCard.WeeklyActivity(
            title = "今週の推移",
            total = weekTotalMinutes.toDurationText(),
            bars = bars
        )
    }

    private fun examColorInt(daysRemaining: Long): Int {
        return when {
            daysRemaining <= 3L -> WIDGET_DANGER_COLOR
            daysRemaining <= 7L -> WIDGET_WARNING_COLOR
            else -> WIDGET_PRIMARY_COLOR
        }
    }

    companion object {
        private const val WIDGET_PRIMARY_COLOR = 0xFF4CAF50.toInt()
        private const val WIDGET_WARNING_COLOR = 0xFFFF9800.toInt()
        private const val WIDGET_DANGER_COLOR = 0xFFF44336.toInt()
        private const val WIDGET_TEXT_PRIMARY_COLOR = 0xDE000000.toInt()
    }
}
