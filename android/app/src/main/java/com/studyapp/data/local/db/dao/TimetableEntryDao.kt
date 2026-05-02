package com.studyapp.data.local.db.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.studyapp.data.local.db.entity.TimetableEntryEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetableEntryDao {
    @Query("SELECT * FROM timetable_entries WHERE deletedAt IS NULL")
    fun getAll(): Flow<List<TimetableEntryEntity>>

    @Query("SELECT * FROM timetable_entries WHERE deletedAt IS NULL")
    suspend fun getAllForSync(): List<TimetableEntryEntity>

    @Query("SELECT * FROM timetable_entries WHERE termId = :termId AND deletedAt IS NULL")
    fun getByTerm(termId: Long): Flow<List<TimetableEntryEntity>>

    @Query("SELECT * FROM timetable_entries WHERE id = :id")
    suspend fun getById(id: Long): TimetableEntryEntity?

    @Query("SELECT * FROM timetable_entries WHERE syncId = :syncId")
    suspend fun getBySyncId(syncId: String): TimetableEntryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TimetableEntryEntity): Long

    @Update
    suspend fun update(entity: TimetableEntryEntity)

    @Delete
    suspend fun delete(entity: TimetableEntryEntity)

    @Query("DELETE FROM timetable_entries")
    suspend fun deleteAllForImport()
}
