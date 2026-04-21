package com.studyapp.domain.usecase

import app.cash.turbine.test
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
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

class GetHomeDataUseCaseTest {
    
    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var goalRepository: GoalRepository
    private lateinit var examRepository: ExamRepository
    private lateinit var clock: Clock
    private lateinit var getHomeDataUseCase: GetHomeDataUseCase
    
    @Before
    fun setup() {
        LogMock.setup()
        studySessionRepository = mockk()
        goalRepository = mockk()
        examRepository = mockk()
        clock = mockk()
        getHomeDataUseCase = GetHomeDataUseCase(
            studySessionRepository,
            goalRepository,
            examRepository,
            clock
        )
    }
    
    @After
    fun teardown() {
        LogMock.teardown()
    }
    
    @Test
    fun `invoke returns home data with correct values`() = runTest {
        val todayStart = System.currentTimeMillis()
        val weekStart = todayStart - 3 * 24 * 60 * 60 * 1000L
        
        val session1 = StudySession(
            id = 1,
            subjectId = 1L,
            subjectName = "Math",
            materialId = 1L,
            materialName = "Textbook",
            startTime = todayStart + 3600000,
            endTime = todayStart + 7200000
        )
        val session2 = StudySession(
            id = 2,
            subjectId = 2L,
            subjectName = "English",
            materialId = null,
            materialName = "",
            startTime = todayStart + 10800000,
            endTime = todayStart + 14400000
        )
        
        val weeklyGoal = Goal(
            id = 1,
            type = GoalType.WEEKLY,
            targetMinutes = 600,
            isActive = true
        )
        val todayGoal = Goal(
            id = 3,
            type = GoalType.DAILY,
            targetMinutes = 90,
            dayOfWeek = DayOfWeek.MONDAY,
            isActive = true
        )
        
        val exam1 = Exam(
            id = 1,
            name = "Math Test",
            date = LocalDate.now().plusDays(7)
        )
        val exam2 = Exam(
            id = 2,
            name = "English Test",
            date = LocalDate.now().plusDays(14)
        )
        
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { clock.currentLocalDate() } returns LocalDate.of(2026, 1, 5)
        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + 86400000) } returns
            flowOf(Result.Success(listOf(session1, session2)))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + 604800000) } returns
            flowOf(Result.Success(listOf(session1, session2)))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(listOf(todayGoal, weeklyGoal)))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(weeklyGoal))
        every { examRepository.getUpcomingExams() } returns
            flowOf(Result.Success(listOf(exam1, exam2)))
        
        getHomeDataUseCase().test {
            val homeData = awaitItem()
            
            assertEquals(120L, homeData.todayStudyMinutes)
            assertEquals(2, homeData.todaySessions.size)
            assertEquals(todayGoal, homeData.todayGoal)
            assertEquals(weeklyGoal, homeData.weeklyGoal)
            assertEquals(120L, homeData.weeklyStudyMinutes)
            assertEquals(2, homeData.upcomingExams.size)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `invoke handles repository error gracefully`() = runTest {
        val todayStart = System.currentTimeMillis()
        val weekStart = todayStart - 3 * 24 * 60 * 60 * 1000L
        
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { clock.currentLocalDate() } returns LocalDate.of(2026, 1, 5)
        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + 86400000) } returns
            flowOf(Result.Error(Exception("Database error")))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + 604800000) } returns
            flowOf(Result.Error(Exception("Database error")))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Error(Exception("Database error")))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Error(Exception("Database error")))
        every { examRepository.getUpcomingExams() } returns
            flowOf(Result.Error(Exception("Database error")))
        
        getHomeDataUseCase().test {
            val homeData = awaitItem()
            
            assertEquals(0L, homeData.todayStudyMinutes)
            assertTrue(homeData.todaySessions.isEmpty())
            assertNull(homeData.todayGoal)
            assertNull(homeData.weeklyGoal)
            assertEquals(0L, homeData.weeklyStudyMinutes)
            assertTrue(homeData.upcomingExams.isEmpty())
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `invoke returns empty data when no sessions exist`() = runTest {
        val todayStart = System.currentTimeMillis()
        val weekStart = todayStart - 3 * 24 * 60 * 60 * 1000L
        
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { clock.currentLocalDate() } returns LocalDate.of(2026, 1, 5)
        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + 86400000) } returns
            flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + 604800000) } returns
            flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(null))
        every { examRepository.getUpcomingExams() } returns
            flowOf(Result.Success(emptyList()))
        
        getHomeDataUseCase().test {
            val homeData = awaitItem()
            
            assertEquals(0L, homeData.todayStudyMinutes)
            assertTrue(homeData.todaySessions.isEmpty())
            assertNull(homeData.todayGoal)
            assertNull(homeData.weeklyGoal)
            assertEquals(0L, homeData.weeklyStudyMinutes)
            assertTrue(homeData.upcomingExams.isEmpty())
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `invoke sorts sessions by start time descending`() = runTest {
        val todayStart = System.currentTimeMillis()
        val weekStart = todayStart - 3 * 24 * 60 * 60 * 1000L
        
        val earlierSession = StudySession(
            id = 1,
            subjectId = 1L,
            subjectName = "Math",
            materialId = null,
            materialName = "",
            startTime = todayStart + 3600000,
            endTime = todayStart + 7200000
        )
        val laterSession = StudySession(
            id = 2,
            subjectId = 2L,
            subjectName = "English",
            materialId = null,
            materialName = "",
            startTime = todayStart + 10800000,
            endTime = todayStart + 14400000
        )
        
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { clock.currentLocalDate() } returns LocalDate.of(2026, 1, 5)
        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + 86400000) } returns
            flowOf(Result.Success(listOf(earlierSession, laterSession)))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + 604800000) } returns
            flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(null))
        every { examRepository.getUpcomingExams() } returns
            flowOf(Result.Success(emptyList()))
        
        getHomeDataUseCase().test {
            val homeData = awaitItem()
            
            assertEquals(2, homeData.todaySessions.size)
            assertEquals(2L, homeData.todaySessions[0].id)
            assertEquals(1L, homeData.todaySessions[1].id)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `invoke sorts exams by date`() = runTest {
        val todayStart = System.currentTimeMillis()
        val weekStart = todayStart - 3 * 24 * 60 * 60 * 1000L
        
        val exam1 = Exam(
            id = 1,
            name = "Later Exam",
            date = LocalDate.now().plusDays(14)
        )
        val exam2 = Exam(
            id = 2,
            name = "Sooner Exam",
            date = LocalDate.now().plusDays(7)
        )
        
        every { clock.startOfToday() } returns todayStart
        every { clock.startOfWeek() } returns weekStart
        every { clock.currentLocalDate() } returns LocalDate.of(2026, 1, 5)
        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + 86400000) } returns
            flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + 604800000) } returns
            flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(null))
        every { examRepository.getUpcomingExams() } returns
            flowOf(Result.Success(listOf(exam1, exam2)))
        
        getHomeDataUseCase().test {
            val homeData = awaitItem()
            
            assertEquals(2, homeData.upcomingExams.size)
            assertEquals("Sooner Exam", homeData.upcomingExams[0].name)
            assertEquals("Later Exam", homeData.upcomingExams[1].name)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
}
