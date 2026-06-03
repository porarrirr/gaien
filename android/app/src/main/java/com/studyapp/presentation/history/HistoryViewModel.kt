package com.studyapp.presentation.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HistoryUiState(
    val sessions: List<StudySession> = emptyList(),
    val subjects: List<Subject> = emptyList(),
    val materials: List<Material> = emptyList(),
    val filterSubjectId: Long? = null,
    val isLoading: Boolean = true,
    val error: String? = null
)

private data class HistorySources(
    val sessionsResult: Result<List<StudySession>>,
    val subjectsResult: Result<List<Subject>>,
    val materialsResult: Result<List<Material>>,
    val filterSubjectId: Long?
)

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HistoryUiState())
    val uiState = _uiState.asStateFlow()
    
    private val filterSubjectIdState = MutableStateFlow<Long?>(null)
    
    init {
        observeData()
    }
    
    private fun observeData() {
        viewModelScope.launch {
            combine(
                studySessionRepository.getAllSessions(),
                subjectRepository.getAllSubjects(),
                materialRepository.getAllMaterials(),
                filterSubjectIdState
            ) { sessionsResult, subjectsResult, materialsResult, filterId ->
                HistorySources(sessionsResult, subjectsResult, materialsResult, filterId)
            }.collect { sources ->
                val sessionsResult = sources.sessionsResult
                val subjectsResult = sources.subjectsResult
                val materialsResult = sources.materialsResult
                val filterId = sources.filterSubjectId
                val sessions = when (sessionsResult) {
                    is Result.Success -> sessionsResult.data
                    is Result.Error -> {
                        _uiState.update { it.copy(
                            isLoading = false,
                            error = sessionsResult.message ?: sessionsResult.exception.message
                        )}
                        return@collect
                    }
                }
                
                val subjects = when (subjectsResult) {
                    is Result.Success -> subjectsResult.data
                    is Result.Error -> {
                        _uiState.update { it.copy(
                            isLoading = false,
                            error = subjectsResult.message ?: subjectsResult.exception.message
                        )}
                        return@collect
                    }
                }

                val materials = when (materialsResult) {
                    is Result.Success -> materialsResult.data
                    is Result.Error -> {
                        _uiState.update { it.copy(
                            isLoading = false,
                            error = materialsResult.message ?: materialsResult.exception.message
                        )}
                        return@collect
                    }
                }
                
                val filteredSessions = filterId?.let { id ->
                    sessions.filter { it.subjectId == id }
                } ?: sessions
                
                _uiState.update { state ->
                    state.copy(
                        sessions = filteredSessions,
                        subjects = subjects,
                        materials = materials,
                        filterSubjectId = filterId,
                        isLoading = false,
                        error = null
                    )
                }
            }
        }
    }
    
    fun setFilter(subjectId: Long?) {
        filterSubjectIdState.value = subjectId
    }
    
    fun updateSession(session: StudySession) {
        viewModelScope.launch {
            when (val result = studySessionRepository.updateSession(session)) {
                is Result.Error -> {
                    _uiState.update { it.copy(error = result.message ?: result.exception.message) }
                }
                is Result.Success -> {}
            }
        }
    }
    
    fun deleteSession(session: StudySession) {
        viewModelScope.launch {
            when (val result = studySessionRepository.deleteSession(session)) {
                is Result.Error -> {
                    _uiState.update { it.copy(error = result.message ?: result.exception.message) }
                }
                is Result.Success -> {}
            }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
