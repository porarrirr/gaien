package com.studyapp.presentation.timer

import com.studyapp.domain.model.AppPreferences
import com.studyapp.domain.model.LandscapeTimerDisplayPreset
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.AppPreferencesRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.GetRecentMaterialsUseCase
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.domain.usecase.TimerServiceManager
import com.studyapp.domain.usecase.TimerStopResult
import com.studyapp.domain.util.Result
import com.studyapp.testutil.MainDispatcherRule
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.async
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TimerViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val subjectRepository = mockk<SubjectRepository>()
    private val materialRepository = mockk<MaterialRepository>()
    private val saveStudySessionUseCase = mockk<SaveStudySessionUseCase>()
    private val getRecentMaterialsUseCase = mockk<GetRecentMaterialsUseCase>()
    private val timerServiceManager = mockk<TimerServiceManager>(relaxed = true)
    private val appPreferencesRepository = mockk<AppPreferencesRepository>()

    private val elapsedTimeFlow = MutableStateFlow(0L)
    private val remainingTimeFlow = MutableStateFlow(0L)
    private val isRunningFlow = MutableStateFlow(false)
    private val isBoundFlow = MutableStateFlow(false)
    private val currentSubjectIdFlow = MutableStateFlow<Long?>(null)
    private val currentSubjectSyncIdFlow = MutableStateFlow<String?>(null)
    private val currentMaterialIdFlow = MutableStateFlow<Long?>(null)
    private val currentMaterialSyncIdFlow = MutableStateFlow<String?>(null)
    private val currentModeFlow = MutableStateFlow(TimerMode.STOPWATCH)
    private val currentTargetDurationMillisFlow = MutableStateFlow<Long?>(null)

    @Test
    fun `loadData maps repositories preferences service state and binds service`() = runTest {
        val math = subject(1, "Math")
        val english = subject(2, "English")
        val textbook = material(10, "Textbook", 1)
        val workbook = material(20, "Workbook", 2)
        currentSubjectSyncIdFlow.value = english.syncId
        currentMaterialSyncIdFlow.value = workbook.syncId
        currentModeFlow.value = TimerMode.TIMER
        currentTargetDurationMillisFlow.value = 15 * 60_000L
        isBoundFlow.value = true
        stubDefaults(
            subjects = listOf(math, english),
            materials = listOf(textbook, workbook),
            recent = listOf(textbook to math),
            preferences = AppPreferences(landscapeTimerDisplayPreset = LandscapeTimerDisplayPreset.CLOCK_ONLY)
        )

        val viewModel = createViewModel()
        advance()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals(listOf(math, english), state.subjects)
        assertEquals(listOf(textbook), state.materialsBySubject[1])
        assertEquals(listOf(textbook to math), state.recentMaterials)
        assertEquals(english, state.selectedSubject)
        assertEquals(workbook, state.selectedMaterial)
        assertEquals(TimerMode.TIMER, state.timerMode)
        assertEquals(15, state.countdownMinutes)
        assertEquals(LandscapeTimerDisplayPreset.CLOCK_ONLY, state.landscapeTimerDisplayPreset)
        assertTrue(state.isServiceBound)
        verify(exactly = 1) { timerServiceManager.bind() }
    }

    @Test
    fun `startTimer requires subject and exposes error without calling service`() = runTest {
        stubDefaults()
        val viewModel = createViewModel()
        advance()

        viewModel.startTimer()

        assertEquals("科目を選択してください", viewModel.uiState.value.error)
        verify(exactly = 0) { timerServiceManager.startTimer(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `startTimer supports subject only timer mode with countdown target`() = runTest {
        val math = subject(1, "Math")
        stubDefaults(subjects = listOf(math), preferences = AppPreferences(focusModePromptOnTimerStart = false))
        val viewModel = createViewModel()
        advance()

        viewModel.selectSubject(math)
        viewModel.setTimerMode(TimerMode.TIMER)
        viewModel.setCountdownMinutes(15)
        viewModel.startTimer()

        verify {
            timerServiceManager.startTimer(
                subjectId = 1,
                subjectSyncId = "subject-1",
                materialId = null,
                materialSyncId = null,
                mode = TimerMode.TIMER,
                targetDurationMillis = 15 * 60_000L
            )
        }
    }

    @Test
    fun `startTimer opens dnd settings when focus mode and timer restriction are enabled`() = runTest {
        val math = subject(1, "Math")
        stubDefaults(
            subjects = listOf(math),
            preferences = AppPreferences(
                focusModeEnabled = true,
                focusModePromptOnTimerStart = true
            )
        )
        val viewModel = createViewModel()
        advance()

        viewModel.selectSubject(math)
        val dndEvent = async { viewModel.openDndSettings.first() }
        viewModel.startTimer()
        advance()

        dndEvent.await()
    }

    @Test
    fun `startTimer does not open dnd settings when focus mode master is disabled`() = runTest {
        val math = subject(1, "Math")
        stubDefaults(
            subjects = listOf(math),
            preferences = AppPreferences(
                focusModeEnabled = false,
                focusModePromptOnTimerStart = true
            )
        )
        val viewModel = createViewModel()
        advance()
        val events = mutableListOf<Unit>()
        val collector = launch {
            viewModel.openDndSettings.collect { events.add(Unit) }
        }

        viewModel.selectSubject(math)
        viewModel.startTimer()
        advance()

        assertEquals(0, events.size)
        collector.cancel()
    }

    @Test
    fun `running timer blocks mode and countdown changes`() = runTest {
        stubDefaults()
        val viewModel = createViewModel()
        advance()
        isRunningFlow.value = true
        advance()

        viewModel.setTimerMode(TimerMode.TIMER)
        assertEquals(TimerMode.STOPWATCH, viewModel.uiState.value.timerMode)
        assertEquals("実行中はタイマー種別を変更できません", viewModel.uiState.value.error)

        viewModel.clearError()
        viewModel.setCountdownMinutes(10)
        assertEquals(25, viewModel.uiState.value.countdownMinutes)
        assertEquals("実行中は時間を変更できません", viewModel.uiState.value.error)
    }

    @Test
    fun `service flows update timer state`() = runTest {
        stubDefaults()
        val viewModel = createViewModel()
        advance()

        elapsedTimeFlow.value = 30_000
        remainingTimeFlow.value = 90_000
        isRunningFlow.value = true
        isBoundFlow.value = true
        advance()

        assertEquals(30_000L, viewModel.uiState.value.elapsedTime)
        assertEquals(90_000L, viewModel.uiState.value.remainingTime)
        assertTrue(viewModel.uiState.value.isRunning)
        assertTrue(viewModel.uiState.value.isServiceBound)
    }

    @Test
    fun `stopTimer creates pending evaluation and save persists enriched session`() = runTest {
        val math = subject(1, "Math")
        val textbook = material(10, "Textbook", 1)
        val captured = slot<StudySession>()
        stubDefaults(subjects = listOf(math), materials = listOf(textbook))
        every { timerServiceManager.stopTimer() } returns TimerStopResult(
            elapsed = 60_000,
            materialId = 10,
            intervals = listOf(StudySessionInterval(1_000, 61_000)),
            sessionType = StudySessionType.STOPWATCH
        )
        coEvery { saveStudySessionUseCase(capture(captured)) } returns Result.Success(42)
        val viewModel = createViewModel()
        advance()

        viewModel.selectMaterial(textbook, math)
        viewModel.stopTimer()
        advance()

        assertNotNull(viewModel.uiState.value.pendingSessionEvaluation)

        viewModel.savePendingSessionEvaluation(
            rating = 4,
            note = "  good focus  ",
            problemRecords = listOf(ProblemSessionRecord(3, ProblemResult.WRONG)),
            problemStart = null,
            problemEnd = null,
            wrongProblemCount = null
        )
        advance()

        val saved = captured.captured
        assertEquals(1L, saved.subjectId)
        assertEquals(10L, saved.materialId)
        assertEquals(60_000L, saved.duration)
        assertEquals(4, saved.rating)
        assertEquals("  good focus  ", saved.note)
        assertEquals(3, saved.problemStart)
        assertEquals(3, saved.problemEnd)
        assertEquals(1, saved.wrongProblemCount)
        assertEquals(listOf("3"), saved.problemRecords.map { it.stableKey })
        assertNull(viewModel.uiState.value.pendingSessionEvaluation)
        assertEquals(0L, viewModel.uiState.value.elapsedTime)
    }

    @Test
    fun `cancelPendingSessionEvaluation saves original pending session without rating`() = runTest {
        val math = subject(1, "Math")
        val captured = slot<StudySession>()
        stubDefaults(subjects = listOf(math))
        every { timerServiceManager.stopTimer() } returns TimerStopResult(
            elapsed = 30_000,
            materialId = null,
            intervals = emptyList(),
            sessionType = StudySessionType.STOPWATCH
        )
        coEvery { saveStudySessionUseCase(capture(captured)) } returns Result.Success(1)
        val viewModel = createViewModel()
        advance()

        viewModel.selectSubject(math)
        viewModel.stopTimer()
        advance()
        viewModel.cancelPendingSessionEvaluation()
        advance()

        assertNull(captured.captured.rating)
        assertNull(captured.captured.note)
        assertNull(viewModel.uiState.value.pendingSessionEvaluation)
    }

    @Test
    fun `problem count clamps records and toggle cycles tile state`() = runTest {
        stubDefaults()
        val viewModel = createViewModel()
        advance()

        viewModel.setProblemCount(250)
        assertEquals(200, viewModel.uiState.value.problemCount)
        assertEquals(200, viewModel.uiState.value.problemStates.size)

        viewModel.toggleProblemState(3)
        assertEquals(ProblemTileState.CORRECT, viewModel.uiState.value.problemStates[3])
        viewModel.toggleProblemState(3)
        assertEquals(ProblemTileState.WRONG, viewModel.uiState.value.problemStates[3])
        viewModel.toggleProblemState(3)
        assertEquals(ProblemTileState.UNTOUCHED, viewModel.uiState.value.problemStates[3])

        viewModel.setProblemCount(2)
        assertEquals(2, viewModel.uiState.value.problemCount)
        assertFalse(viewModel.uiState.value.problemStates.containsKey(3))
    }

    @Test
    fun `saveManualEntry validates time range before use case call`() = runTest {
        stubDefaults()
        val viewModel = createViewModel()
        advance()

        viewModel.saveManualEntry(subjectId = 1, materialId = null, startTime = 2_000, endTime = 1_000)
        advance()

        assertEquals("終了時刻は開始時刻より後にしてください", viewModel.uiState.value.error)
        coVerify(exactly = 0) {
            saveStudySessionUseCase(
                subjectId = any<Long>(),
                materialId = any(),
                duration = any<Long>(),
                intervals = any(),
                sessionType = any()
            )
        }
    }

    private fun createViewModel(): TimerViewModel = TimerViewModel(
        subjectRepository = subjectRepository,
        materialRepository = materialRepository,
        saveStudySessionUseCase = saveStudySessionUseCase,
        getRecentMaterialsUseCase = getRecentMaterialsUseCase,
        timerServiceManager = timerServiceManager,
        appPreferencesRepository = appPreferencesRepository
    )

    private fun stubDefaults(
        subjects: List<Subject> = emptyList(),
        materials: List<Material> = emptyList(),
        recent: List<Pair<Material, Subject>> = emptyList(),
        preferences: AppPreferences = AppPreferences()
    ) {
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(subjects))
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(materials))
        every { getRecentMaterialsUseCase() } returns flowOf(recent)
        every { appPreferencesRepository.observePreferences() } returns flowOf(preferences)
        every { appPreferencesRepository.loadPreferences() } returns preferences
        every { timerServiceManager.elapsedTime } returns elapsedTimeFlow
        every { timerServiceManager.remainingTime } returns remainingTimeFlow
        every { timerServiceManager.isRunning } returns isRunningFlow
        every { timerServiceManager.isBound } returns isBoundFlow
        every { timerServiceManager.currentSubjectId } returns currentSubjectIdFlow
        every { timerServiceManager.currentSubjectSyncId } returns currentSubjectSyncIdFlow
        every { timerServiceManager.currentMaterialId } returns currentMaterialIdFlow
        every { timerServiceManager.currentMaterialSyncId } returns currentMaterialSyncIdFlow
        every { timerServiceManager.currentMode } returns currentModeFlow
        every { timerServiceManager.currentTargetDurationMillis } returns currentTargetDurationMillisFlow
        every { timerServiceManager.bind() } just runs
        every { timerServiceManager.unbind() } just runs
    }

    private fun advance() {
        mainDispatcherRule.dispatcher.scheduler.advanceUntilIdle()
    }

    private fun subject(id: Long, name: String) = Subject(
        id = id,
        syncId = "subject-$id",
        name = name,
        color = id.toInt()
    )

    private fun material(id: Long, name: String, subjectId: Long) = Material(
        id = id,
        syncId = "material-$id",
        name = name,
        subjectId = subjectId,
        subjectSyncId = "subject-$subjectId"
    )
}
