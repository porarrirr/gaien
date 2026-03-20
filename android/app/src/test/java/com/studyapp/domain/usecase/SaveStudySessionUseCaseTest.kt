package com.studyapp.domain.usecase

import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import com.studyapp.testutil.LogMock
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SaveStudySessionUseCaseTest {
    
    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var clock: Clock
    private lateinit var saveStudySessionUseCase: SaveStudySessionUseCase
    
    @Before
    fun setup() {
        LogMock.setup()
        studySessionRepository = mockk()
        clock = mockk()
        saveStudySessionUseCase = SaveStudySessionUseCase(studySessionRepository, clock)
    }
    
    @After
    fun teardown() {
        LogMock.teardown()
    }
    
    @Test
    fun `invoke saves session successfully`() = runTest {
        val currentTime = System.currentTimeMillis()
        val subjectId = 1L
        val materialId = 2L
        val duration = 3600000L
        
        every { clock.currentTimeMillis() } returns currentTime
        coEvery { studySessionRepository.insertSession(any()) } returns Result.Success(1L)
        
        val result = saveStudySessionUseCase(subjectId, materialId, duration)
        
        assertTrue(result.isSuccess)
        assertEquals(1L, result.getOrNull())
    }
    
    @Test
    fun `invoke returns error when duration is zero`() = runTest {
        val result = saveStudySessionUseCase(1L, null, 0L)
        
        assertTrue(result.isFailure)
        assertFalse(result.isSuccess)
    }
    
    @Test
    fun `invoke returns error when duration is negative`() = runTest {
        val result = saveStudySessionUseCase(1L, null, -1000L)
        
        assertTrue(result.isFailure)
        assertFalse(result.isSuccess)
    }
    
    @Test
    fun `invoke handles repository error`() = runTest {
        val currentTime = System.currentTimeMillis()
        val subjectId = 1L
        val materialId = 2L
        val duration = 3600000L
        
        every { clock.currentTimeMillis() } returns currentTime
        coEvery { studySessionRepository.insertSession(any()) } returns
            Result.Error(Exception("Database error"), "データベースエラー")
        
        val result = saveStudySessionUseCase(subjectId, materialId, duration)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `invoke creates session with correct values`() = runTest {
        val currentTime = System.currentTimeMillis()
        val subjectId = 1L
        val materialId = 2L
        val duration = 3600000L
        
        every { clock.currentTimeMillis() } returns currentTime
        coEvery { 
            studySessionRepository.insertSession(match { session ->
                session.subjectId == subjectId &&
                session.materialId == materialId &&
                session.duration == duration &&
                session.startTime == currentTime - duration &&
                session.endTime == currentTime
            })
        } returns Result.Success(1L)
        
        val result = saveStudySessionUseCase(subjectId, materialId, duration)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `invoke saves session without material`() = runTest {
        val currentTime = System.currentTimeMillis()
        val subjectId = 1L
        val duration = 1800000L
        
        every { clock.currentTimeMillis() } returns currentTime
        coEvery { 
            studySessionRepository.insertSession(match { session ->
                session.subjectId == subjectId &&
                session.materialId == null &&
                session.duration == duration
            })
        } returns Result.Success(1L)
        
        val result = saveStudySessionUseCase(subjectId, null, duration)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `invoke handles large duration`() = runTest {
        val currentTime = System.currentTimeMillis()
        val subjectId = 1L
        val duration = 8 * 60 * 60 * 1000L
        
        every { clock.currentTimeMillis() } returns currentTime
        coEvery { studySessionRepository.insertSession(any()) } returns Result.Success(1L)
        
        val result = saveStudySessionUseCase(subjectId, null, duration)
        
        assertTrue(result.isSuccess)
    }
}