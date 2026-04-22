package com.studyapp.domain.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

data class StudySessionInterval(
    val startTime: Long,
    val endTime: Long
) {
    val duration: Long
        get() = (endTime - startTime).coerceAtLeast(0L)
}

data class StudySession(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString(),
    val materialId: Long?,
    val materialSyncId: String? = null,
    val materialName: String = "",
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val subjectName: String = "",
    val startTime: Long,
    val endTime: Long,
    val intervals: List<StudySessionInterval> = emptyList(),
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val effectiveIntervals: List<StudySessionInterval>
        get() = if (intervals.isEmpty()) {
            listOf(StudySessionInterval(startTime = startTime, endTime = endTime))
        } else {
            intervals.sortedBy { it.startTime }
        }

    val duration: Long
        get() = if (intervals.isEmpty()) {
            endTime - startTime
        } else {
            effectiveIntervals.sumOf { it.duration }
        }

    val sessionStartTime: Long
        get() = effectiveIntervals.firstOrNull()?.startTime ?: startTime

    val sessionEndTime: Long
        get() = effectiveIntervals.lastOrNull()?.endTime ?: endTime
    
    val date: LocalDate
        get() = Instant.ofEpochMilli(sessionStartTime).atZone(ZoneId.systemDefault()).toLocalDate()
    
    val durationMinutes: Long
        get() = duration / 60000
    
    val durationHours: Float
        get() = duration / 3600000f
    
    val durationFormatted: String
        get() {
            val hours = duration / 3600000
            val minutes = (duration % 3600000) / 60000
            val seconds = (duration % 60000) / 1000
            return when {
                hours > 0 -> String.format("%d:%02d:%02d", hours, minutes, seconds)
                else -> String.format("%02d:%02d", minutes, seconds)
            }
        }
}
