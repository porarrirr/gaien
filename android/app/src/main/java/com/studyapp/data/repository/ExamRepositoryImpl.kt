package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.ExamDao
import com.studyapp.data.local.db.entity.ExamEntity
import com.studyapp.domain.model.Exam
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ExamRepositoryImpl @Inject constructor(
    private val examDao: ExamDao,
    private val clock: Clock
) : ExamRepository {

    companion object {
        private const val TAG = "ExamRepository"
    }

    override fun getAllExams(): Flow<Result<List<Exam>>> {
        return examDao.getAllExams().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override fun getUpcomingExams(): Flow<Result<List<Exam>>> {
        val currentTime = clock.currentTimeMillis()
        return examDao.getUpcomingExams(currentTime).map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun getExamById(id: Long): Result<Exam?> {
        return try {
            val exam = examDao.getExamById(id)?.toDomain()
            Result.Success(exam)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get exam by id: $id", e)
            Result.Error(e, "Failed to get exam")
        }
    }

    override suspend fun insertExam(exam: Exam): Result<Long> {
        return try {
            val id = examDao.insertExam(exam.toEntity())
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert exam: ${exam.name}", e)
            Result.Error(e, "Failed to insert exam")
        }
    }

    override suspend fun updateExam(exam: Exam): Result<Unit> {
        return try {
            examDao.updateExam(exam.copy(updatedAt = clock.currentTimeMillis()).toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update exam: ${exam.id}", e)
            Result.Error(e, "Failed to update exam")
        }
    }

    override suspend fun deleteExam(exam: Exam): Result<Unit> {
        return try {
            val now = clock.currentTimeMillis()
            examDao.updateExam(exam.copy(deletedAt = now, updatedAt = now).toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete exam: ${exam.id}", e)
            Result.Error(e, "Failed to delete exam")
        }
    }

    private fun ExamEntity.toDomain(): Exam {
        return Exam(
            id = id,
            syncId = syncId,
            name = name,
            date = Instant.ofEpochMilli(date).atZone(ZoneId.systemDefault()).toLocalDate(),
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun Exam.toEntity(): ExamEntity {
        return ExamEntity(
            id = id,
            syncId = syncId,
            name = name,
            date = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }
}
