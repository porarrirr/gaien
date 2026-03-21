package com.studyapp.presentation.timer

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.GetRecentMaterialsUseCase
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.usecase.TimerServiceManager
import com.studyapp.domain.util.Result
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TimerViewModelTest {
    
    private val testDispatcher = StandardTestDispatcher()
    
    private lateinit var subjectRepository: SubjectRepository
    private lateinit var materialRepository: MaterialRepository
    private lateinit var saveStudySessionUseCase: SaveStudySessionUseCase
    private lateinit var getRecentMaterialsUseCase: GetRecentMaterialsUseCase
    private lateinit var timerServiceManager: TimerServiceManager
    private lateinit var viewModel: TimerViewModel
    
    private val elapsedTimeFlow = MutableStateFlow(0L)
    private val isRunningFlow = MutableStateFlow(false)
    private val isBoundFlow = MutableStateFlow(false)
    private val currentSubjectIdFlow = MutableStateFlow<Long?>(null)
    private val currentSubjectSyncIdFlow = MutableStateFlow<String?>(null)
    private val currentMaterialIdFlow = MutableStateFlow<Long?>(null)
    private val currentMaterialSyncIdFlow = MutableStateFlow<String?>(null)
    
    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        
        subjectRepository = mockk()
        materialRepository = mockk()
        saveStudySessionUseCase = mockk()
        getRecentMaterialsUseCase = mockk()
        timerServiceManager = mockk(relaxed = true)
        
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(emptyList()))
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(emptyList()))
        every { getRecentMaterialsUseCase() } returns flowOf(emptyList())
        
        every { timerServiceManager.elapsedTime } returns elapsedTimeFlow
        every { timerServiceManager.isRunning } returns isRunningFlow
        every { timerServiceManager.isBound } returns isBoundFlow
        every { timerServiceManager.currentSubjectId } returns currentSubjectIdFlow
        every { timerServiceManager.currentSubjectSyncId } returns currentSubjectSyncIdFlow
        every { timerServiceManager.currentMaterialId } returns currentMaterialIdFlow
        every { timerServiceManager.currentMaterialSyncId } returns currentMaterialSyncIdFlow
        every { timerServiceManager.bind() } just runs
        every { timerServiceManager.unbind() } just runs
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
    }
    
    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }
    
    @Test
    fun `initial state is loading`() = runTest {
        val state = viewModel.uiState.value
        assertTrue(state.isLoading)
        assertNull(state.error)
    }
    
    @Test
    fun `initial state is not running`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.uiState.value.isRunning)
    }
    
    @Test
    fun `initial state has zero elapsed time`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(0L, viewModel.uiState.value.elapsedTime)
    }
    
    @Test
    fun `initial state has empty subjects list`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.uiState.value.subjects.isEmpty())
    }
    
    @Test
    fun `loadData emits success state`() = runTest {
        val subjects = listOf(
            Subject(id = 1L, name = "Math", color = 0xFF0000.toInt()),
            Subject(id = 2L, name = "English", color = 0x00FF00.toInt())
        )
        val materials = listOf(
            Material(id = 1L, name = "Textbook", subjectId = 1L),
            Material(id = 2L, name = "Workbook", subjectId = 1L)
        )
        
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(subjects))
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(materials))
        every { getRecentMaterialsUseCase() } returns flowOf(emptyList())
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNull(state.error)
        assertEquals(2, state.subjects.size)
        assertEquals("Math", state.subjects.first().name)
        
        verify { subjectRepository.getAllSubjects() }
        verify { materialRepository.getAllMaterials() }
        verify { getRecentMaterialsUseCase() }
    }
    
    @Test
    fun `loadData emits error state on failure`() = runTest {
        val exception = RuntimeException("Database error")
        every { subjectRepository.getAllSubjects() } returns flow { throw exception }
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNotNull(state.error)
        assertEquals("Database error", state.error)
    }
    
    @Test
    fun `subjects are loaded from repository`() = runTest {
        val subjects = listOf(
            Subject(id = 1L, name = "Math", color = 0xFF0000.toInt()),
            Subject(id = 2L, name = "English", color = 0x00FF00.toInt())
        )
        
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(subjects))
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(2, viewModel.uiState.value.subjects.size)
        assertEquals("Math", viewModel.uiState.value.subjects.first().name)
    }
    
    @Test
    fun `selectMaterial updates selected material and subject`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        assertEquals(material, viewModel.uiState.value.selectedMaterial)
        assertEquals(subject, viewModel.uiState.value.selectedSubject)
    }
    
    @Test
    fun `materials are grouped by subject`() = runTest {
        val materials = listOf(
            Material(id = 1L, name = "Textbook 1", subjectId = 1L),
            Material(id = 2L, name = "Textbook 2", subjectId = 1L),
            Material(id = 3L, name = "Workbook", subjectId = 2L)
        )
        
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(materials))
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(2, viewModel.uiState.value.materialsBySubject[1L]?.size)
        assertEquals(1, viewModel.uiState.value.materialsBySubject[2L]?.size)
    }
    
    @Test
    fun `startTimer calls service manager with correct parameters`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        every { timerServiceManager.startTimer(1L, subject.syncId, 1L, material.syncId) } just runs
        
        viewModel.startTimer()
        
        verify {
            timerServiceManager.startTimer(
                subjectId = 1L,
                subjectSyncId = subject.syncId,
                materialId = 1L,
                materialSyncId = material.syncId
            )
        }
    }
    
    @Test
    fun `startTimer does nothing when already running`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        isRunningFlow.value = true
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.startTimer()
        
        verify(exactly = 0) { timerServiceManager.startTimer(any(), any(), any(), any()) }
    }
    
    @Test
    fun `startTimer does nothing when no subject selected`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.startTimer()
        
        verify(exactly = 0) { timerServiceManager.startTimer(any(), any(), any(), any()) }
    }
    
    @Test
    fun `pauseTimer calls service manager`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.pauseTimer()
        
        verify { timerServiceManager.pauseTimer() }
    }
    
    @Test
    fun `stopTimer saves session when elapsed time is positive`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        every { timerServiceManager.stopTimer() } returns Pair(60000L, 1L)
        coEvery { saveStudySessionUseCase(1L, 1L, 60000L) } returns Result.Success(1L)
        
        viewModel.stopTimer()
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify { saveStudySessionUseCase(subjectId = 1L, materialId = 1L, duration = 60000L) }
        assertFalse(viewModel.uiState.value.isRunning)
        assertEquals(0L, viewModel.uiState.value.elapsedTime)
    }
    
    @Test
    fun `stopTimer does not save session when elapsed time is zero`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        every { timerServiceManager.stopTimer() } returns Pair(0L, null)
        
        viewModel.stopTimer()
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify(exactly = 0) { saveStudySessionUseCase(any(), any(), any()) }
    }
    
    @Test
    fun `stopTimer does not save session when no subject selected`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        every { timerServiceManager.stopTimer() } returns Pair(60000L, null)
        
        viewModel.stopTimer()
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify(exactly = 0) { saveStudySessionUseCase(any(), any(), any()) }
    }
    
    @Test
    fun `stopTimer handles save error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        
        viewModel.selectMaterial(material, subject)
        
        every { timerServiceManager.stopTimer() } returns Pair(60000L, 1L)
        coEvery { saveStudySessionUseCase(1L, 1L, 60000L) } returns Result.Error(RuntimeException("Save failed"), "保存に失敗しました")
        
        viewModel.stopTimer()
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertNotNull(viewModel.uiState.value.error)
        assertEquals("保存に失敗しました", viewModel.uiState.value.error)
    }
    
    @Test
    fun `saveManualEntry calls saveStudySessionUseCase with correct duration`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        coEvery { saveStudySessionUseCase(1L, 2L, 60000L) } returns Result.Success(1L)
        
        viewModel.saveManualEntry(subjectId = 1L, materialId = 2L, durationMinutes = 1L)
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify { saveStudySessionUseCase(subjectId = 1L, materialId = 2L, duration = 60000L) }
    }
    
    @Test
    fun `saveManualEntry handles error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        coEvery { saveStudySessionUseCase(1L, null, 300000L) } returns Result.Error(RuntimeException("Error"), "保存エラー")
        
        viewModel.saveManualEntry(subjectId = 1L, materialId = null, durationMinutes = 5L)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertNotNull(viewModel.uiState.value.error)
    }
    
    @Test
    fun `elapsedTime updates from service manager`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        elapsedTimeFlow.value = 30000L
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(30000L, viewModel.uiState.value.elapsedTime)
        
        elapsedTimeFlow.value = 60000L
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals(60000L, viewModel.uiState.value.elapsedTime)
    }
    
    @Test
    fun `isRunning updates from service manager`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.uiState.value.isRunning)
        
        isRunningFlow.value = true
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.uiState.value.isRunning)
    }
    
    @Test
    fun `isServiceBound updates from service manager`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.uiState.value.isServiceBound)
        
        isBoundFlow.value = true
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.uiState.value.isServiceBound)
    }
    
    @Test
    fun `clearError removes error from state`() = runTest {
        val exception = RuntimeException("Test error")
        every { subjectRepository.getAllSubjects() } returns flow { throw exception }
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertNotNull(viewModel.uiState.value.error)
        
        viewModel.clearError()
        
        assertNull(viewModel.uiState.value.error)
    }
    
    @Test
    fun `recent materials are loaded from use case`() = runTest {
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 1L, name = "Textbook", subjectId = 1L)
        val recentMaterials = listOf(material to subject)
        
        every { getRecentMaterialsUseCase() } returns flowOf(recentMaterials)
        
        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.uiState.value
        assertEquals(1, state.recentMaterials.size)
        assertEquals("Textbook", state.recentMaterials.first().first.name)
        assertEquals("Math", state.recentMaterials.first().second.name)
    }

    @Test
    fun `active timer selection is restored from service manager state`() = runTest {
        val subject = Subject(id = 1L, name = "Math", color = 0xFF0000.toInt())
        val material = Material(id = 2L, name = "Workbook", subjectId = 1L)

        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(listOf(subject)))
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(listOf(material)))
        currentSubjectIdFlow.value = subject.id
        currentMaterialIdFlow.value = material.id

        viewModel = TimerViewModel(
            subjectRepository = subjectRepository,
            materialRepository = materialRepository,
            saveStudySessionUseCase = saveStudySessionUseCase,
            getRecentMaterialsUseCase = getRecentMaterialsUseCase,
            timerServiceManager = timerServiceManager
        )
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(subject, viewModel.uiState.value.selectedSubject)
        assertEquals(material, viewModel.uiState.value.selectedMaterial)
    }
    
    @Test
    fun `bindToService is called on init`() = runTest {
        verify { timerServiceManager.bind() }
    }
}
