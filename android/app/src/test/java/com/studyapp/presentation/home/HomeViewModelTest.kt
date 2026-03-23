package com.studyapp.presentation.home

import com.studyapp.domain.model.AnkiIntegrationStatus
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.usecase.GetHomeDataUseCase
import com.studyapp.domain.usecase.HomeData
import com.studyapp.domain.usecase.TodaySession
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
    private val testDispatcher = StandardTestDispatcher()

    private lateinit var getHomeDataUseCase: GetHomeDataUseCase
    private lateinit var ankiRepository: AnkiRepository

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        getHomeDataUseCase = mockk()
        ankiRepository = mockk()
        every { ankiRepository.observeTodayStats() } returns flowOf(
            AnkiTodayStats(status = AnkiIntegrationStatus.ANKI_NOT_INSTALLED)
        )
        coEvery { ankiRepository.refreshTodayStats() } returns Unit
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createDefaultHomeData() = HomeData(
        todayStudyMinutes = 0L,
        todaySessions = emptyList(),
        weeklyGoal = null,
        weeklyStudyMinutes = 0L,
        upcomingExams = emptyList()
    )

    @Test
    fun `initial state is loading`() = runTest {
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData())

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)

        val state = viewModel.uiState.value
        assertTrue(state.isLoading)
        assertNull(state.error)
    }

    @Test
    fun `loadData emits success state with data`() = runTest {
        val expectedData = HomeData(
            todayStudyMinutes = 120L,
            todaySessions = listOf(
                TodaySession(
                    id = 1L,
                    subjectName = "Math",
                    materialName = "Textbook",
                    duration = 3_600_000L,
                    startTime = System.currentTimeMillis()
                )
            ),
            weeklyGoal = Goal(
                id = 1L,
                type = GoalType.WEEKLY,
                targetMinutes = 300,
                isActive = true
            ),
            weeklyStudyMinutes = 600L,
            upcomingExams = listOf(
                Exam(
                    id = 1L,
                    name = "Final Exam",
                    date = LocalDate.now().plusDays(7)
                )
            )
        )

        every { getHomeDataUseCase() } returns flowOf(expectedData)

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNull(state.error)
        assertEquals(120L, state.todayStudyMinutes)
        assertEquals(1, state.todaySessions.size)
        assertEquals("Math", state.todaySessions.first().subjectName)
        assertNotNull(state.weeklyGoal)
        assertEquals(300, state.weeklyGoal?.targetMinutes)
        assertEquals(600L, state.weeklyStudyMinutes)
        assertEquals(1, state.upcomingExams.size)
        assertEquals("Final Exam", state.upcomingExams.first().name)

        verify { getHomeDataUseCase() }
    }

    @Test
    fun `loadData emits error state on failure`() = runTest {
        val exception = RuntimeException("Database error")
        every { getHomeDataUseCase() } returns flow { throw exception }

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNotNull(state.error)
        assertEquals("Database error", state.error)

        verify { getHomeDataUseCase() }
    }

    @Test
    fun `loadData emits error state with default message when exception has no message`() = runTest {
        every { getHomeDataUseCase() } returns flow { throw RuntimeException() }

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("データの読み込みに失敗しました", state.error)
    }

    @Test
    fun `state has zero study minutes when no sessions`() = runTest {
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData())

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(0L, state.todayStudyMinutes)
        assertEquals(0L, state.weeklyStudyMinutes)
        assertTrue(state.todaySessions.isEmpty())
    }

    @Test
    fun `state has no goal when weeklyGoal is null`() = runTest {
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData())

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        assertNull(viewModel.uiState.value.weeklyGoal)
    }

    @Test
    fun `state has goal when weeklyGoal is set`() = runTest {
        val goal = Goal(
            id = 1L,
            type = GoalType.WEEKLY,
            targetMinutes = 500,
            isActive = true
        )
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData().copy(weeklyGoal = goal))

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertNotNull(state.weeklyGoal)
        assertEquals(500, state.weeklyGoal?.targetMinutes)
        assertEquals(GoalType.WEEKLY, state.weeklyGoal?.type)
    }

    @Test
    fun `state has empty exams list when no exams`() = runTest {
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData())

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.upcomingExams.isEmpty())
    }

    @Test
    fun `state has exams when exams are returned`() = runTest {
        val exams = listOf(
            Exam(id = 1L, name = "Math Test", date = LocalDate.now().plusDays(3)),
            Exam(id = 2L, name = "Science Test", date = LocalDate.now().plusDays(5))
        )
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData().copy(upcomingExams = exams))

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(2, state.upcomingExams.size)
        assertEquals("Math Test", state.upcomingExams[0].name)
        assertEquals("Science Test", state.upcomingExams[1].name)
    }

    @Test
    fun `retry resets loading state and reloads data`() = runTest {
        val expectedData = HomeData(
            todayStudyMinutes = 60L,
            todaySessions = emptyList(),
            weeklyGoal = null,
            weeklyStudyMinutes = 100L,
            upcomingExams = emptyList()
        )
        every { getHomeDataUseCase() } returns flowOf(expectedData)

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.retry()
        assertTrue(viewModel.uiState.value.isLoading)

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNull(state.error)
        assertEquals(60L, state.todayStudyMinutes)

        verify(exactly = 2) { getHomeDataUseCase() }
        coVerify(exactly = 2) { ankiRepository.refreshTodayStats() }
    }

    @Test
    fun `clearError removes error from state`() = runTest {
        every { getHomeDataUseCase() } returns flow { throw RuntimeException("Test error") }

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        assertNotNull(viewModel.uiState.value.error)

        viewModel.clearError()

        assertNull(viewModel.uiState.value.error)
    }

    @Test
    fun `todaySessions preserves order from UseCase`() = runTest {
        val now = System.currentTimeMillis()
        val sessions = listOf(
            TodaySession(id = 2L, subjectName = "English", materialName = "", duration = 2_000L, startTime = now),
            TodaySession(id = 1L, subjectName = "Math", materialName = "", duration = 1_000L, startTime = now - 1_000),
            TodaySession(id = 3L, subjectName = "Science", materialName = "", duration = 3_000L, startTime = now - 2_000)
        )
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData().copy(todaySessions = sessions))

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(3, state.todaySessions.size)
        assertEquals("English", state.todaySessions[0].subjectName)
        assertEquals("Math", state.todaySessions[1].subjectName)
        assertEquals("Science", state.todaySessions[2].subjectName)
    }

    @Test
    fun `multiple data emissions update state correctly`() = runTest {
        val firstData = HomeData(
            todayStudyMinutes = 30L,
            todaySessions = emptyList(),
            weeklyGoal = null,
            weeklyStudyMinutes = 100L,
            upcomingExams = emptyList()
        )
        val secondData = HomeData(
            todayStudyMinutes = 90L,
            todaySessions = emptyList(),
            weeklyGoal = null,
            weeklyStudyMinutes = 200L,
            upcomingExams = emptyList()
        )
        every { getHomeDataUseCase() } returns flowOf(firstData, secondData)

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(90L, state.todayStudyMinutes)
        assertEquals(200L, state.weeklyStudyMinutes)
    }

    @Test
    fun `anki stats are reflected in ui state`() = runTest {
        every { getHomeDataUseCase() } returns flowOf(createDefaultHomeData())
        every { ankiRepository.observeTodayStats() } returns flowOf(
            AnkiTodayStats(
                answeredCards = 24,
                usageMinutes = 36,
                status = AnkiIntegrationStatus.AVAILABLE
            )
        )

        val viewModel = HomeViewModel(getHomeDataUseCase, ankiRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(24, state.ankiStats.answeredCards)
        assertEquals(36L, state.ankiStats.usageMinutes)
        assertEquals(AnkiIntegrationStatus.AVAILABLE, state.ankiStats.status)
        assertFalse(state.isRefreshingAnkiStats)
        coVerify { ankiRepository.refreshTodayStats() }
    }
}
