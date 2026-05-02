package com.studyapp.data.local.db.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.studyapp.data.local.db.entity.TimetableReviewRecordEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetableReviewRecordDao {
    @Query("SELECT * FROM timetable_review_records WHERE deletedAt IS NULL")
    fun getAll(): Flow<List<TimetableReviewRecordEntity>>

    @Query("SELECT * FROM timetable_review_records WHERE deletedAt IS NULL")
    suspend fun getAllForSync(): List<TimetableReviewRecordEntity>

    @Query("SELECT * FROM timetable_review_records WHERE termId = :termId AND deletedAt IS NULL")
    fun getByTerm(termId: Long): Flow<List<TimetableReviewRecordEntity>>

    @Query("SELECT * FROM timetable_review_records WHERE occurrenceDate = :date AND deletedAt IS NULL")
    fun getByDate(date: Long): Flow<List<TimetableReviewRecordEntity>>

    @Query("""
        SELECT COUNT(*) FROM timetable_review_records 
        WHERE isReviewed = 0 AND isExcluded = 0 AND deletedAt IS NULL 
        AND occurrenceDate < :todayEpochDay
    """)
    suspend fun getOverdueCount(todayEpochDay: Long): Int

    @Query("SELECT * FROM timetable_review_records WHERE id = :id")
    suspend fun getById(id: Long): TimetableReviewRecordEntity?

    @Query("SELECT * FROM timetable_review_records WHERE syncId = :syncId")
    suspend fun getBySyncId(syncId: String): TimetableReviewRecordEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TimetableReviewRecordEntity): Long

    @Update
    suspend fun update(entity: TimetableReviewRecordEntity)

    @Delete
    suspend fun delete(entity: TimetableReviewRecordEntity)

    @Query("DELETE FROM timetable_review_records")
    suspend fun deleteAllForImport()
}
