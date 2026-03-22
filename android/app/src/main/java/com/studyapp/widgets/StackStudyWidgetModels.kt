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

    data class TextCard(
        override val type: StudyWidgetCardType,
        val title: String,
        val value: String,
        val body: String?,
        val caption: String?,
        val extraLines: List<String> = emptyList(),
        val progress: Float? = null,
        val valueStyle: ValueStyle = ValueStyle.HERO,
        val valueColor: Int,
        val bodyMaxLines: Int = 1
    ) : StackStudyWidgetCard

    data class WeeklyActivity(
        override val type: StudyWidgetCardType = StudyWidgetCardType.WEEKLY_ACTIVITY,
        val title: String,
        val total: String,
        val lines: List<String>,
        val caption: String?
    ) : StackStudyWidgetCard

    enum class ValueStyle {
        HERO,
        COMPACT
    }
}

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

    private fun StudyWidgetSnapshot.toTodayCard(): StackStudyWidgetCard.TextCard {
        val caption = if (todaySessionCount > 0) {
            "${todaySessionCount}件のセッション"
        } else {
            "タップして学習を始める"
        }
        return StackStudyWidgetCard.TextCard(
            type = StudyWidgetCardType.TODAY,
            title = "今日の学習",
            value = todayStudyMinutes.toDurationText(),
            body = null,
            caption = caption,
            progress = todayProgress,
            valueStyle = StackStudyWidgetCard.ValueStyle.HERO,
            valueColor = WIDGET_TEXT_PRIMARY_COLOR
        )
    }

    private fun StudyWidgetSnapshot.toWeeklyGoalCard(): StackStudyWidgetCard.TextCard {
        val goalMinutes = weeklyGoalMinutes
        return if (goalMinutes == null || goalMinutes <= 0) {
            StackStudyWidgetCard.TextCard(
                type = StudyWidgetCardType.WEEKLY_GOAL,
                title = "週間目標",
                value = "未設定",
                body = "目標を設定してください",
                caption = "設定画面から追加できます",
                progress = null,
                valueStyle = StackStudyWidgetCard.ValueStyle.COMPACT,
                valueColor = WIDGET_TEXT_PRIMARY_COLOR,
                bodyMaxLines = 2
            )
        } else {
            StackStudyWidgetCard.TextCard(
                type = StudyWidgetCardType.WEEKLY_GOAL,
                title = "週間目標",
                value = "${(weeklyProgress * 100f).toInt()}%",
                body = "${weeklyStudyMinutes.toDurationText()} 学習済み",
                caption = "${weeklyStudyMinutes.toDurationText()} / ${goalMinutes.toLong().toDurationText()}",
                progress = weeklyProgress,
                valueStyle = StackStudyWidgetCard.ValueStyle.HERO,
                valueColor = WIDGET_TEXT_PRIMARY_COLOR
            )
        }
    }

    private fun StudyWidgetSnapshot.toStreakCard(): StackStudyWidgetCard.TextCard {
        return StackStudyWidgetCard.TextCard(
            type = StudyWidgetCardType.STREAK,
            title = "連続学習",
            value = "${streakDays}日",
            body = if (streakDays > 0) "今日も継続中" else "今日の学習でスタート",
            caption = "最長 ${bestStreak}日",
            valueStyle = StackStudyWidgetCard.ValueStyle.HERO,
            valueColor = WIDGET_TEXT_PRIMARY_COLOR
        )
    }

    private fun StudyWidgetSnapshot.toExamCountdownCard(): StackStudyWidgetCard.TextCard {
        val nextExam = upcomingExams.firstOrNull()
        return if (nextExam == null) {
            StackStudyWidgetCard.TextCard(
                type = StudyWidgetCardType.EXAM_COUNTDOWN,
                title = "試験カウントダウン",
                value = "予定なし",
                body = "今後の試験はありません",
                caption = "ウィジェットに表示できる試験がありません",
                progress = null,
                valueStyle = StackStudyWidgetCard.ValueStyle.COMPACT,
                valueColor = WIDGET_TEXT_PRIMARY_COLOR,
                bodyMaxLines = 2
            )
        } else {
            StackStudyWidgetCard.TextCard(
                type = StudyWidgetCardType.EXAM_COUNTDOWN,
                title = "試験カウントダウン",
                value = examDaysText(nextExam.daysRemaining),
                body = nextExam.name,
                caption = if (upcomingExams.size > 1) "次の予定も表示中" else null,
                extraLines = upcomingExams.drop(1).take(2).map { exam ->
                    "${exam.name} ${examDaysText(exam.daysRemaining)}"
                },
                progress = null,
                valueStyle = StackStudyWidgetCard.ValueStyle.HERO,
                valueColor = examColorInt(nextExam.daysRemaining),
                bodyMaxLines = 1
            )
        }
    }

    private fun StudyWidgetSnapshot.toWeeklyActivityCard(): StackStudyWidgetCard.WeeklyActivity {
        val lines = weekActivity.map { summary ->
            val prefix = if (summary.isToday) "今日" else summary.dayLabel
            "$prefix ${summary.minutes.toDurationText()}"
        }
        return StackStudyWidgetCard.WeeklyActivity(
            title = "今週の推移",
            total = weekTotalMinutes.toDurationText(),
            lines = lines.ifEmpty { listOf("学習記録はまだありません") },
            caption = if (weekActivity.any { it.minutes > 0L }) {
                "直近7日間の記録"
            } else {
                "記録が増えるとここに表示されます"
            }
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
