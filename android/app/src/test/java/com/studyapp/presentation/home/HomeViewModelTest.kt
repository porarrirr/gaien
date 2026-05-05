package com.studyapp.presentation.home

import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.usecase.GetHomeDataUseCase
import com.studyapp.domain.usecase.GetRecentMaterialsUseCase
import com.studyapp.domain.usecase.HomeData
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `home data updates ui state`() = runTest {
        val homeUseCase = mockk<GetHomeDataUseCase>()
        val recentMaterialsUseCase = mockk<GetRecentMaterialsUseCase>()
        val ankiRepository = mockk<AnkiRepository>()
        every { homeUseCase() } returns flowOf(
            HomeData(
                todayStudyMinutes = 25,
                todaySessions = emptyList(),
                todayGoal = null,
                weeklyGoal = null,
                weeklyStudyMinutes = 90,
                upcomingExams = emptyList()
            )
        )
        every { recentMaterialsUseCase() } returns flowOf(emptyList())
        every { ankiRepository.observeTodayStats() } returns flowOf(AnkiTodayStats(answeredCards = 3))
        coEvery { ankiRepository.refreshTodayStats() } returns Unit

        val viewModel = HomeViewModel(homeUseCase, recentMaterialsUseCase, ankiRepository)
        advanceUntilIdle()

        assertEquals(25L, viewModel.uiState.value.todayStudyMinutes)
        assertEquals(90L, viewModel.uiState.value.weeklyStudyMinutes)
        assertEquals(3, viewModel.uiState.value.ankiStats.answeredCards)
    }
}
