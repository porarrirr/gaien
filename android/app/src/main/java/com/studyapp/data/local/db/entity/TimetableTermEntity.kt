package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "timetable_terms",
    indices = [Index("syncId"), Index("isActive")]
)
data class TimetableTermEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val syncId: String = "",
    val name: String,
    val startDate: Long,
    val endDate: Long,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
