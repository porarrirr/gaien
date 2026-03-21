package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.StudySessionDao
import com.studyapp.data.local.db.entity.StudySessionEntity
import com.studyapp.data.local.db.entity.StudySessionWithDetails
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import com.studyapp.sync.AppDataWriteLock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StudySessionRepositoryImpl @Inject constructor(
    private val studySessionDao: StudySessionDao,
    private val clock: Clock,
    private val writeLock: AppDataWriteLock
) : StudySessionRepository {

    companion object {
        private const val TAG = "StudySessionRepository"
    }

    override fun getAllSessions(): Flow<Result<List<StudySession>>> {
        return studySessionDao.getAllSessionsWithDetails().map { details ->
            Result.Success(details.map { it.toDomain() })
        }
    }

    override fun getSessionsByDate(date: Long): Flow<Result<List<StudySession>>> {
        return studySessionDao.getSessionsByDateWithDetails(date).map { details ->
            Result.Success(details.map { it.toDomain() })
        }
    }

    override fun getSessionsBetweenDates(startDate: Long, endDate: Long): Flow<Result<List<StudySession>>> {
        return studySessionDao.getSessionsBetweenDates(startDate, endDate).map { entities ->
            Result.Success(entities.map { it.toDomainSimple() })
        }
    }

    override fun getSessionsBySubject(subjectId: Long): Flow<Result<List<StudySession>>> {
        return studySessionDao.getSessionsBySubject(subjectId).map { entities ->
            Result.Success(entities.map { it.toDomainSimple() })
        }
    }

    override fun getSessionsByMaterial(materialId: Long): Flow<Result<List<StudySession>>> {
        return studySessionDao.getSessionsByMaterial(materialId).map { entities ->
            Result.Success(entities.map { it.toDomainSimple() })
        }
    }

    override suspend fun getTotalDurationByDate(date: Long): Result<Long> {
        return try {
            val duration = studySessionDao.getTotalDurationByDate(date) ?: 0L
            Result.Success(duration)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get total duration by date: $date", e)
            Result.Error(e, "Failed to get total duration")
        }
    }

    override suspend fun getTotalDurationBetweenDates(startDate: Long, endDate: Long): Result<Long> {
        return try {
            val duration = studySessionDao.getTotalDurationBetweenDates(startDate, endDate) ?: 0L
            Result.Success(duration)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get total duration between dates: $startDate - $endDate", e)
            Result.Error(e, "Failed to get total duration")
        }
    }

    override suspend fun getTotalDurationBySubjectBetweenDates(
        subjectId: Long,
        startDate: Long,
        endDate: Long
    ): Result<Long> {
        return try {
            val duration = studySessionDao.getTotalDurationBySubjectBetweenDates(subjectId, startDate, endDate) ?: 0L
            Result.Success(duration)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get total duration for subject: $subjectId", e)
            Result.Error(e, "Failed to get total duration")
        }
    }

    override suspend fun getSessionById(id: Long): Result<StudySession?> {
        return try {
            val session = studySessionDao.getSessionById(id)?.toDomainSimple()
            Result.Success(session)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get session by id: $id", e)
            Result.Error(e, "Failed to get session")
        }
    }

    override suspend fun insertSession(session: StudySession): Result<Long> {
        return try {
            val id = writeLock.withLock {
                studySessionDao.insertSession(session.toEntity())
            }
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert session", e)
            Result.Error(e, "Failed to insert session")
        }
    }

    override suspend fun updateSession(session: StudySession): Result<Unit> {
        return try {
            writeLock.withLock {
                studySessionDao.updateSession(session.copy(updatedAt = System.currentTimeMillis()).toEntity())
            }
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update session: ${session.id}", e)
            Result.Error(e, "Failed to update session")
        }
    }

    override suspend fun deleteSession(session: StudySession): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                studySessionDao.updateSession(session.copy(deletedAt = now, updatedAt = now).toEntity())
            }
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete session: ${session.id}", e)
            Result.Error(e, "Failed to delete session")
        }
    }

    private fun StudySessionWithDetails.toDomain(): StudySession {
        return StudySession(
            id = session.id,
            syncId = session.syncId,
            materialId = session.materialId,
            materialSyncId = session.materialSyncId,
            materialName = material?.name ?: "",
            subjectId = session.subjectId,
            subjectSyncId = session.subjectSyncId,
            subjectName = subject?.name ?: "",
            startTime = session.startTime,
            endTime = session.endTime,
            note = session.note,
            createdAt = session.createdAt,
            updatedAt = session.updatedAt,
            deletedAt = session.deletedAt,
            lastSyncedAt = session.lastSyncedAt
        )
    }

    private fun StudySessionEntity.toDomainSimple(): StudySession {
        return StudySession(
            id = id,
            syncId = syncId,
            materialId = materialId,
            materialSyncId = materialSyncId,
            materialName = "",
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            subjectName = "",
            startTime = startTime,
            endTime = endTime,
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun StudySession.toEntity(): StudySessionEntity {
        val localDateMillis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        return StudySessionEntity(
            id = id,
            syncId = syncId,
            materialId = materialId,
            materialSyncId = materialSyncId,
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            startTime = startTime,
            endTime = endTime,
            duration = duration,
            date = localDateMillis,
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }
}
