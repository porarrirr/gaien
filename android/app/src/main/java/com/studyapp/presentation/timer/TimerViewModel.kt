package com.studyapp.presentation.timer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.usecase.GetRecentMaterialsUseCase
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.usecase.TimerServiceManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TimerUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val isRunning: Boolean = false,
    val elapsedTime: Long = 0L,
    val selectedMaterial: Material? = null,
    val selectedSubject: Subject? = null,
    val subjects: List<Subject> = emptyList(),
    val materialsBySubject: Map<Long, List<Material>> = emptyMap(),
    val recentMaterials: List<Pair<Material, Subject>> = emptyList(),
    val isServiceBound: Boolean = false
)

@HiltViewModel
class TimerViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository,
    private val saveStudySessionUseCase: SaveStudySessionUseCase,
    private val getRecentMaterialsUseCase: GetRecentMaterialsUseCase,
    private val timerServiceManager: TimerServiceManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(TimerUiState())
    val uiState: StateFlow<TimerUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
        bindToService()
    }
    
    private fun loadData() {
        val timerSelection = combine(
            timerServiceManager.currentSubjectId,
            timerServiceManager.currentSubjectSyncId,
            timerServiceManager.currentMaterialId,
            timerServiceManager.currentMaterialSyncId
        ) { currentSubjectId, currentSubjectSyncId, currentMaterialId, currentMaterialSyncId ->
            TimerSelection(
                currentSubjectId = currentSubjectId,
                currentSubjectSyncId = currentSubjectSyncId,
                currentMaterialId = currentMaterialId,
                currentMaterialSyncId = currentMaterialSyncId
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
                currentMaterialSyncId = selection.currentMaterialSyncId
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
            materialSyncId = state.selectedMaterial?.syncId
        )
    }
    
    fun pauseTimer() {
        timerServiceManager.pauseTimer()
    }
    
    fun stopTimer() {
        val stopResult = timerServiceManager.stopTimer()
        val subject = _uiState.value.selectedSubject
        val materialId = _uiState.value.selectedMaterial?.id
        
        if (stopResult.elapsed > 0 && subject != null) {
            saveSession(
                subjectId = subject.id,
                materialId = materialId,
                duration = stopResult.elapsed,
                intervals = stopResult.intervals
            )
        }
        
        _uiState.update { state ->
            state.copy(
                isRunning = false,
                elapsedTime = 0L
            )
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
            )
        )
    }
    
    private fun saveSession(
        subjectId: Long,
        materialId: Long?,
        duration: Long,
        intervals: List<com.studyapp.domain.model.StudySessionInterval> = emptyList()
    ) {
        viewModelScope.launch {
            saveStudySessionUseCase(
                subjectId = subjectId,
                materialId = materialId,
                duration = duration,
                intervals = intervals
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

    private data class TimerDataState(
        val subjects: List<Subject>,
        val materials: List<Material>,
        val recentMaterials: List<Pair<Material, Subject>>,
        val currentSubjectId: Long?,
        val currentSubjectSyncId: String?,
        val currentMaterialId: Long?,
        val currentMaterialSyncId: String?
    )

    private data class TimerSelection(
        val currentSubjectId: Long?,
        val currentSubjectSyncId: String?,
        val currentMaterialId: Long?,
        val currentMaterialSyncId: String?
    )
}
