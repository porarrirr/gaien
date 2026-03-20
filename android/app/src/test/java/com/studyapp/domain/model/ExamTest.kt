package com.studyapp.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class ExamTest {
    
    @Test
    fun `getDaysRemaining returns 0 for today`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now())
        assertEquals(0L, exam.getDaysRemaining(LocalDate.now()))
    }
    
    @Test
    fun `getDaysRemaining returns positive for future date`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().plusDays(7))
        assertEquals(7L, exam.getDaysRemaining(LocalDate.now()))
    }
    
    @Test
    fun `getDaysRemaining returns negative for past date`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().minusDays(1))
        assertEquals(-1L, exam.getDaysRemaining(LocalDate.now()))
    }
    
    @Test
    fun `getDaysRemaining returns correct value for multiple weeks`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().plusDays(30))
        assertEquals(30L, exam.getDaysRemaining(LocalDate.now()))
    }
    
    @Test
    fun `isPast returns true for yesterday`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().minusDays(1))
        assertTrue(exam.isPast(LocalDate.now()))
    }
    
    @Test
    fun `isPast returns false for today`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now())
        assertFalse(exam.isPast(LocalDate.now()))
    }
    
    @Test
    fun `isPast returns false for tomorrow`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().plusDays(1))
        assertFalse(exam.isPast(LocalDate.now()))
    }
    
    @Test
    fun `isToday returns true for today`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now())
        assertTrue(exam.isToday(LocalDate.now()))
    }
    
    @Test
    fun `isToday returns false for yesterday`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().minusDays(1))
        assertFalse(exam.isToday(LocalDate.now()))
    }
    
    @Test
    fun `isToday returns false for tomorrow`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now().plusDays(1))
        assertFalse(exam.isToday(LocalDate.now()))
    }
    
    @Test
    fun `boundary test - yesterday at end of day vs today at start`() {
        val yesterday = LocalDate.now().minusDays(1)
        val today = LocalDate.now()
        
        val yesterdayExam = Exam(id = 1, name = "Yesterday Exam", date = yesterday)
        val todayExam = Exam(id = 2, name = "Today Exam", date = today)
        
        assertTrue(yesterdayExam.isPast(today))
        assertFalse(todayExam.isPast(today))
        assertEquals(1L, todayExam.getDaysRemaining(yesterday))
        assertEquals(-1L, yesterdayExam.getDaysRemaining(today))
    }
    
    @Test
    fun `boundary test - today vs tomorrow at midnight`() {
        val today = LocalDate.now()
        val tomorrow = LocalDate.now().plusDays(1)
        
        val todayExam = Exam(id = 1, name = "Today Exam", date = today)
        val tomorrowExam = Exam(id = 2, name = "Tomorrow Exam", date = tomorrow)
        
        assertTrue(todayExam.isToday(today))
        assertFalse(tomorrowExam.isToday(today))
        assertEquals(0L, todayExam.getDaysRemaining(today))
        assertEquals(1L, tomorrowExam.getDaysRemaining(today))
    }
    
    @Test
    fun `toEpochMillis returns start of day`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.of(2024, 1, 15))
        val millis = exam.toEpochMillis()
        val millisNextDay = Exam(id = 1, name = "Test", date = LocalDate.of(2024, 1, 16)).toEpochMillis()
        
        assertEquals(24 * 60 * 60 * 1000L, millisNextDay - millis)
    }
    
    @Test
    fun `fromTimestamp creates correct date in the provided timezone`() {
        val zoneId = ZoneId.of("Asia/Tokyo")
        val timestamp = ZonedDateTime.of(2024, 1, 15, 0, 30, 0, 0, zoneId)
            .toInstant()
            .toEpochMilli()

        val exam = Exam.fromTimestamp(
            id = 1,
            name = "Test",
            timestamp = timestamp,
            zoneId = zoneId
        )

        assertEquals(LocalDate.of(2024, 1, 15), exam.date)
    }
    
    @Test
    fun `exam with note preserves note`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now(), note = "Important exam")
        assertEquals("Important exam", exam.note)
    }
    
    @Test
    fun `exam with null note handles correctly`() {
        val exam = Exam(id = 1, name = "Test", date = LocalDate.now())
        assertNull(exam.note)
    }
}
