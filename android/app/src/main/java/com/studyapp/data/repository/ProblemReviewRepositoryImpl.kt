package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.ProblemReviewRecordDao
import com.studyapp.data.local.db.entity.ProblemReviewRecordEntity
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.repository.ProblemReviewRepository
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ProblemReviewRepositoryImpl @Inject constructor(
    private val problemReviewRecordDao: ProblemReviewRecordDao
) : ProblemReviewRepository {
    override fun getActiveReviewRecords(): Flow<Result<List<ProblemReviewRecord>>> {
        return problemReviewRecordDao.observeActiveRecords()
            .map { records: List<ProblemReviewRecordEntity> ->
                Result.Success(records.map { it.toDomain() })
                    as Result<List<ProblemReviewRecord>>
            }
            .catch { e ->
                Log.e(TAG, "Failed to observe problem review records", e)
                emit(Result.Error(e as? Exception ?: RuntimeException(e), "Failed to get review records"))
            }
    }

    private fun ProblemReviewRecordEntity.toDomain(): ProblemReviewRecord {
        return ProblemReviewRecord(
            id = id,
            syncId = syncId,
            problemId = problemId,
            materialId = materialId,
            materialSyncId = materialSyncId,
            problemNumber = problemNumber,
            reviewedAt = reviewedAt,
            rating = ProblemReviewRating.fromWireName(rating),
            nextReviewDate = nextReviewDate,
            consecutiveCorrectCount = consecutiveCorrectCount,
            wrongCount = wrongCount,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    companion object {
        private const val TAG = "ProblemReviewRepository"
    }
}
