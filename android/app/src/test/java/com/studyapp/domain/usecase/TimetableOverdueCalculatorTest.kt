package com.studyapp.domain.usecase

import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableTerm
import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class TimetableOverdueCalculatorTest {
    @Test
    fun `counts lesson without review after 48 hours`() {
        val term = TimetableTerm(
            id = 1,
            name = "2026春",
            startDate = LocalDate.of(2026, 5, 1).toEpochDay(),
            endDate = LocalDate.of(2026, 5, 31).toEpochDay(),
            isActive = true
        )
        val period = TimetablePeriod(
            id = 10,
            name = "1限",
            startMinute = 9 * 60,
            endMinute = 10 * 60,
            sortOrder = 1,
            isActive = true
        )
        val entry = TimetableEntry(
            termId = 1,
            dayOfWeek = StudyWeekday.MONDAY,
            periodId = 10,
            subjectName = "数学"
        )
        val reference = LocalDateTime.of(2026, 5, 6, 12, 0)

        val count = TimetableOverdueCalculator.overdueCount(
            reference = reference,
            terms = listOf(term),
            periods = listOf(period),
            entries = listOf(entry),
            reviews = emptyList()
        )

        assertEquals(1, count)
    }
}
