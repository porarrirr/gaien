package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.StudySessionDao
import com.studyapp.data.local.db.entity.StudySessionEntity
import com.studyapp.data.local.db.entity.StudySessionWithDetails
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import com.studyapp.sync.AppDataWriteLock
import com.studyapp.sync.SyncChangeNotifier
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StudySessionRepositoryImpl @Inject constructor(
    private val studySessionDao: StudySessionDao,
    private val clock: Clock,
    private val writeLock: AppDataWriteLock,
    private val syncChangeNotifier: SyncChangeNotifier
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
            syncChangeNotifier.notifyLocalDataChanged()
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
            syncChangeNotifier.notifyLocalDataChanged()
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
            syncChangeNotifier.notifyLocalDataChanged()
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
            sessionType = session.sessionType,
            startTime = session.startTime,
            endTime = session.endTime,
            intervals = session.intervalsJson.toIntervals(),
            rating = session.rating,
            note = session.note,
            problemStart = session.problemStart,
            problemEnd = session.problemEnd,
            wrongProblemCount = session.wrongProblemCount,
            problemRecords = session.problemRecordsJson.toProblemRecords(),
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
            sessionType = sessionType,
            startTime = startTime,
            endTime = endTime,
            intervals = intervalsJson.toIntervals(),
            rating = rating,
            note = note,
            problemStart = problemStart,
            problemEnd = problemEnd,
            wrongProblemCount = wrongProblemCount,
            problemRecords = problemRecordsJson.toProblemRecords(),
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun StudySession.toEntity(): StudySessionEntity {
        return StudySessionEntity(
            id = id,
            syncId = syncId,
            materialId = materialId,
            materialSyncId = materialSyncId,
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            sessionType = sessionType,
            startTime = sessionStartTime,
            endTime = sessionEndTime,
            duration = duration,
            date = date,
            intervalsJson = intervals.intervalsToJson(),
            rating = rating,
            note = note,
            problemStart = problemStart,
            problemEnd = problemEnd,
            wrongProblemCount = wrongProblemCount,
            problemRecordsJson = problemRecords.recordsToJson(),
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun String?.toIntervals(): List<StudySessionInterval> {
        if (this.isNullOrBlank()) return emptyList()
        return try {
            val jsonArray = JSONArray(this)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    add(
                        StudySessionInterval(
                            startTime = item.optLong("startTime"),
                            endTime = item.optLong("endTime")
                        )
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun List<StudySessionInterval>.intervalsToJson(): String? {
        if (isEmpty()) return null
        return JSONArray(
            map { interval ->
                JSONObject().apply {
                    put("startTime", interval.startTime)
                    put("endTime", interval.endTime)
                }
            }
        ).toString()
    }

    private fun String?.toProblemRecords(): List<ProblemSessionRecord> {
        if (this.isNullOrBlank()) return emptyList()
        return try {
            val jsonArray = JSONArray(this)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    val resultStr = item.optString("result", "CORRECT")
                    val result = try {
                        ProblemResult.valueOf(resultStr)
                    } catch (_: Exception) {
                        if (item.optBoolean("isWrong", false)) ProblemResult.WRONG else ProblemResult.CORRECT
                    }
                    add(
                        ProblemSessionRecord(
                            number = item.optInt("number"),
                            result = result,
                            detail = item.optString("detail", null)
                        )
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun List<ProblemSessionRecord>.recordsToJson(): String? {
        if (isEmpty()) return null
        return JSONArray(
            map { record ->
                JSONObject().apply {
                    put("number", record.number)
                    put("result", record.result.name)
                    put("isWrong", record.isWrong)
                    record.detail?.let { put("detail", it) }
                }
            }
        ).toString()
    }
}
