package com.studyapp.domain.model

import java.util.UUID

enum class GoalType {
    DAILY,
    WEEKLY;

    val title: String
        get() = when (this) {
            DAILY -> "1日の目標"
            WEEKLY -> "週間目標"
        }
}

data class Goal(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val type: GoalType,
    val targetMinutes: Int,
    val dayOfWeek: StudyWeekday? = null,
    val weekStartDay: StudyWeekday = StudyWeekday.MONDAY,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val targetFormatted: String
        get() = formatMinutes(targetMinutes)

    companion object {
        fun formatMinutes(minutes: Int): String {
            val hours = minutes / 60
            val remainder = minutes % 60
            return when {
                hours > 0 && remainder > 0 -> "${hours}時間${remainder}分"
                hours > 0 -> "${hours}時間"
                else -> "${remainder}分"
            }
        }
    }
}

fun List<Goal>.latestActiveDailyGoal(forDayOfWeek: StudyWeekday): Goal? =
    filter { it.type == GoalType.DAILY && it.isActive && it.deletedAt == null && it.dayOfWeek == forDayOfWeek }
        .maxByOrNull { it.updatedAt * 1000 + it.createdAt }

fun List<Goal>.latestActiveWeeklyGoal(): Goal? =
    filter { it.type == GoalType.WEEKLY && it.isActive && it.deletedAt == null }
        .maxByOrNull { it.updatedAt * 1000 + it.createdAt }

fun List<Goal>.latestActiveDailyGoalsByWeekday(): Map<StudyWeekday, Goal> =
    fold(mutableMapOf<StudyWeekday, Goal>()) { result, goal ->
        if (goal.type == GoalType.DAILY && goal.isActive && goal.deletedAt == null) {
            val dayOfWeek = goal.dayOfWeek ?: return@fold result
            val current = result[dayOfWeek]
            if (current == null || goal.updatedAt > current.updatedAt ||
                (goal.updatedAt == current.updatedAt && goal.createdAt > current.createdAt)
            ) {
                result[dayOfWeek] = goal
            }
        }
        result
    }
