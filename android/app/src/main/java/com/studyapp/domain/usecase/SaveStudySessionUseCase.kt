package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import javax.inject.Inject

class SaveStudySessionUseCase @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(
        subjectId: Long,
        materialId: Long?,
        duration: Long
    ): Result<Long> {
        return try {
            Log.d(TAG, "Saving study session: subjectId=$subjectId, materialId=$materialId, duration=$duration")
            
            if (duration <= 0) {
                Log.w(TAG, "Invalid duration: $duration")
                return Result.Error(IllegalArgumentException("Duration must be positive"), "学習時間は0より大きくしてください")
            }
            
            val currentTime = clock.currentTimeMillis()
            
            val session = StudySession(
                materialId = materialId,
                materialName = "",
                subjectId = subjectId,
                subjectName = "",
                startTime = currentTime - duration,
                endTime = currentTime
            )
            
            val result = studySessionRepository.insertSession(session)
            
            result.onSuccess { id ->
                Log.i(TAG, "Study session saved successfully with id=$id")
            }
            
            result.map { it }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save study session", e)
            Result.Error(e, "学習記録の保存に失敗しました")
        }
    }
    
    companion object {
        private const val TAG = "SaveStudySessionUseCase"
    }
}