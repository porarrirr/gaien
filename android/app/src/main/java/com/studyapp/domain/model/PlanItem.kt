package com.studyapp.domain.model

import java.time.DayOfWeek

data class PlanItem(
    val id: Long = 0,
    val planId: Long,
    val subjectId: Long,
    val dayOfWeek: DayOfWeek,
    val targetMinutes: Int,
    val actualMinutes: Int = 0,
    val timeSlot: String? = null
)