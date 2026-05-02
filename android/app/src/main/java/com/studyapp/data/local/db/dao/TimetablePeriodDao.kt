package com.studyapp.data.local.db.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.studyapp.data.local.db.entity.TimetablePeriodEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetablePeriodDao {
    @Query("SELECT * FROM timetable_periods WHERE deletedAt IS NULL ORDER BY sortOrder ASC")
    fun getAllActive(): Flow<List<TimetablePeriodEntity>>

    @Query("SELECT * FROM timetable_periods WHERE deletedAt IS NULL ORDER BY sortOrder ASC")
    suspend fun getAllActiveForSync(): List<TimetablePeriodEntity>

    @Query("SELECT * FROM timetable_periods WHERE id = :id")
    suspend fun getById(id: Long): TimetablePeriodEntity?

    @Query("SELECT * FROM timetable_periods WHERE syncId = :syncId")
    suspend fun getBySyncId(syncId: String): TimetablePeriodEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TimetablePeriodEntity): Long

    @Update
    suspend fun update(entity: TimetablePeriodEntity)

    @Delete
    suspend fun delete(entity: TimetablePeriodEntity)

    @Query("DELETE FROM timetable_periods")
    suspend fun deleteAllForImport()
}
