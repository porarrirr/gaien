package com.studyapp.domain.model

data class StudyPlan(
    val id: Long = 0,
    val name: String,
    val startDate: Long,
    val endDate: Long,
    val isActive: Boolean = true,
    val createdAt: Long
)