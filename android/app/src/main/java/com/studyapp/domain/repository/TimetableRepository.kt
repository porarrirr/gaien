package com.studyapp.domain.repository

import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

interface TimetableRepository {
    fun getAllPeriods(): Flow<Result<List<TimetablePeriod>>>
    suspend fun savePeriod(period: TimetablePeriod): Result<Long>
    suspend fun deletePeriod(period: TimetablePeriod): Result<Unit>

    fun getAllTerms(): Flow<Result<List<TimetableTerm>>>
    suspend fun saveTerm(term: TimetableTerm): Result<Long>
    suspend fun deleteTerm(term: TimetableTerm): Result<Unit>

    fun getAllEntries(): Flow<Result<List<TimetableEntry>>>
    suspend fun saveEntry(entry: TimetableEntry): Result<Long>
    suspend fun deleteEntry(entry: TimetableEntry): Result<Unit>

    fun getAllReviewRecords(): Flow<Result<List<TimetableReviewRecord>>>
    suspend fun saveReviewRecord(record: TimetableReviewRecord): Result<Long>
    suspend fun deleteReviewRecord(record: TimetableReviewRecord): Result<Unit>
    suspend fun getOverdueReviewCount(): Result<Int>
}
