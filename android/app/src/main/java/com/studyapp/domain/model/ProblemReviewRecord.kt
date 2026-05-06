package com.studyapp.domain.model

import java.util.UUID

enum class ProblemReviewRating {
    AGAIN,
    GOOD;

    val wireName: String
        get() = when (this) {
            AGAIN -> "again"
            GOOD -> "good"
        }

    companion object {
        fun fromWireName(value: String): ProblemReviewRating {
            return entries.firstOrNull { it.wireName == value || it.name == value.uppercase() } ?: AGAIN
        }
    }
}

data class ProblemReviewRecord(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val problemId: String,
    val materialId: Long,
    val materialSyncId: String? = null,
    val problemNumber: Int,
    val reviewedAt: Long,
    val rating: ProblemReviewRating,
    val nextReviewDate: Long,
    val consecutiveCorrectCount: Int,
    val wrongCount: Int,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    companion object {
        fun problemId(materialId: Long, problemNumber: Int): String {
            return "$materialId-$problemNumber"
        }
    }
}

data class TodayReviewProblem(
    val materialId: Long,
    val materialName: String,
    val subjectName: String,
    val problemNumber: Int,
    val nextReviewDate: Long,
    val consecutiveCorrectCount: Int,
    val wrongCount: Int
) {
    val id: String
        get() = ProblemReviewRecord.problemId(materialId, problemNumber)
}
