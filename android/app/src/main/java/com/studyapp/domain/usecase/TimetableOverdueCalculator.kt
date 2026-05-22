package com.studyapp.domain.usecase

import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

object TimetableOverdueCalculator {
    private const val OVERDUE_HOURS = 48L

    fun overdueCount(
        reference: LocalDateTime,
        terms: List<TimetableTerm>,
        periods: List<TimetablePeriod>,
        entries: List<TimetableEntry>,
        reviews: List<TimetableReviewRecord>
    ): Int {
        val activePeriods = periods
            .filter { it.isActive && it.deletedAt == null && it.startMinute < it.endMinute }
            .sortedWith(compareBy<TimetablePeriod> { it.sortOrder }.thenBy { it.startMinute })
        if (activePeriods.isEmpty()) return 0

        val periodMap = activePeriods.associateBy { it.id }
        val reviewMap = reviews
            .filter { it.deletedAt == null }
            .groupBy { "${it.termId}-${it.entryId}-${it.periodId}-${it.occurrenceDate}" }
            .mapValues { (_, records) -> records.maxByOrNull { it.updatedAt } }
        val referenceDate = reference.toLocalDate()
        var overdue = 0

        for (term in terms.filter { it.deletedAt == null && it.isActive }) {
            var date = term.startDateValue
            val lastDate = minOf(term.endDateValue, referenceDate)
            while (!date.isAfter(lastDate)) {
                val occurrenceDate = date.toEpochDay()
                val weekday = StudyWeekday.fromDayOfWeek(date.dayOfWeek)
                for (entry in entries) {
                    if (entry.deletedAt != null) continue
                    if (entry.termId != term.id && entry.termId != null) continue
                    if (entry.dayOfWeek != weekday) continue
                    if (entry.validFromDate != null && occurrenceDate < entry.validFromDate) continue
                    if (entry.validToDate != null && occurrenceDate > entry.validToDate) continue
                    val period = periodMap[entry.periodId] ?: continue
                    val key = "${term.id}-${entry.id}-${period.id}-$occurrenceDate"
                    val review = reviewMap[key]
                    if (review?.isReviewed == true || review?.isExcluded == true) continue
                    val endDateTime = LocalDateTime.of(
                        date,
                        LocalTime.of(period.endMinute / 60, period.endMinute % 60)
                    )
                    if (!reference.isBefore(endDateTime.plusHours(OVERDUE_HOURS))) {
                        overdue += 1
                    }
                }
                date = date.plusDays(1)
            }
        }

        return overdue
    }
}
