package com.studyapp.domain.model

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.UUID

data class TimetablePeriod(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val name: String,
    val startMinute: Int,
    val endMinute: Int,
    val sortOrder: Int,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val timeRangeText: String
        get() = "${timeText(startMinute)}-${timeText(endMinute)}"

    companion object {
        fun timeText(minute: Int): String =
            String.format("%02d:%02d", minute / 60, minute % 60)

        val defaultPeriods: List<TimetablePeriod>
            get() = listOf(
                TimetablePeriod(name = "1限", startMinute = 9 * 60, endMinute = 10 * 60 + 30, sortOrder = 1),
                TimetablePeriod(name = "2限", startMinute = 10 * 60 + 40, endMinute = 12 * 60 + 10, sortOrder = 2),
                TimetablePeriod(name = "3限", startMinute = 13 * 60, endMinute = 14 * 60 + 30, sortOrder = 3),
                TimetablePeriod(name = "4限", startMinute = 14 * 60 + 40, endMinute = 16 * 60 + 10, sortOrder = 4),
                TimetablePeriod(name = "5限", startMinute = 16 * 60 + 20, endMinute = 17 * 60 + 50, sortOrder = 5),
                TimetablePeriod(name = "6限", startMinute = 18 * 60, endMinute = 19 * 60 + 30, sortOrder = 6),
                TimetablePeriod(name = "7限", startMinute = 19 * 60 + 40, endMinute = 21 * 60 + 10, sortOrder = 7)
            )
    }
}

data class TimetableEntry(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val termId: Long? = null,
    val termSyncId: String? = null,
    val dayOfWeek: StudyWeekday,
    val periodId: Long,
    val periodSyncId: String? = null,
    val subjectName: String,
    val courseName: String? = null,
    val roomName: String? = null,
    val validFromDate: Long? = null,
    val validToDate: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)

data class TimetableTerm(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val name: String,
    val startDate: Long,
    val endDate: Long,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val startDateValue: LocalDate
        get() = LocalDate.ofEpochDay(startDate)

    val endDateValue: LocalDate
        get() = LocalDate.ofEpochDay(endDate)

    val dateRangeText: String
        get() {
            val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd", Locale.JAPAN)
            return "${formatter.format(startDateValue)} - ${formatter.format(endDateValue)}"
        }

    fun contains(date: LocalDate): Boolean {
        val day = date.toEpochDay()
        return startDate <= day && day <= endDate
    }
}

data class TimetableReviewRecord(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val termId: Long,
    val termSyncId: String? = null,
    val entryId: Long,
    val entrySyncId: String? = null,
    val periodId: Long,
    val periodSyncId: String? = null,
    val occurrenceDate: Long,
    val dayOfWeek: StudyWeekday,
    val periodName: String,
    val periodStartMinute: Int,
    val periodEndMinute: Int,
    val subjectName: String,
    val courseName: String? = null,
    val roomName: String? = null,
    val isReviewed: Boolean = false,
    val note: String? = null,
    val isExcluded: Boolean = false,
    val reviewedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val occurrenceDateValue: LocalDate
        get() = LocalDate.ofEpochDay(occurrenceDate)

    val periodTimeRangeText: String
        get() = "${TimetablePeriod.timeText(periodStartMinute)}-${TimetablePeriod.timeText(periodEndMinute)}"
}

data class TimetableLesson(
    val entry: TimetableEntry,
    val period: TimetablePeriod,
    val dayOfWeek: StudyWeekday,
    val date: LocalDate,
    val isCurrent: Boolean
) {
    val statusTitle: String
        get() = if (isCurrent) "現在の授業" else "次の授業"
}
