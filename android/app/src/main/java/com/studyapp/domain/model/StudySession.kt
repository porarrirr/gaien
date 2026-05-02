package com.studyapp.domain.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

enum class StudySessionType {
    STOPWATCH,
    TIMER,
    MANUAL;

    val title: String
        get() = when (this) {
            STOPWATCH -> "ストップウォッチ"
            TIMER -> "タイマー"
            MANUAL -> "手動"
        }
}

@Serializable
data class StudySessionInterval(
    val startTime: Long,
    val endTime: Long
) {
    val duration: Long
        get() = (endTime - startTime).coerceAtLeast(0L)
}

data class StudySession(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val materialId: Long? = null,
    val materialSyncId: String? = null,
    val materialName: String = "",
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val subjectName: String = "",
    val sessionType: StudySessionType = StudySessionType.STOPWATCH,
    val startTime: Long,
    val endTime: Long,
    val intervals: List<StudySessionInterval> = emptyList(),
    val rating: Int? = null,
    val note: String? = null,
    val problemStart: Int? = null,
    val problemEnd: Int? = null,
    val wrongProblemCount: Int? = null,
    val problemRecords: List<ProblemSessionRecord> = emptyList(),
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
            maxOf(endTime - startTime, 0)
        } else {
            effectiveIntervals.sumOf { it.duration }
        }

    val sessionStartTime: Long
        get() = effectiveIntervals.firstOrNull()?.startTime ?: startTime

    val sessionEndTime: Long
        get() = effectiveIntervals.lastOrNull()?.endTime ?: endTime

    val date: Long
        get() {
            val localDate = Instant.ofEpochMilli(sessionStartTime)
                .atZone(ZoneId.systemDefault()).toLocalDate()
            return localDate.toEpochDay()
        }

    val durationMinutes: Int
        get() = (duration / 60000).toInt()

    val durationHours: Double
        get() = duration.toDouble() / 3_600_000.0

    val durationFormatted: String
        get() {
            val totalSeconds = (duration / 1000).toInt()
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            return if (hours > 0) {
                String.format("%d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format("%02d:%02d", minutes, seconds)
            }
        }

    val durationJapaneseText: String
        get() = Goal.formatMinutes(durationMinutes)

    val hasRating: Boolean
        get() = rating != null

    val problemRangeText: String?
        get() {
            if (problemRecords.isNotEmpty()) {
                val numbers = problemRecords.map { it.number }.sorted()
                val first = numbers.firstOrNull() ?: return null
                val last = numbers.lastOrNull() ?: return null
                return if (first == last) "${first}問" else "$first-${last}問"
            }
            val start = problemStart ?: return null
            val end = problemEnd ?: return null
            return if (start == end) "${start}問" else "$start-${end}問"
        }

    val effectiveWrongProblemCount: Int?
        get() {
            if (problemRecords.isNotEmpty()) {
                return problemRecords.count { it.result == ProblemResult.WRONG }
            }
            return wrongProblemCount
        }

    val effectiveReviewCorrectProblemCount: Int
        get() = problemRecords.count { it.result == ProblemResult.REVIEW_CORRECT }

    val startDate: LocalDate
        get() = Instant.ofEpochMilli(sessionStartTime).atZone(ZoneId.systemDefault()).toLocalDate()

    val dayOfWeek: StudyWeekday
        get() {
            val weekday = startDate.dayOfWeek
            return StudyWeekday.fromDayOfWeek(weekday)
        }

    companion object {
        val allowedRatings = 1..5
    }
}
