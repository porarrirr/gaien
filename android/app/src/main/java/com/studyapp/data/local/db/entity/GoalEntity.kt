package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.studyapp.domain.model.GoalType

@Entity(
    tableName = "goals",
    indices = [
        Index(value = ["type", "isActive"], unique = true)
    ]
)
data class GoalEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val type: GoalType,
    val targetMinutes: Int,
    val weekStartDay: Int = 1,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)