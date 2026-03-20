package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "study_plans",
    indices = [Index("isActive"), Index("createdAt")]
)
data class PlanEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val startDate: Long,
    val endDate: Long,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "plan_items",
    foreignKeys = [
        ForeignKey(
            entity = PlanEntity::class,
            parentColumns = ["id"],
            childColumns = ["planId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = SubjectEntity::class,
            parentColumns = ["id"],
            childColumns = ["subjectId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("planId"), Index("subjectId"), Index(value = ["planId", "dayOfWeek"])]
)
data class PlanItemEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val planId: Long,
    val subjectId: Long,
    val dayOfWeek: Int,
    val targetMinutes: Int,
    val actualMinutes: Int = 0,
    val timeSlot: String? = null
)

data class WeeklyPlanSummary(
    val dayOfWeek: Int,
    val totalTargetMinutes: Int,
    val totalActualMinutes: Int
)