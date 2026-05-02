package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "timetable_review_records",
    indices = [
        Index("syncId"),
        Index("termId"),
        Index("entryId"),
        Index("occurrenceDate"),
        Index("periodId")
    ]
)
data class TimetableReviewRecordEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val syncId: String = "",
    val termId: Long,
    val termSyncId: String? = null,
    val entryId: Long,
    val entrySyncId: String? = null,
    val periodId: Long,
    val periodSyncId: String? = null,
    val occurrenceDate: Long,
    val dayOfWeek: Int,
    val periodName: String,
    val periodStartMinute: Int,
    val periodEndMinute: Int,
    val subjectName: String,
    val courseName: String? = null,
    val roomName: String? = null,
    val isReviewed: Boolean = false,
    val note: String? = null,
    val isExcluded: Boolean = false,
    val reviewedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
