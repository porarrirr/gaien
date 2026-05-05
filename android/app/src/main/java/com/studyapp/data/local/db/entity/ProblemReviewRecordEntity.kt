package com.studyapp.data.local.db.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "problem_review_records",
    indices = [
        Index("syncId"),
        Index("problemId"),
        Index("materialId"),
        Index("nextReviewDate")
    ]
)
data class ProblemReviewRecordEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val syncId: String,
    val problemId: String,
    val materialId: Long,
    val materialSyncId: String? = null,
    val problemNumber: Int,
    val reviewedAt: Long,
    val rating: String,
    val nextReviewDate: Long,
    val consecutiveCorrectCount: Int = 0,
    val wrongCount: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
