package com.studyapp.domain.usecase

import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.ProblemReviewRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class GetHomeDataUseCaseTest {
    @Test
    fun `today review problems include old latest records that are not correct`() = runTest {
        val todayStart = 1_700_000_000_000L
        val oldWrongRecord = ProblemReviewRecord(
            problemId = ProblemReviewRecord.problemId(1, 12),
            materialId = 1,
            materialSyncId = "material-sync",
            problemNumber = 12,
            reviewedAt = todayStart - DAY_MS - 1,
            rating = ProblemReviewRating.AGAIN,
            nextReviewDate = todayStart + DAY_MS,
            consecutiveCorrectCount = 0,
            wrongCount = 2
        )
        val recentWrongRecord = oldWrongRecord.copy(
            syncId = "recent",
            problemId = ProblemReviewRecord.problemId(1, 13),
            problemNumber = 13,
            reviewedAt = todayStart - DAY_MS + 1,
            nextReviewDate = todayStart - DAY_MS
        )
        val oldGoodRecord = oldWrongRecord.copy(
            syncId = "good",
            problemId = ProblemReviewRecord.problemId(1, 14),
            problemNumber = 14,
            reviewedAt = todayStart - DAY_MS - 1,
            rating = ProblemReviewRating.GOOD,
            nextReviewDate = todayStart - DAY_MS
        )
        val olderWrongRecordSupersededByGood = oldWrongRecord.copy(
            syncId = "older-wrong",
            problemId = ProblemReviewRecord.problemId(1, 15),
            problemNumber = 15,
            reviewedAt = todayStart - DAY_MS * 3,
            nextReviewDate = todayStart - DAY_MS
        )
        val latestGoodRecord = olderWrongRecordSupersededByGood.copy(
            syncId = "latest-good",
            reviewedAt = todayStart - DAY_MS - 1,
            rating = ProblemReviewRating.GOOD
        )

        val studySessionRepository = mockk<StudySessionRepository>()
        val materialRepository = mockk<MaterialRepository>()
        val subjectRepository = mockk<SubjectRepository>()
        val problemReviewRepository = mockk<ProblemReviewRepository>()
        val goalRepository = mockk<GoalRepository>()
        val examRepository = mockk<ExamRepository>()
        val timetableRepository = mockk<TimetableRepository>()

        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns flowOf(Result.Success(emptyList()))
        every { materialRepository.getAllMaterials() } returns flowOf(
            Result.Success(listOf(Material(id = 1, name = "数学問題集", subjectId = 2)))
        )
        every { subjectRepository.getAllSubjects() } returns flowOf(
            Result.Success(listOf(Subject(id = 2, name = "数学", color = 0x4CAF50)))
        )
        every { problemReviewRepository.getActiveReviewRecords() } returns flowOf(
            Result.Success(
                listOf(
                    recentWrongRecord,
                    oldGoodRecord,
                    olderWrongRecordSupersededByGood,
                    latestGoodRecord,
                    oldWrongRecord
                )
            )
        )
        every { goalRepository.getAllGoals() } returns flowOf(Result.Success(emptyList()))
        every { examRepository.getUpcomingExams() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllPeriods() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllEntries() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllTerms() } returns flowOf(Result.Success(emptyList()))

        val useCase = GetHomeDataUseCase(
            studySessionRepository = studySessionRepository,
            materialRepository = materialRepository,
            subjectRepository = subjectRepository,
            problemReviewRepository = problemReviewRepository,
            goalRepository = goalRepository,
            examRepository = examRepository,
            timetableRepository = timetableRepository,
            clock = FixedClock(todayStart)
        )

        val result = useCase().first()

        assertEquals(1, result.todayReviewProblems.size)
        assertEquals("数学問題集", result.todayReviewProblems.first().materialName)
        assertEquals("数学", result.todayReviewProblems.first().subjectName)
        assertEquals(12, result.todayReviewProblems.first().problemNumber)
    }

    private class FixedClock(private val todayStart: Long) : Clock {
        override fun currentTimeMillis(): Long = todayStart
        override fun currentLocalDate(): LocalDate = LocalDate.of(2026, 5, 6)
        override fun currentLocalDateTime(): LocalDateTime = currentLocalDate().atStartOfDay()
        override fun startOfDay(timestamp: Long): Long = todayStart
        override fun startOfToday(): Long = todayStart
        override fun startOfWeek(): Long = todayStart
        override fun startOfMonth(): Long = todayStart
    }

    private companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
    }
}
