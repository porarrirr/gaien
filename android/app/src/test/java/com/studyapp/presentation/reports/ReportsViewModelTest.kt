package com.studyapp.presentation.reports

import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ReportsViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var subjectRepository: SubjectRepository
    private lateinit var clock: Clock

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        studySessionRepository = mockk()
        subjectRepository = mockk()
        clock = mockk()

        every { clock.currentTimeMillis() } returns 1_700_000_000_000L
        every { clock.startOfToday() } returns 1_700_000_000_000L
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(emptyList()))
        coEvery { studySessionRepository.getTotalDurationBetweenDates(any(), any()) } returns Result.Success(0L)
        coEvery { studySessionRepository.getTotalDurationByDate(any()) } returns Result.Success(0L)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `loadReports surfaces typed repository errors without casts`() = runTest {
        coEvery {
            studySessionRepository.getTotalDurationBetweenDates(any(), any())
        } returns Result.Error(IllegalStateException("boom"), "daily failed")

        val viewModel = ReportsViewModel(
            studySessionRepository = studySessionRepository,
            subjectRepository = subjectRepository,
            clock = clock
        )
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertEquals("daily failed", viewModel.uiState.value.error)
    }

    @Test
    fun `loadSubjectBreakdown uses injected clock for end time`() = runTest {
        val now = 1_700_000_123_456L
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())

        every { clock.currentTimeMillis() } returns now
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(listOf(subject)))
        coEvery { studySessionRepository.getTotalDurationBetweenDates(any(), any()) } returns Result.Success(60 * 60 * 1000L)
        coEvery { studySessionRepository.getTotalDurationByDate(any()) } returnsMany listOf(
            Result.Success(60 * 60 * 1000L),
            Result.Success(0L)
        )
        coEvery {
            studySessionRepository.getTotalDurationBySubjectBetweenDates(subject.id, any(), now)
        } returns Result.Success(2 * 60 * 60 * 1000L)

        ReportsViewModel(
            studySessionRepository = studySessionRepository,
            subjectRepository = subjectRepository,
            clock = clock
        )
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { studySessionRepository.getTotalDurationBySubjectBetweenDates(subject.id, any(), now) }
    }
}
