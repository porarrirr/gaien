package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.SubjectDao
import com.studyapp.data.local.db.entity.SubjectEntity
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.SubjectIcon
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SubjectRepositoryImpl @Inject constructor(
    private val subjectDao: SubjectDao
) : SubjectRepository {

    companion object {
        private const val TAG = "SubjectRepository"
    }

    override fun getAllSubjects(): Flow<Result<List<Subject>>> {
        return subjectDao.getAllSubjects().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun getSubjectById(id: Long): Result<Subject?> {
        return try {
            val subject = subjectDao.getSubjectById(id)?.toDomain()
            Result.Success(subject)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get subject by id: $id", e)
            Result.Error(e, "Failed to get subject")
        }
    }

    override suspend fun insertSubject(subject: Subject): Result<Long> {
        return try {
            val id = subjectDao.insertSubject(subject.toEntity())
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert subject: ${subject.name}", e)
            Result.Error(e, "Failed to insert subject")
        }
    }

    override suspend fun updateSubject(subject: Subject): Result<Unit> {
        return try {
            subjectDao.updateSubject(subject.toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update subject: ${subject.id}", e)
            Result.Error(e, "Failed to update subject")
        }
    }

    override suspend fun deleteSubject(subject: Subject): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            subjectDao.updateSubject(subject.copy(deletedAt = now, updatedAt = now).toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete subject: ${subject.id}", e)
            Result.Error(e, "Failed to delete subject")
        }
    }

    private fun SubjectEntity.toDomain(): Subject {
        return Subject(
            id = id,
            syncId = syncId,
            name = name,
            color = color,
            icon = icon?.let { SubjectIcon.fromName(it) },
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun Subject.toEntity(): SubjectEntity {
        return SubjectEntity(
            id = id,
            syncId = syncId,
            name = name,
            color = color,
            icon = icon?.name,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }
}
