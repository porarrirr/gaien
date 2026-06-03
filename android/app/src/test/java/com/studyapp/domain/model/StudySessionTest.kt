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

    @Test
    fun `problem summaries include sub question count without breaking main problem records`() {
        val session = StudySession(
            subjectId = 1,
            startTime = 0,
            endTime = 10_000,
            problemRecords = listOf(
                ProblemSessionRecord(number = 3, result = ProblemResult.CORRECT),
                ProblemSessionRecord(number = 3, result = ProblemResult.WRONG, subNumber = "2"),
                ProblemSessionRecord(number = 4, result = ProblemResult.CORRECT, subNumber = "1")
            )
        )

        assertEquals("3-4問（小問2件）", session.problemRangeText)
        assertEquals(1, session.effectiveWrongProblemCount)
        assertEquals("3:2", session.problemRecords[1].stableKey)
    }

    @Test
    fun `review resolver treats manual review correct as correct input`() {
        val records = ProblemSessionReviewResolver.canonicalInputRecords(
            listOf(ProblemSessionRecord(number = 1, result = ProblemResult.REVIEW_CORRECT))
        )

        assertEquals(listOf(ProblemResult.CORRECT), records.map { it.result })
    }

    @Test
    fun `review resolver marks correct after previous wrong as review correct`() {
        val previousResults = linkedMapOf<String, ProblemResult>()
        val first = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            session = sessionWithRecords(
                startTime = 1_000,
                records = listOf(ProblemSessionRecord(number = 4, result = ProblemResult.WRONG))
            ),
            previousResults = previousResults
        )
        val second = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            session = sessionWithRecords(
                startTime = 2_000,
                records = listOf(ProblemSessionRecord(number = 4, result = ProblemResult.CORRECT))
            ),
            previousResults = previousResults
        )
        val third = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            session = sessionWithRecords(
                startTime = 3_000,
                records = listOf(ProblemSessionRecord(number = 4, result = ProblemResult.CORRECT))
            ),
            previousResults = previousResults
        )

        assertEquals(listOf(ProblemResult.WRONG), first.problemRecords.map { it.result })
        assertEquals(listOf(ProblemResult.REVIEW_CORRECT), second.problemRecords.map { it.result })
        assertEquals(listOf(ProblemResult.CORRECT), third.problemRecords.map { it.result })
        assertEquals(0, second.wrongProblemCount)
    }

    private fun sessionWithRecords(
        startTime: Long,
        records: List<ProblemSessionRecord>
    ): StudySession {
        return StudySession(
            materialId = 10,
            subjectId = 1,
            startTime = startTime,
            endTime = startTime + 600_000,
            problemRecords = records
        )
    }
}
