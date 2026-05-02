package com.studyapp.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class TimerSnapshot(
    val subjectId: Long,
    val materialId: Long? = null,
    val startedAt: Long? = null,
    val accumulatedMilliseconds: Long = 0,
    val completedIntervals: List<StudySessionInterval> = emptyList(),
    val mode: Mode = Mode.STOPWATCH,
    val targetDurationMilliseconds: Long? = null,
    val problemRecords: List<ProblemSessionRecord> = emptyList(),
    val problemCountDraft: String = "",
    val isRunning: Boolean
) {
    @Serializable
    enum class Mode {
        STOPWATCH,
        TIMER
    }

    fun elapsedTime(nowMillis: Long = System.currentTimeMillis()): Long {
        return if (isRunning && startedAt != null) {
            accumulatedMilliseconds + maxOf(nowMillis - startedAt, 0)
        } else {
            accumulatedMilliseconds
        }
    }

    fun finalizedIntervals(nowMillis: Long = System.currentTimeMillis()): List<StudySessionInterval> {
        return if (isRunning && startedAt != null) {
            completedIntervals + StudySessionInterval(startTime = startedAt, endTime = nowMillis)
        } else {
            completedIntervals
        }
    }

    fun remainingTime(nowMillis: Long = System.currentTimeMillis()): Long {
        if (mode != Mode.TIMER) return 0
        return maxOf((targetDurationMilliseconds ?: 0) - elapsedTime(nowMillis), 0)
    }

    val sessionType: StudySessionType
        get() = when (mode) {
            Mode.STOPWATCH -> StudySessionType.STOPWATCH
            Mode.TIMER -> StudySessionType.TIMER
        }
}
