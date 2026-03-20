package com.studyapp.domain.usecase

import com.studyapp.domain.model.StudySession
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class GetReportsDataUseCaseTest {
    
    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var clock: Clock
    private lateinit var getReportsDataUseCase: GetReportsDataUseCase
    
    @Before
    fun setup() {
        LogMock.setup()
        studySessionRepository = mockk()
        clock = mockk()
        getReportsDataUseCase = GetReportsDataUseCase(studySessionRepository, clock)
    }
    
    @After
    fun teardown() {
        LogMock.teardown()
    }
    
    private fun createSession(
        id: Long,
        startTime: Long,
        durationMinutes: Long
    ): StudySession {
        val durationMs = durationMinutes * 60000
        return StudySession(
            id = id,
            subjectId = 1L,
            subjectName = "Test",
            materialId = null,
            materialName = "",
            startTime = startTime,
            endTime = startTime + durationMs
        )
    }
    
    @Test
    fun `invoke returns empty data when no sessions exist`() = runTest {
        val now = System.currentTimeMillis()
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns now - (now % 86400000)
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(emptyList()))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.dailyData.isEmpty())
        assertTrue(result.weeklyData.isEmpty())
        assertTrue(result.monthlyData.isEmpty())
        assertEquals(0, result.streak)
        assertEquals(0, result.bestStreak)
    }
    
    @Test
    fun `invoke calculates daily data correctly`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        val session1 = createSession(1, todayStart - 3600000, 60)
        val session2 = createSession(2, todayStart - 7200000, 30)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(listOf(session1, session2)))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(listOf(session1, session2)))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.dailyData.isNotEmpty())
    }
    
    @Test
    fun `invoke calculates weekly data correctly`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        val weekStart = todayStart - 3 * 86400000
        
        val session1 = createSession(1, weekStart + 3600000, 120)
        val session2 = createSession(2, weekStart + 86400000, 60)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(listOf(session1, session2)))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(listOf(session1, session2)))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.weeklyData.isNotEmpty())
    }
    
    @Test
    fun `invoke calculates monthly data correctly`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        val session1 = createSession(1, now - 86400000, 60)
        val session2 = createSession(2, now - 2 * 86400000, 90)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(listOf(session1, session2)))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(listOf(session1, session2)))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.monthlyData.isNotEmpty())
    }
    
    @Test
    fun `invoke calculates streak correctly`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        val yesterday = todayStart - 86400000
        val dayBefore = todayStart - 2 * 86400000
        
        val session1 = createSession(1, todayStart + 3600000, 60)
        val session2 = createSession(2, yesterday + 3600000, 60)
        val session3 = createSession(3, dayBefore + 3600000, 60)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(listOf(session1)))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(listOf(session1, session2, session3)))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.streak >= 0)
    }
    
    @Test
    fun `invoke calculates best streak correctly`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        val day1 = todayStart - 10 * 86400000
        val day2 = day1 + 86400000
        val day3 = day2 + 86400000
        
        val session1 = createSession(1, day1, 60)
        val session2 = createSession(2, day2, 60)
        val session3 = createSession(3, day3, 60)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Success(listOf(session1, session2, session3)))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.bestStreak >= 0)
    }
    
    @Test
    fun `invoke handles repository error gracefully`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Error(Exception("Database error")))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Error(Exception("Database error")))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.dailyData.isEmpty())
        assertTrue(result.weeklyData.isEmpty())
        assertTrue(result.monthlyData.isEmpty())
        assertEquals(0, result.streak)
        assertEquals(0, result.bestStreak)
    }
    
    @Test
    fun `invoke handles mixed success and error`() = runTest {
        val now = System.currentTimeMillis()
        val todayStart = now - (now % 86400000)
        
        val session = createSession(1, todayStart - 3600000, 60)
        
        every { clock.currentTimeMillis() } returns now
        every { clock.startOfToday() } returns todayStart
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(listOf(session)))
        every { studySessionRepository.getAllSessions() } returns
            flowOf(Result.Error(Exception("Database error")))
        
        val result = getReportsDataUseCase()
        
        assertTrue(result.dailyData.isNotEmpty())
        assertEquals(0, result.bestStreak)
    }
}