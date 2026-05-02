package com.studyapp.data.local.db.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.studyapp.data.local.db.entity.TimetableTermEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetableTermDao {
    @Query("SELECT * FROM timetable_terms WHERE deletedAt IS NULL ORDER BY endDate DESC")
    fun getAll(): Flow<List<TimetableTermEntity>>

    @Query("SELECT * FROM timetable_terms WHERE deletedAt IS NULL ORDER BY endDate DESC")
    suspend fun getAllForSync(): List<TimetableTermEntity>

    @Query("SELECT * FROM timetable_terms WHERE id = :id")
    suspend fun getById(id: Long): TimetableTermEntity?

    @Query("SELECT * FROM timetable_terms WHERE syncId = :syncId")
    suspend fun getBySyncId(syncId: String): TimetableTermEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TimetableTermEntity): Long

    @Update
    suspend fun update(entity: TimetableTermEntity)

    @Delete
    suspend fun delete(entity: TimetableTermEntity)

    @Query("DELETE FROM timetable_terms")
    suspend fun deleteAllForImport()
}
