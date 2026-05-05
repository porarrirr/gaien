package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ExamTest {
    @Test
    fun `daysRemaining uses epoch-day date`() {
        val today = LocalDate.of(2026, 5, 5)
        val exam = Exam(id = 1, name = "Test", date = today.plusDays(7).toEpochDay())

        assertEquals(7, exam.daysRemaining(today))
    }

    @Test
    fun `date helpers identify today and past exams`() {
        val today = LocalDate.of(2026, 5, 5)
        val todayExam = Exam(id = 1, name = "Today", date = today.toEpochDay())
        val pastExam = Exam(id = 2, name = "Past", date = today.minusDays(1).toEpochDay())

        assertTrue(todayExam.isToday(today))
        assertFalse(todayExam.isPast(today))
        assertTrue(pastExam.isPast(today))
    }
}
