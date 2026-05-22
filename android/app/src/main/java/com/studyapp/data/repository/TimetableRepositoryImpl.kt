package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.TimetableEntryDao
import com.studyapp.data.local.db.dao.TimetablePeriodDao
import com.studyapp.data.local.db.dao.TimetableReviewRecordDao
import com.studyapp.data.local.db.dao.TimetableTermDao
import com.studyapp.data.local.db.entity.TimetableEntryEntity
import com.studyapp.data.local.db.entity.TimetablePeriodEntity
import com.studyapp.data.local.db.entity.TimetableReviewRecordEntity
import com.studyapp.data.local.db.entity.TimetableTermEntity
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.usecase.TimetableOverdueCalculator
import com.studyapp.domain.util.Result
import com.studyapp.sync.AppDataWriteLock
import com.studyapp.sync.SyncChangeNotifier
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TimetableRepositoryImpl @Inject constructor(
    private val periodDao: TimetablePeriodDao,
    private val termDao: TimetableTermDao,
    private val entryDao: TimetableEntryDao,
    private val reviewRecordDao: TimetableReviewRecordDao,
    private val writeLock: AppDataWriteLock,
    private val syncChangeNotifier: SyncChangeNotifier
) : TimetableRepository {

    companion object {
        private const val TAG = "TimetableRepository"
    }

    override fun getAllPeriods(): Flow<Result<List<TimetablePeriod>>> {
        return periodDao.getAllActive().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun savePeriod(period: TimetablePeriod): Result<Long> {
        return try {
            val id = writeLock.withLock {
                if (period.id == 0L) {
                    periodDao.insert(period.toEntity())
                } else {
                    periodDao.update(period.toEntity())
                    period.id
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save period", e)
            Result.Error(e, "Failed to save period")
        }
    }

    override suspend fun deletePeriod(period: TimetablePeriod): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                periodDao.update(period.copy(deletedAt = now, updatedAt = now).toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete period", e)
            Result.Error(e, "Failed to delete period")
        }
    }

    override fun getAllTerms(): Flow<Result<List<TimetableTerm>>> {
        return termDao.getAll().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun saveTerm(term: TimetableTerm): Result<Long> {
        return try {
            val id = writeLock.withLock {
                if (term.id == 0L) {
                    termDao.insert(term.toEntity())
                } else {
                    termDao.update(term.toEntity())
                    term.id
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save term", e)
            Result.Error(e, "Failed to save term")
        }
    }

    override suspend fun deleteTerm(term: TimetableTerm): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                termDao.update(term.copy(deletedAt = now, updatedAt = now).toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete term", e)
            Result.Error(e, "Failed to delete term")
        }
    }

    override fun getAllEntries(): Flow<Result<List<TimetableEntry>>> {
        return entryDao.getAll().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun saveEntry(entry: TimetableEntry): Result<Long> {
        return try {
            val id = writeLock.withLock {
                if (entry.id == 0L) {
                    entryDao.insert(entry.toEntity())
                } else {
                    entryDao.update(entry.toEntity())
                    entry.id
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save entry", e)
            Result.Error(e, "Failed to save entry")
        }
    }

    override suspend fun deleteEntry(entry: TimetableEntry): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                entryDao.update(entry.copy(deletedAt = now, updatedAt = now).toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete entry", e)
            Result.Error(e, "Failed to delete entry")
        }
    }

    override fun getAllReviewRecords(): Flow<Result<List<TimetableReviewRecord>>> {
        return reviewRecordDao.getAll().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun saveReviewRecord(record: TimetableReviewRecord): Result<Long> {
        return try {
            val id = writeLock.withLock {
                if (record.id == 0L) {
                    reviewRecordDao.insert(record.toEntity())
                } else {
                    reviewRecordDao.update(record.toEntity())
                    record.id
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save review record", e)
            Result.Error(e, "Failed to save review record")
        }
    }

    override suspend fun deleteReviewRecord(record: TimetableReviewRecord): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                reviewRecordDao.update(record.copy(deletedAt = now, updatedAt = now).toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete review record", e)
            Result.Error(e, "Failed to delete review record")
        }
    }

    override suspend fun getOverdueReviewCount(): Result<Int> {
        return try {
            val periods = periodDao.getAllActiveForSync().map { it.toDomain() }
            val terms = termDao.getAllForSync().map { it.toDomain() }
            val entries = entryDao.getAllForSync().map { it.toDomain() }
            val reviews = reviewRecordDao.getAllForSync().map { it.toDomain() }
            val count = TimetableOverdueCalculator.overdueCount(
                reference = LocalDateTime.now(),
                terms = terms,
                periods = periods,
                entries = entries,
                reviews = reviews
            )
            Result.Success(count)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get overdue review count", e)
            Result.Error(e, "Failed to get overdue review count")
        }
    }

    private fun TimetablePeriodEntity.toDomain() = TimetablePeriod(
        id = id, syncId = syncId, name = name, startMinute = startMinute,
        endMinute = endMinute, sortOrder = sortOrder, isActive = isActive,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetablePeriod.toEntity() = TimetablePeriodEntity(
        id = id, syncId = syncId, name = name, startMinute = startMinute,
        endMinute = endMinute, sortOrder = sortOrder, isActive = isActive,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableTermEntity.toDomain() = TimetableTerm(
        id = id, syncId = syncId, name = name, startDate = startDate, endDate = endDate,
        isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
        deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableTerm.toEntity() = TimetableTermEntity(
        id = id, syncId = syncId, name = name, startDate = startDate, endDate = endDate,
        isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
        deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableEntryEntity.toDomain() = TimetableEntry(
        id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
        dayOfWeek = StudyWeekday.entries[dayOfWeek],
        periodId = periodId, periodSyncId = periodSyncId, subjectName = subjectName,
        courseName = courseName, roomName = roomName, validFromDate = validFromDate, validToDate = validToDate,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableEntry.toEntity() = TimetableEntryEntity(
        id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
        dayOfWeek = dayOfWeek.ordinal,
        periodId = periodId, periodSyncId = periodSyncId, subjectName = subjectName,
        courseName = courseName, roomName = roomName, validFromDate = validFromDate, validToDate = validToDate,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableReviewRecordEntity.toDomain() = TimetableReviewRecord(
        id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
        entryId = entryId, entrySyncId = entrySyncId, periodId = periodId, periodSyncId = periodSyncId,
        occurrenceDate = occurrenceDate, dayOfWeek = StudyWeekday.entries[dayOfWeek],
        periodName = periodName, periodStartMinute = periodStartMinute, periodEndMinute = periodEndMinute,
        subjectName = subjectName, courseName = courseName, roomName = roomName,
        isReviewed = isReviewed, note = note, isExcluded = isExcluded, reviewedAt = reviewedAt,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )

    private fun TimetableReviewRecord.toEntity() = TimetableReviewRecordEntity(
        id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
        entryId = entryId, entrySyncId = entrySyncId, periodId = periodId, periodSyncId = periodSyncId,
        occurrenceDate = occurrenceDate, dayOfWeek = dayOfWeek.ordinal,
        periodName = periodName, periodStartMinute = periodStartMinute, periodEndMinute = periodEndMinute,
        subjectName = subjectName, courseName = courseName, roomName = roomName,
        isReviewed = isReviewed, note = note, isExcluded = isExcluded, reviewedAt = reviewedAt,
        createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
    )
}
