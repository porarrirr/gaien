package com.studyapp.presentation.settings

import android.content.Context
import com.studyapp.domain.model.AnkiIntegrationStatus
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import com.studyapp.sync.AuthRepository
import com.studyapp.sync.AuthSession
import com.studyapp.sync.SyncChangeNotifier
import com.studyapp.sync.SyncRepository
import com.studyapp.sync.SyncStatus
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
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
class SettingsViewModelTest {
    private val testDispatcher = StandardTestDispatcher()

    private lateinit var studySessionRepository: StudySessionRepository
    private lateinit var ankiRepository: AnkiRepository
    private lateinit var themePreferences: ThemePreferences
    private lateinit var reminderPreferences: ReminderPreferences
    private lateinit var exportImportDataUseCase: com.studyapp.domain.usecase.ExportImportDataUseCase
    private lateinit var authRepository: AuthRepository
    private lateinit var syncRepository: SyncRepository
    private lateinit var syncChangeNotifier: SyncChangeNotifier
    private lateinit var appContext: Context

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        studySessionRepository = mockk()
        ankiRepository = mockk()
        themePreferences = mockk()
        reminderPreferences = mockk()
        exportImportDataUseCase = mockk(relaxed = true)
        authRepository = mockk()
        syncRepository = mockk()
        syncChangeNotifier = mockk(relaxed = true)
        appContext = mockk(relaxed = true)

        every { studySessionRepository.getAllSessions() } returns flowOf(Result.Success(emptyList()))
        every { ankiRepository.observeTodayStats() } returns flowOf(
            AnkiTodayStats(
                answeredCards = 7,
                usageMinutes = 12,
                status = AnkiIntegrationStatus.AVAILABLE
            )
        )
        coEvery { ankiRepository.refreshTodayStats() } returns Unit
        every { themePreferences.getPrimaryColor() } returns flowOf(ColorTheme.GREEN)
        every { themePreferences.getThemeMode() } returns flowOf(ThemeMode.SYSTEM)
        every { reminderPreferences.isReminderEnabled() } returns flowOf(false)
        every { reminderPreferences.getReminderTime() } returns flowOf("19:00")
        every { authRepository.session } returns MutableStateFlow<AuthSession?>(null)
        every { syncRepository.status } returns MutableStateFlow(SyncStatus())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `anki stats are reflected in settings ui state`() = runTest {
        val viewModel = SettingsViewModel(
            studySessionRepository = studySessionRepository,
            ankiRepository = ankiRepository,
            themePreferences = themePreferences,
            reminderPreferences = reminderPreferences,
            exportImportDataUseCase = exportImportDataUseCase,
            authRepository = authRepository,
            syncRepository = syncRepository,
            syncChangeNotifier = syncChangeNotifier,
            appContext = appContext
        )

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(7, state.ankiStats.answeredCards)
        assertEquals(12L, state.ankiStats.usageMinutes)
        assertEquals(AnkiIntegrationStatus.AVAILABLE, state.ankiStats.status)
        assertFalse(state.isRefreshingAnkiStats)
        coVerify { ankiRepository.refreshTodayStats() }
    }
}
