package com.studyapp.data.local.db.dao

import androidx.room.*
import com.studyapp.data.local.db.entity.StudySessionEntity
import com.studyapp.data.local.db.entity.StudySessionWithDetails
import com.studyapp.data.local.db.entity.StudySessionWithNames
import kotlinx.coroutines.flow.Flow

@Dao
interface StudySessionDao {
    @Transaction
    @Query("SELECT * FROM study_sessions ORDER BY startTime DESC")
    fun getAllSessionsWithDetails(): Flow<List<StudySessionWithDetails>>

    @Query("""
        SELECT s.*, sub.name as subjectName, m.name as materialName
        FROM study_sessions s
        INNER JOIN subjects sub ON s.subjectId = sub.id
        LEFT JOIN materials m ON s.materialId = m.id
        ORDER BY s.startTime DESC
    """)
    fun getAllSessionsWithNames(): Flow<List<StudySessionWithNames>>

    @Query("SELECT * FROM study_sessions ORDER BY startTime DESC")
    fun getAllSessions(): Flow<List<StudySessionEntity>>

    @Transaction
    @Query("SELECT * FROM study_sessions WHERE date = :date ORDER BY startTime DESC")
    fun getSessionsByDateWithDetails(date: Long): Flow<List<StudySessionWithDetails>>

    @Query("SELECT * FROM study_sessions WHERE date = :date ORDER BY startTime DESC")
    fun getSessionsByDate(date: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE date >= :startDate AND date < :endDate ORDER BY startTime DESC")
    fun getSessionsBetweenDates(startDate: Long, endDate: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE subjectId = :subjectId ORDER BY startTime DESC")
    fun getSessionsBySubject(subjectId: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT * FROM study_sessions WHERE materialId = :materialId ORDER BY startTime DESC")
    fun getSessionsByMaterial(materialId: Long): Flow<List<StudySessionEntity>>

    @Query("SELECT SUM(duration) FROM study_sessions WHERE date = :date")
    suspend fun getTotalDurationByDate(date: Long): Long?

    @Query("SELECT SUM(duration) FROM study_sessions WHERE date >= :startDate AND date < :endDate")
    suspend fun getTotalDurationBetweenDates(startDate: Long, endDate: Long): Long?

    @Query("SELECT SUM(duration) FROM study_sessions WHERE subjectId = :subjectId AND date >= :startDate AND date < :endDate")
    suspend fun getTotalDurationBySubjectBetweenDates(subjectId: Long, startDate: Long, endDate: Long): Long?

    @Query("SELECT * FROM study_sessions WHERE id = :id")
    suspend fun getSessionById(id: Long): StudySessionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: StudySessionEntity): Long

    @Update
    suspend fun updateSession(session: StudySessionEntity)

    @Delete
    suspend fun deleteSession(session: StudySessionEntity)

    @Query("DELETE FROM study_sessions WHERE id = :id")
    suspend fun deleteSessionById(id: Long)
}
