package com.studyapp.presentation.timer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.LandscapeTimerDisplayPreset
import com.studyapp.domain.model.Material
import com.studyapp.domain.repository.AppPreferencesRepository
import com.studyapp.domain.model.PendingSessionEvaluation
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.GetRecentMaterialsUseCase
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.domain.usecase.TimerServiceManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class ProblemTileState { UNTOUCHED, CORRECT, WRONG }

data class TimerUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val isRunning: Boolean = false,
    val elapsedTime: Long = 0L,
    val remainingTime: Long = 0L,
    val timerMode: TimerMode = TimerMode.STOPWATCH,
    val countdownMinutes: Int = 25,
    val selectedMaterial: Material? = null,
    val selectedSubject: Subject? = null,
    val subjects: List<Subject> = emptyList(),
    val materialsBySubject: Map<Long, List<Material>> = emptyMap(),
    val recentMaterials: List<Pair<Material, Subject>> = emptyList(),
    val isServiceBound: Boolean = false,
    val pendingSessionEvaluation: PendingSessionEvaluation? = null,
    val problemCount: Int = 0,
    val problemStates: Map<Int, ProblemTileState> = emptyMap(),
    val landscapeTimerDisplayPreset: LandscapeTimerDisplayPreset = LandscapeTimerDisplayPreset.PROBLEM_PROGRESS
)

@HiltViewModel
class TimerViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository,
    private val saveStudySessionUseCase: SaveStudySessionUseCase,
    private val getRecentMaterialsUseCase: GetRecentMaterialsUseCase,
    private val timerServiceManager: TimerServiceManager,
    private val appPreferencesRepository: AppPreferencesRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(TimerUiState())
    val uiState: StateFlow<TimerUiState> = _uiState.asStateFlow()
    private val _openDndSettings = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val openDndSettings: SharedFlow<Unit> = _openDndSettings.asSharedFlow()
    
    init {
        loadData()
        bindToService()
        appPreferencesRepository.observePreferences()
            .onEach { preferences ->
                _uiState.update {
                    it.copy(landscapeTimerDisplayPreset = preferences.landscapeTimerDisplayPreset)
                }
            }
            .launchIn(viewModelScope)
    }
    
    private fun loadData() {
        val selectionBase = combine(
            timerServiceManager.currentSubjectId,
            timerServiceManager.currentSubjectSyncId,
            timerServiceManager.currentMaterialId,
            timerServiceManager.currentMaterialSyncId
        ) { currentSubjectId, currentSubjectSyncId, currentMaterialId, currentMaterialSyncId ->
            TimerSelection(
                currentSubjectId = currentSubjectId,
                currentSubjectSyncId = currentSubjectSyncId,
                currentMaterialId = currentMaterialId,
                currentMaterialSyncId = currentMaterialSyncId,
                currentMode = TimerMode.STOPWATCH,
                currentTargetDurationMillis = null
            )
        }
        val timerSelection = combine(
            selectionBase,
            timerServiceManager.currentMode,
            timerServiceManager.currentTargetDurationMillis
        ) { selection, currentMode, currentTargetDurationMillis ->
            selection.copy(
                currentMode = currentMode,
                currentTargetDurationMillis = currentTargetDurationMillis
            )
        }

        combine(
            subjectRepository.getAllSubjects(),
            materialRepository.getAllMaterials(),
            getRecentMaterialsUseCase(),
            timerSelection
        ) { subjectsResult, materialsResult, recentMaterials, selection ->
            TimerDataState(
                subjects = subjectsResult.getOrNull() ?: emptyList(),
                materials = materialsResult.getOrNull() ?: emptyList(),
                recentMaterials = recentMaterials,
                currentSubjectId = selection.currentSubjectId,
                currentSubjectSyncId = selection.currentSubjectSyncId,
                currentMaterialId = selection.currentMaterialId,
                currentMaterialSyncId = selection.currentMaterialSyncId,
                currentMode = selection.currentMode,
                currentTargetDurationMillis = selection.currentTargetDurationMillis
            )
        }
        .onEach { data ->
            val bySubject = data.materials.groupBy { it.subjectId }
            _uiState.update { state ->
                val selectedSubject = when (val currentSubjectId = data.currentSubjectId) {
                    null -> data.currentSubjectSyncId?.let { syncId ->
                        data.subjects.find { it.syncId == syncId }
                    } ?: state.selectedSubject?.let { selected ->
                        data.subjects.find { it.syncId == selected.syncId } ?: data.subjects.find { it.id == selected.id }
                    }
                    else -> data.subjects.find { it.id == currentSubjectId }
                        ?: data.currentSubjectSyncId?.let { syncId -> data.subjects.find { it.syncId == syncId } }
                }
                val selectedMaterial = when (val currentMaterialId = data.currentMaterialId) {
                    null -> data.currentMaterialSyncId?.let { syncId ->
                        data.materials.find { it.syncId == syncId }
                    } ?: state.selectedMaterial?.let { selected ->
                        data.materials.find { it.syncId == selected.syncId } ?: data.materials.find { it.id == selected.id }
                    }
                    else -> data.materials.find { it.id == currentMaterialId }
                        ?: data.currentMaterialSyncId?.let { syncId -> data.materials.find { it.syncId == syncId } }
                }?.takeIf { material ->
                    selectedSubject == null ||
                        material.subjectId == selectedSubject.id ||
                        material.subjectSyncId == selectedSubject.syncId
                }

                state.copy(
                    isLoading = false,
                    error = null,
                    subjects = data.subjects,
                    materialsBySubject = bySubject,
                    recentMaterials = data.recentMaterials,
                    timerMode = data.currentMode,
                    countdownMinutes = ((data.currentTargetDurationMillis ?: (state.countdownMinutes * 60_000L)) / 60_000L).toInt()
                        .coerceAtLeast(1),
                    selectedSubject = selectedSubject,
                    selectedMaterial = selectedMaterial
                )
            }
        }
        .catch { e ->
            _uiState.update { state ->
                state.copy(
                    isLoading = false,
                    error = e.message ?: "データの読み込みに失敗しました"
                )
            }
        }
        .launchIn(viewModelScope)
        
        timerServiceManager.elapsedTime
            .onEach { time ->
                _uiState.update { it.copy(elapsedTime = time) }
            }
            .launchIn(viewModelScope)
        
        timerServiceManager.isRunning
            .onEach { running ->
                _uiState.update { it.copy(isRunning = running) }
            }
            .launchIn(viewModelScope)

        timerServiceManager.remainingTime
            .onEach { remaining ->
                _uiState.update { it.copy(remainingTime = remaining) }
            }
            .launchIn(viewModelScope)
        
        timerServiceManager.isBound
            .onEach { bound ->
                _uiState.update { it.copy(isServiceBound = bound) }
            }
            .launchIn(viewModelScope)
    }
    
    private fun bindToService() {
        timerServiceManager.bind()
    }
    
    override fun onCleared() {
        super.onCleared()
        timerServiceManager.unbind()
    }
    
    fun selectMaterial(material: Material, subject: Subject) {
        _uiState.update { state ->
            state.copy(
                selectedMaterial = material,
                selectedSubject = subject
            )
        }
    }

    fun selectSubject(subject: Subject) {
        _uiState.update { state ->
            state.copy(
                selectedSubject = subject,
                selectedMaterial = state.selectedMaterial?.takeIf { material ->
                    material.subjectId == subject.id || material.subjectSyncId == subject.syncId
                }
            )
        }
    }

    fun selectTimerTarget(subject: Subject, material: Material?) {
        _uiState.update { state ->
            state.copy(
                selectedSubject = subject,
                selectedMaterial = material?.takeIf {
                    it.subjectId == subject.id || it.subjectSyncId == subject.syncId
                },
                problemStates = if (state.selectedMaterial?.id == material?.id) state.problemStates else emptyMap(),
                problemCount = if (state.selectedMaterial?.id == material?.id) {
                    state.problemCount
                } else {
                    (material?.effectiveTotalProblems ?: 0).coerceIn(0, 200)
                }
            )
        }
    }
    
    fun startTimer() {
        val state = _uiState.value
        if (state.isRunning) return
        
        val subject = state.selectedSubject
        if (subject == null) {
            _uiState.update { it.copy(error = "科目を選択してください") }
            return
        }
        
        timerServiceManager.startTimer(
            subjectId = subject.id,
            subjectSyncId = subject.syncId,
            materialId = state.selectedMaterial?.id,
            materialSyncId = state.selectedMaterial?.syncId,
            mode = state.timerMode,
            targetDurationMillis = if (state.timerMode == TimerMode.TIMER) {
                state.countdownMinutes * 60_000L
            } else {
                null
            }
        )
        val appPreferences = appPreferencesRepository.loadPreferences()
        if (appPreferences.focusModeEnabled && appPreferences.focusModePromptOnTimerStart) {
            viewModelScope.launch { _openDndSettings.emit(Unit) }
        }
    }
    
    fun pauseTimer() {
        timerServiceManager.pauseTimer()
    }
    
    fun stopTimer() {
        val stopResult = timerServiceManager.stopTimer()
        val subject = _uiState.value.selectedSubject
        val material = _uiState.value.selectedMaterial
        
        if (stopResult.elapsed > 0 && subject != null) {
            val now = System.currentTimeMillis()
            val session = StudySession(
                id = 0,
                syncId = java.util.UUID.randomUUID().toString().lowercase(),
                materialId = material?.id,
                materialSyncId = material?.syncId,
                materialName = material?.name ?: "",
                subjectId = subject.id,
                subjectSyncId = subject.syncId,
                subjectName = subject.name,
                sessionType = stopResult.sessionType,
                startTime = now - stopResult.elapsed,
                endTime = now,
                intervals = stopResult.intervals,
                rating = null,
                note = null,
                problemStart = null,
                problemEnd = null,
                wrongProblemCount = null,
                problemRecords = emptyList(),
                createdAt = now,
                updatedAt = now,
                deletedAt = null,
                lastSyncedAt = null
            )
            _uiState.update { state ->
                state.copy(
                    isRunning = false,
                    elapsedTime = 0L,
                    remainingTime = 0L,
                    pendingSessionEvaluation = PendingSessionEvaluation(session = session)
                )
            }
        } else {
            _uiState.update { state ->
                state.copy(
                    isRunning = false,
                    elapsedTime = 0L,
                    remainingTime = 0L
                )
            }
        }
    }

    fun savePendingSessionEvaluation(
        rating: Int,
        note: String?,
        problemRecords: List<ProblemSessionRecord>,
        problemStart: Int?,
        problemEnd: Int?,
        wrongProblemCount: Int?
    ) {
        val pending = _uiState.value.pendingSessionEvaluation ?: return
        val sortedProblemRecords = problemRecords.sortedWith(
            compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" }
        )
        val session = pending.session.copy(
            rating = rating,
            note = note?.takeIf { it.isNotBlank() },
            problemRecords = sortedProblemRecords,
            problemStart = sortedProblemRecords.firstOrNull()?.number ?: problemStart,
            problemEnd = sortedProblemRecords.lastOrNull()?.number ?: problemEnd,
            wrongProblemCount = if (sortedProblemRecords.isEmpty()) {
                wrongProblemCount
            } else {
                sortedProblemRecords.count { it.result == com.studyapp.domain.model.ProblemResult.WRONG }
            },
            updatedAt = System.currentTimeMillis()
        )
        _uiState.update { it.copy(pendingSessionEvaluation = null) }
        viewModelScope.launch {
            saveStudySessionUseCase(session)
                .onError { error ->
                    _uiState.update { state ->
                        state.copy(error = error.message ?: "学習記録の保存に失敗しました")
                    }
                }
        }
    }

    fun cancelPendingSessionEvaluation() {
        val pending = _uiState.value.pendingSessionEvaluation ?: return
        _uiState.update { it.copy(pendingSessionEvaluation = null) }
        viewModelScope.launch {
            saveStudySessionUseCase(pending.session)
                .onError { error ->
                    _uiState.update { state ->
                        state.copy(error = error.message ?: "学習記録の保存に失敗しました")
                    }
                }
        }
    }
    
    fun saveManualEntry(subjectId: Long, materialId: Long?, startTime: Long, endTime: Long) {
        val duration = endTime - startTime
        if (duration <= 0L) {
            _uiState.update { it.copy(error = "終了時刻は開始時刻より後にしてください") }
            return
        }
        saveSession(
            subjectId = subjectId,
            materialId = materialId,
            duration = duration,
            intervals = listOf(
                StudySessionInterval(
                    startTime = startTime,
                    endTime = endTime
                )
            ),
            sessionType = StudySessionType.MANUAL
        )
    }

    fun setTimerMode(mode: TimerMode) {
        if (_uiState.value.isRunning) {
            _uiState.update { it.copy(error = "実行中はタイマー種別を変更できません") }
            return
        }
        _uiState.update { it.copy(timerMode = mode) }
    }

    fun setCountdownMinutes(minutes: Int) {
        if (_uiState.value.isRunning) {
            _uiState.update { it.copy(error = "実行中は時間を変更できません") }
            return
        }
        _uiState.update { it.copy(countdownMinutes = minutes.coerceAtLeast(1)) }
    }
    
    private fun saveSession(
        subjectId: Long,
        materialId: Long?,
        duration: Long,
        intervals: List<com.studyapp.domain.model.StudySessionInterval> = emptyList(),
        sessionType: StudySessionType = StudySessionType.STOPWATCH
    ) {
        viewModelScope.launch {
            saveStudySessionUseCase(
                subjectId = subjectId,
                materialId = materialId,
                duration = duration,
                intervals = intervals,
                sessionType = sessionType
            )
                .onError { error ->
                    _uiState.update { state ->
                        state.copy(error = error.message ?: "学習記録の保存に失敗しました")
                    }
                }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun setProblemCount(count: Int) {
        val newCount = count.coerceIn(0, 200)
        _uiState.update { state ->
            val newStates = (1..newCount).associateWith { num ->
                state.problemStates[num] ?: ProblemTileState.UNTOUCHED
            }
            state.copy(problemCount = newCount, problemStates = newStates)
        }
    }

    fun toggleProblemState(number: Int) {
        _uiState.update { state ->
            val current = state.problemStates[number] ?: ProblemTileState.UNTOUCHED
            val next = when (current) {
                ProblemTileState.UNTOUCHED -> ProblemTileState.CORRECT
                ProblemTileState.CORRECT -> ProblemTileState.WRONG
                ProblemTileState.WRONG -> ProblemTileState.UNTOUCHED
            }
            state.copy(problemStates = state.problemStates + (number to next))
        }
    }

    private data class TimerDataState(
        val subjects: List<Subject>,
        val materials: List<Material>,
        val recentMaterials: List<Pair<Material, Subject>>,
        val currentSubjectId: Long?,
        val currentSubjectSyncId: String?,
        val currentMaterialId: Long?,
        val currentMaterialSyncId: String?,
        val currentMode: TimerMode,
        val currentTargetDurationMillis: Long?
    )

    private data class TimerSelection(
        val currentSubjectId: Long?,
        val currentSubjectSyncId: String?,
        val currentMaterialId: Long?,
        val currentMaterialSyncId: String?,
        val currentMode: TimerMode,
        val currentTargetDurationMillis: Long?
    )
}
