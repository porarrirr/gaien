package com.studyapp.domain.model

import java.time.DayOfWeek

enum class GoalType {
    DAILY,
    WEEKLY
}

data class Goal(
    val id: Long = 0,
    val type: GoalType,
    val targetMinutes: Int,
    val weekStartDay: DayOfWeek = DayOfWeek.MONDAY,
    val isActive: Boolean = true
) {
    val targetHours: Float
        get() = targetMinutes / 60f
    
    val hoursPart: Int
        get() = targetMinutes / 60
    
    val minutesPart: Int
        get() = targetMinutes % 60
    
    val targetFormatted: String
        get() = when {
            hoursPart > 0 && minutesPart > 0 -> "${hoursPart}時間${minutesPart}分"
            hoursPart > 0 -> "${hoursPart}時間"
            else -> "${minutesPart}分"
        }
}