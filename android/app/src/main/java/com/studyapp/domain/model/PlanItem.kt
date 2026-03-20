package com.studyapp.domain.model

import java.time.DayOfWeek
import java.util.UUID

data class PlanItem(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString(),
    val planId: Long,
    val planSyncId: String? = null,
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val dayOfWeek: DayOfWeek,
    val targetMinutes: Int,
    val actualMinutes: Int = 0,
    val timeSlot: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
