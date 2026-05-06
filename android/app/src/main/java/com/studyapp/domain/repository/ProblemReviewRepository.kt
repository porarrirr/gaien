package com.studyapp.domain.repository

import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

interface ProblemReviewRepository {
    fun getActiveReviewRecords(): Flow<Result<List<ProblemReviewRecord>>>
}
