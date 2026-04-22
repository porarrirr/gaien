package com.studyapp.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class StudySessionTest {
    
    @Test
    fun `durationMinutes calculates correctly`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 180000
        )
        assertEquals(3L, session.durationMinutes)
    }
    
    @Test
    fun `durationMinutes returns correct value for one hour`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 3600000
        )
        assertEquals(60L, session.durationMinutes)
    }
    
    @Test
    fun `durationHours returns correct value`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 7200000
        )
        assertEquals(2f, session.durationHours, 0.01f)
    }
    
    @Test
    fun `durationHours returns correct decimal value`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 5400000
        )
        assertEquals(1.5f, session.durationHours, 0.01f)
    }
    
    @Test
    fun `durationFormatted returns correct format for hours`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 3661000
        )
        assertEquals("1:01:01", session.durationFormatted)
    }
    
    @Test
    fun `durationFormatted returns correct format for minutes only`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 61000
        )
        assertEquals("01:01", session.durationFormatted)
    }
    
    @Test
    fun `durationFormatted returns correct format for seconds only`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 45000
        )
        assertEquals("00:45", session.durationFormatted)
    }
    
    @Test
    fun `durationFormatted handles zero duration`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 1000L,
            endTime = 1000L
        )
        assertEquals(0L, session.duration)
        assertEquals("00:00", session.durationFormatted)
    }
    
    @Test
    fun `durationFormatted handles large duration`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 36000000
        )
        assertEquals(10L * 60 * 60 * 1000, session.duration)
        assertEquals("10:00:00", session.durationFormatted)
    }
    
    @Test
    fun `duration calculates correctly`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 1000L,
            endTime = 5000L
        )
        assertEquals(4000L, session.duration)
    }
    
    @Test
    fun `duration returns zero for same start and end time`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 1000L,
            endTime = 1000L
        )
        assertEquals(0L, session.duration)
    }
    
    @Test
    fun `duration returns negative when end before start`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 5000L,
            endTime = 1000L
        )
        assertEquals(-4000L, session.duration)
    }
    
    @Test
    fun `durationMinutes returns zero for zero duration`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 1000L,
            endTime = 1000L
        )
        assertEquals(0L, session.durationMinutes)
    }
    
    @Test
    fun `durationHours returns zero for zero duration`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 1000L,
            endTime = 1000L
        )
        assertEquals(0f, session.durationHours, 0.01f)
    }
    
    @Test
    fun `durationFormatted handles exact one hour`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 3600000
        )
        assertEquals("1:00:00", session.durationFormatted)
    }
    
    @Test
    fun `durationFormatted handles exact one minute`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 60000
        )
        assertEquals("01:00", session.durationFormatted)
    }
    
    @Test
    fun `session with material preserves material info`() {
        val session = StudySession(
            id = 1,
            materialId = 5L,
            materialName = "数学テキスト",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 3600000
        )
        assertEquals(5L, session.materialId)
        assertEquals("数学テキスト", session.materialName)
    }
    
    @Test
    fun `session with note preserves note`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = 0L,
            endTime = 3600000,
            note = "集中して勉強できた"
        )
        assertEquals("集中して勉強できた", session.note)
    }
    
    @Test
    fun `date extracts correct LocalDate from startTime`() {
        val expectedDate = LocalDate.of(2024, 1, 15)
        val startTime = expectedDate
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
        val session = StudySession(
            id = 1,
            materialId = null,
            materialName = "",
            subjectId = 1,
            subjectName = "数学",
            startTime = startTime,
            endTime = startTime + 3600000
        )
        assertEquals(expectedDate, session.date)
    }
    
    @Test
    fun `session defaults are correct`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            subjectId = 1,
            startTime = 0L,
            endTime = 3600000
        )
        assertEquals("", session.materialName)
        assertEquals("", session.subjectName)
        assertNull(session.note)
    }

    @Test
    fun `segmented session duration sums only active intervals`() {
        val session = StudySession(
            id = 1,
            materialId = null,
            subjectId = 1,
            startTime = 12 * 60 * 60 * 1000L,
            endTime = 12 * 60 * 60 * 1000L + 59 * 60 * 1000L,
            intervals = listOf(
                StudySessionInterval(
                    startTime = 12 * 60 * 60 * 1000L,
                    endTime = 12 * 60 * 60 * 1000L + 25 * 60 * 1000L
                ),
                StudySessionInterval(
                    startTime = 12 * 60 * 60 * 1000L + 40 * 60 * 1000L,
                    endTime = 12 * 60 * 60 * 1000L + 59 * 60 * 1000L
                )
            )
        )

        assertEquals(44L, session.durationMinutes)
        assertEquals(12 * 60 * 60 * 1000L, session.sessionStartTime)
        assertEquals(12 * 60 * 60 * 1000L + 59 * 60 * 1000L, session.sessionEndTime)
    }
}
