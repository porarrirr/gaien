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

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: ProblemReviewRecordEntity): Long

    @Query("DELETE FROM problem_review_records")
    suspend fun deleteAllForImport()
}
