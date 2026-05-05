package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class StudySessionTest {
    @Test
    fun `duration sums completed intervals when present`() {
        val session = StudySession(
            subjectId = 1,
            startTime = 0,
            endTime = 10_000,
            intervals = listOf(
                StudySessionInterval(startTime = 1_000, endTime = 4_000),
                StudySessionInterval(startTime = 10_000, endTime = 16_000)
            )
        )

        assertEquals(9_000L, session.duration)
        assertEquals(1_000L, session.sessionStartTime)
        assertEquals(16_000L, session.sessionEndTime)
    }

    @Test
    fun `problem summaries prefer explicit problem records`() {
        val session = StudySession(
            subjectId = 1,
            startTime = 0,
            endTime = 10_000,
            problemStart = 1,
            problemEnd = 10,
            wrongProblemCount = 5,
            problemRecords = listOf(
                ProblemSessionRecord(number = 3, result = ProblemResult.CORRECT),
                ProblemSessionRecord(number = 4, result = ProblemResult.WRONG)
            )
        )

        assertEquals("3-4問", session.problemRangeText)
        assertEquals(1, session.effectiveWrongProblemCount)
    }
}
