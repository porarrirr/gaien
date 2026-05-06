package com.studyapp.presentation.settings

import android.content.Context
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.ThemeMode
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import com.studyapp.sync.AuthRepository
import com.studyapp.sync.AuthSession
import com.studyapp.sync.SyncChangeNotifier
import com.studyapp.sync.SyncRepository
import com.studyapp.sync.SyncStatus
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
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    private val testDispatcher = StandardTestDispatcher()

    private lateinit var studySessionRepository: StudySessionRepository
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
        themePreferences = mockk()
        reminderPreferences = mockk()
        exportImportDataUseCase = mockk(relaxed = true)
        authRepository = mockk()
        syncRepository = mockk()
        syncChangeNotifier = mockk(relaxed = true)
        appContext = mockk(relaxed = true)

        every { studySessionRepository.getAllSessions() } returns flowOf(Result.Success(emptyList()))
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
    fun `settings preferences are reflected in ui state`() = runTest {
        val viewModel = SettingsViewModel(
            studySessionRepository = studySessionRepository,
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
        assertEquals(ColorTheme.GREEN, state.selectedColorTheme)
        assertEquals(ThemeMode.SYSTEM, state.selectedThemeMode)
        assertEquals("19:00", state.reminderTime)
    }
}
