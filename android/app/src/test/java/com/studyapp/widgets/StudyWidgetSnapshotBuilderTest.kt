package com.studyapp.widgets

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import com.studyapp.testutil.LogMock
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StudyWidgetSnapshotBuilderTest {

    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var goalRepository: GoalRepository
    private lateinit var examRepository: ExamRepository
    private lateinit var clock: Clock
    private lateinit var builder: StudyWidgetSnapshotBuilder

    @Before
    fun setup() {
        LogMock.setup()
        studySessionRepository = mockk()
        goalRepository = mockk()
        examRepository = mockk()
        clock = mockk()
        builder = StudyWidgetSnapshotBuilder(
            studySessionRepository = studySessionRepository,
            goalRepository = goalRepository,
            examRepository = examRepository,
            clock = clock
        )
    }

    @After
    fun teardown() {
        LogMock.teardown()
    }

    @Test
    fun `build aggregates today weekly streak and exams`() = runTest {
        val zoneId = ZoneId.systemDefault()
        val today = LocalDate.of(2026, 3, 22)
        val todayStart = today.atStartOfDay(zoneId).toInstant().toEpochMilli()
        val now = todayStart + 12 * 60 * 60 * 1000L
        val weekStart = today.minusDays(6).atStartOfDay(zoneId).toInstant().toEpochMilli()

        val todaySession = StudySession(
            id = 1L,
            materialId = null,
            subjectId = 1L,
            startTime = todayStart + 60 * 60 * 1000L,
            endTime = todayStart + 3 * 60 * 60 * 1000L
        )
        val yesterdaySession = StudySession(
            id = 2L,
            materialId = null,
            subjectId = 1L,
            startTime = today.minusDays(1).atStartOfDay(zoneId).toInstant().toEpochMilli() + 30 * 60 * 1000L,
            endTime = today.minusDays(1).atStartOfDay(zoneId).toInstant().toEpochMilli() + 90 * 60 * 1000L
        )
        val olderSession = StudySession(
            id = 3L,
            materialId = null,
            subjectId = 1L,
            startTime = today.minusDays(3).atStartOfDay(zoneId).toInstant().toEpochMilli() + 30 * 60 * 1000L,
            endTime = today.minusDays(3).atStartOfDay(zoneId).toInstant().toEpochMilli() + 150 * 60 * 1000L
        )

        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { studySessionRepository.getAllSessions() } returns flowOf(
            Result.Success(listOf(todaySession, yesterdaySession, olderSession))
        )
        every { goalRepository.getActiveGoals() } returns flowOf(
            Result.Success(
                listOf(
                    Goal(type = GoalType.DAILY, targetMinutes = 180, dayOfWeek = today.dayOfWeek)
                )
            )
        )
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns flowOf(
            Result.Success(Goal(type = GoalType.WEEKLY, targetMinutes = 600))
        )
        every { examRepository.getUpcomingExams() } returns flowOf(
            Result.Success(
                listOf(
                    Exam(name = "数学", date = today.plusDays(2)),
                    Exam(name = "英語", date = today.plusDays(5))
                )
            )
        )

        val snapshot = builder.build()

        assertEquals(120L, snapshot.todayStudyMinutes)
        assertEquals(1, snapshot.todaySessionCount)
        assertEquals(180, snapshot.dailyGoalMinutes)
        assertEquals(600, snapshot.weeklyGoalMinutes)
        assertEquals(300L, snapshot.weeklyStudyMinutes)
        assertEquals(2, snapshot.streakDays)
        assertEquals(2, snapshot.bestStreak)
        assertEquals(2, snapshot.upcomingExams.size)
        assertEquals("数学", snapshot.upcomingExams.first().name)
        assertEquals(2L, snapshot.upcomingExams.first().daysRemaining)
    }

    @Test
    fun `build fills week activity with empty days when no sessions exist`() = runTest {
        val zoneId = ZoneId.systemDefault()
        val today = LocalDate.of(2026, 3, 22)
        val todayStart = today.atStartOfDay(zoneId).toInstant().toEpochMilli()
        val weekStart = today.minusDays(6).atStartOfDay(zoneId).toInstant().toEpochMilli()

        every { clock.currentTimeMillis() } returns todayStart + 8 * 60 * 60 * 1000L
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { studySessionRepository.getAllSessions() } returns flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns flowOf(Result.Success(null))
        every { examRepository.getUpcomingExams() } returns flowOf(Result.Success(emptyList()))

        val snapshot = builder.build()

        assertEquals(0L, snapshot.todayStudyMinutes)
        assertEquals(0, snapshot.todaySessionCount)
        assertEquals(0, snapshot.streakDays)
        assertTrue(snapshot.upcomingExams.isEmpty())
        assertEquals(7, snapshot.weekActivity.size)
        assertTrue(snapshot.weekActivity.all { it.minutes == 0L })
    }
}
