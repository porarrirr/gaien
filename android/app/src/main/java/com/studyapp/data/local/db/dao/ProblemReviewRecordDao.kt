package com.studyapp.data.local.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.studyapp.data.local.db.entity.ProblemReviewRecordEntity

@Dao
interface ProblemReviewRecordDao {
    @Query("SELECT * FROM problem_review_records")
    suspend fun getAllForSync(): List<ProblemReviewRecordEntity>

    @Query("UPDATE problem_review_records SET deletedAt = :deletedAt, updatedAt = :updatedAt WHERE materialId = :materialId AND deletedAt IS NULL")
    suspend fun softDeleteActiveByMaterial(materialId: Long, deletedAt: Long, updatedAt: Long)

    @Query("UPDATE problem_review_records SET deletedAt = :deletedAt, updatedAt = :updatedAt WHERE materialId IN (SELECT id FROM materials WHERE subjectId = :subjectId) AND deletedAt IS NULL")
    suspend fun softDeleteActiveBySubject(subjectId: Long, deletedAt: Long, updatedAt: Long)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: ProblemReviewRecordEntity): Long

    @Query("DELETE FROM problem_review_records")
    suspend fun deleteAllForImport()
}
