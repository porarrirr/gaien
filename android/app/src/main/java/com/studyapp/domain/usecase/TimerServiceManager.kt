package com.studyapp.domain.usecase

import kotlinx.coroutines.flow.Flow
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType

data class TimerStopResult(
    val elapsed: Long,
    val materialId: Long?,
    val intervals: List<StudySessionInterval>,
    val sessionType: StudySessionType
)

enum class TimerMode {
    STOPWATCH,
    TIMER
}

interface TimerServiceManager {
    fun bind()
    fun unbind()
    fun startTimer(
        subjectId: Long,
        subjectSyncId: String?,
        materialId: Long?,
        materialSyncId: String?,
        mode: TimerMode,
        targetDurationMillis: Long?
    )
    fun pauseTimer()
    fun stopTimer(): TimerStopResult
    val elapsedTime: Flow<Long>
    val remainingTime: Flow<Long>
    val isRunning: Flow<Boolean>
    val isBound: Flow<Boolean>
    val currentSubjectId: Flow<Long?>
    val currentSubjectSyncId: Flow<String?>
    val currentMaterialId: Flow<Long?>
    val currentMaterialSyncId: Flow<String?>
    val currentMode: Flow<TimerMode>
    val currentTargetDurationMillis: Flow<Long?>
}
