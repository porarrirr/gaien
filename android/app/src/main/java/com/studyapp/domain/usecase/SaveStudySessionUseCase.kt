package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import javax.inject.Inject

class SaveStudySessionUseCase @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(
        subjectId: Long,
        materialId: Long?,
        duration: Long,
        intervals: List<StudySessionInterval> = emptyList(),
        sessionType: StudySessionType = StudySessionType.MANUAL
    ): Result<Long> {
        return invoke(
            subjectId = subjectId,
            subjectSyncId = null,
            materialId = materialId,
            materialSyncId = null,
            duration = duration,
            intervals = intervals,
            sessionType = sessionType
        )
    }

    suspend operator fun invoke(
        subjectId: Long?,
        subjectSyncId: String?,
        materialId: Long?,
        materialSyncId: String?,
        duration: Long,
        intervals: List<StudySessionInterval> = emptyList(),
        sessionType: StudySessionType = StudySessionType.STOPWATCH
    ): Result<Long> {
        return try {
            Log.d(
                TAG,
                "Saving study session: subjectId=$subjectId, subjectSyncId=$subjectSyncId, materialId=$materialId, materialSyncId=$materialSyncId, duration=$duration"
            )
            
            if (duration <= 0) {
                Log.w(TAG, "Invalid duration: $duration")
                return Result.Error(IllegalArgumentException("Duration must be positive"), "学習時間は0より大きくしてください")
            }
            
            val currentTime = clock.currentTimeMillis()
            val subject = resolveSubject(subjectId, subjectSyncId)
                ?: return Result.Error(
                    NoSuchElementException("Subject not found"),
                    "科目が見つかりません"
                )
            val material = resolveMaterial(materialId, materialSyncId)
            val effectiveIntervals = intervals.ifEmpty {
                listOf(
                    StudySessionInterval(
                        startTime = currentTime - duration,
                        endTime = currentTime
                    )
                )
            }
            
            val session = StudySession(
                materialId = material?.id,
                materialSyncId = material?.syncId,
                materialName = material?.name.orEmpty(),
                subjectId = subject.id,
                subjectSyncId = subject.syncId,
                subjectName = subject.name,
                sessionType = sessionType,
                startTime = effectiveIntervals.first().startTime,
                endTime = effectiveIntervals.last().endTime,
                intervals = effectiveIntervals
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

    private suspend fun resolveSubject(subjectId: Long?, subjectSyncId: String?): Subject? {
        return subjectId?.let { subjectRepository.getSubjectById(it).getOrNull() }
            ?: subjectSyncId?.let { subjectRepository.getSubjectBySyncId(it).getOrNull() }
    }

    private suspend fun resolveMaterial(materialId: Long?, materialSyncId: String?) =
        materialId?.let { materialRepository.getMaterialById(it).getOrNull() }
            ?: materialSyncId?.let { materialRepository.getMaterialBySyncId(it).getOrNull() }
    
    companion object {
        private const val TAG = "SaveStudySessionUseCase"
    }
}
