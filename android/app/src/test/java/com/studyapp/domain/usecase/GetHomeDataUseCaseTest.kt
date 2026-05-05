package com.studyapp.domain.usecase

import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

class GetHomeDataUseCaseTest {
    @Test
    fun `invoke combines current repositories into home data`() = runTest {
        val studySessionRepository = mockk<StudySessionRepository>()
        val goalRepository = mockk<GoalRepository>()
        val examRepository = mockk<ExamRepository>()
        val timetableRepository = mockk<TimetableRepository>()
        val clock = fixedClock()
        val session = StudySession(
            id = 10,
            subjectId = 1,
            subjectName = "数学",
            materialName = "問題集",
            startTime = 1_000,
            endTime = 121_000
        )
        val dailyGoal = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 60,
            dayOfWeek = StudyWeekday.TUESDAY
        )

        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns flowOf(Result.Success(listOf(session)))
        every { goalRepository.getAllGoals() } returns flowOf(Result.Success(listOf(dailyGoal)))
        every { examRepository.getUpcomingExams() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllPeriods() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllEntries() } returns flowOf(Result.Success(emptyList()))
        every { timetableRepository.getAllTerms() } returns flowOf(Result.Success(emptyList()))

        val result = GetHomeDataUseCase(
            studySessionRepository,
            goalRepository,
            examRepository,
            timetableRepository,
            clock
        )().first()

        assertEquals(2L, result.todayStudyMinutes)
        assertEquals(dailyGoal, result.todayGoal)
        assertEquals("数学", result.todaySessions.single().subjectName)
    }

    private fun fixedClock(): Clock = object : Clock {
        override fun currentTimeMillis(): Long = 1_000
        override fun currentLocalDate(): LocalDate = LocalDate.of(2026, 5, 5)
        override fun currentLocalDateTime(): LocalDateTime = LocalDateTime.of(2026, 5, 5, 10, 0)
        override fun startOfDay(timestamp: Long): Long = 0
        override fun startOfToday(): Long = 0
        override fun startOfWeek(): Long = 0
        override fun startOfMonth(): Long = 0
    }
}
