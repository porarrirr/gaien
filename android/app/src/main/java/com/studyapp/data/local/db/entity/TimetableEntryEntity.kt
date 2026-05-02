package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "timetable_entries",
    foreignKeys = [
        ForeignKey(
            entity = TimetablePeriodEntity::class,
            parentColumns = ["id"],
            childColumns = ["periodId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("syncId"), Index("periodId"), Index("termId"), Index("dayOfWeek")]
)
data class TimetableEntryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val syncId: String = "",
    val termId: Long? = null,
    val termSyncId: String? = null,
    val dayOfWeek: Int,
    val periodId: Long,
    val periodSyncId: String? = null,
    val subjectName: String,
    val courseName: String? = null,
    val roomName: String? = null,
    val validFromDate: Long? = null,
    val validToDate: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
