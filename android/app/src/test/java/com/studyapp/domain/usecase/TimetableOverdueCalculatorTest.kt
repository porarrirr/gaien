package com.studyapp.domain.usecase

import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class TimetableOverdueCalculatorTest {
    private val monday = LocalDate.of(2026, 5, 4)

    @Test
    fun `counts lesson exactly at 48 hours after period end`() {
        val count = overdueCount(reference = LocalDateTime.of(2026, 5, 6, 10, 0))

        assertEquals(1, count)
    }

    @Test
    fun `does not count lesson one minute before 48 hour threshold`() {
        val count = overdueCount(reference = LocalDateTime.of(2026, 5, 6, 9, 59))

        assertEquals(0, count)
    }

    @Test
    fun `reviewed or excluded latest review records suppress overdue lesson`() {
        val reviewed = review(isReviewed = true, updatedAt = 200)
        val olderUnreviewed = review(isReviewed = false, updatedAt = 100)
        val excluded = review(entryId = 2, periodId = 10, isExcluded = true, updatedAt = 200)
        val count = TimetableOverdueCalculator.overdueCount(
            reference = LocalDateTime.of(2026, 5, 7, 12, 0),
            terms = listOf(term()),
            periods = listOf(period()),
            entries = listOf(entry(id = 1), entry(id = 2)),
            reviews = listOf(olderUnreviewed, reviewed, excluded)
        )

        assertEquals(0, count)
    }

    @Test
    fun `valid date range filters entry occurrences`() {
        val count = TimetableOverdueCalculator.overdueCount(
            reference = LocalDateTime.of(2026, 5, 13, 12, 0),
            terms = listOf(term(start = monday, end = monday.plusDays(7))),
            periods = listOf(period()),
            entries = listOf(
                entry(validFromDate = monday.plusDays(7).toEpochDay()),
                entry(id = 2, validToDate = monday.minusDays(1).toEpochDay())
            ),
            reviews = emptyList()
        )

        assertEquals(1, count)
    }

    @Test
    fun `deleted inactive and invalid periods and entries are ignored`() {
        val count = TimetableOverdueCalculator.overdueCount(
            reference = LocalDateTime.of(2026, 5, 7, 12, 0),
            terms = listOf(term(), term(id = 2, isActive = false)),
            periods = listOf(
                period(deletedAt = 1),
                period(id = 11, startMinute = 600, endMinute = 600)
            ),
            entries = listOf(
                entry(periodId = 10),
                entry(id = 2, periodId = 11),
                entry(id = 3, deletedAt = 1)
            ),
            reviews = emptyList()
        )

        assertEquals(0, count)
    }

    private fun overdueCount(reference: LocalDateTime): Int =
        TimetableOverdueCalculator.overdueCount(
            reference = reference,
            terms = listOf(term()),
            periods = listOf(period()),
            entries = listOf(entry()),
            reviews = emptyList()
        )

    private fun term(
        id: Long = 1,
        start: LocalDate = monday,
        end: LocalDate = monday,
        isActive: Boolean = true
    ) = TimetableTerm(
        id = id,
        name = "2026春",
        startDate = start.toEpochDay(),
        endDate = end.toEpochDay(),
        isActive = isActive
    )

    private fun period(
        id: Long = 10,
        startMinute: Int = 9 * 60,
        endMinute: Int = 10 * 60,
        deletedAt: Long? = null
    ) = TimetablePeriod(
        id = id,
        name = "1限",
        startMinute = startMinute,
        endMinute = endMinute,
        sortOrder = id.toInt(),
        isActive = true,
        deletedAt = deletedAt
    )

    private fun entry(
        id: Long = 1,
        periodId: Long = 10,
        validFromDate: Long? = null,
        validToDate: Long? = null,
        deletedAt: Long? = null
    ) = TimetableEntry(
        id = id,
        termId = 1,
        dayOfWeek = StudyWeekday.MONDAY,
        periodId = periodId,
        subjectName = "数学",
        validFromDate = validFromDate,
        validToDate = validToDate,
        deletedAt = deletedAt
    )

    private fun review(
        entryId: Long = 1,
        periodId: Long = 10,
        isReviewed: Boolean = false,
        isExcluded: Boolean = false,
        updatedAt: Long
    ) = TimetableReviewRecord(
        termId = 1,
        entryId = entryId,
        periodId = periodId,
        occurrenceDate = monday.toEpochDay(),
        dayOfWeek = StudyWeekday.MONDAY,
        periodName = "1限",
        periodStartMinute = 9 * 60,
        periodEndMinute = 10 * 60,
        subjectName = "数学",
        isReviewed = isReviewed,
        isExcluded = isExcluded,
        updatedAt = updatedAt
    )
}
