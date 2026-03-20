package com.studyapp.domain.model

import java.util.UUID

data class StudyPlan(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString(),
    val name: String,
    val startDate: Long,
    val endDate: Long,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
