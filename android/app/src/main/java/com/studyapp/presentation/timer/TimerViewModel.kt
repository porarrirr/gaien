package com.studyapp.presentation.timer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Material
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
        combine(
            subjectRepository.getAllSubjects(),
            materialRepository.getAllMaterials(),
            getRecentMaterialsUseCase()
        ) { subjectsResult, materialsResult, recentMaterials ->
            Triple(
                subjectsResult.getOrNull() ?: emptyList(),
                materialsResult.getOrNull() ?: emptyList(),
                recentMaterials
            )
        }
        .onEach { (subjects, materials, recentMaterials) ->
            val bySubject = materials.groupBy { it.subjectId }
            _uiState.update { state ->
                state.copy(
                    isLoading = false,
                    error = null,
                    subjects = subjects,
                    materialsBySubject = bySubject,
                    recentMaterials = recentMaterials
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
            materialId = state.selectedMaterial?.id
        )
    }
    
    fun pauseTimer() {
        timerServiceManager.pauseTimer()
    }
    
    fun stopTimer() {
        val (elapsed, materialId) = timerServiceManager.stopTimer()
        val subject = _uiState.value.selectedSubject
        
        if (elapsed > 0 && subject != null) {
            saveSession(
                subjectId = subject.id,
                materialId = materialId,
                duration = elapsed
            )
        }
        
        _uiState.update { state ->
            state.copy(
                isRunning = false,
                elapsedTime = 0L
            )
        }
    }
    
    fun saveManualEntry(subjectId: Long, materialId: Long?, durationMinutes: Long) {
        saveSession(
            subjectId = subjectId,
            materialId = materialId,
            duration = durationMinutes * 60000
        )
    }
    
    private fun saveSession(subjectId: Long, materialId: Long?, duration: Long) {
        viewModelScope.launch {
            saveStudySessionUseCase(subjectId, materialId, duration)
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
}