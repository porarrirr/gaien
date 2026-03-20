package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Exam
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.util.Clock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class GetUpcomingExamsUseCase @Inject constructor(
    private val examRepository: ExamRepository,
    private val clock: Clock
) {
    operator fun invoke(): Flow<List<Exam>> {
        Log.d(TAG, "Getting upcoming exams")
        
        return examRepository.getUpcomingExams().map { result ->
            val exams = result.getOrNull() ?: emptyList()
            val sorted = exams.sortedBy { it.date.toEpochDay() }
            Log.i(TAG, "Found ${sorted.size} upcoming exams")
            sorted
        }
    }
    
    operator fun invoke(limit: Int): Flow<List<Exam>> {
        Log.d(TAG, "Getting upcoming exams with limit=$limit")
        
        return examRepository.getUpcomingExams().map { result ->
            val exams = result.getOrNull() ?: emptyList()
            val sorted = exams
                .sortedBy { it.date.toEpochDay() }
                .take(limit)
            Log.i(TAG, "Found ${sorted.size} upcoming exams (limit=$limit)")
            sorted
        }
    }
    
    companion object {
        private const val TAG = "GetUpcomingExamsUseCase"
    }
}