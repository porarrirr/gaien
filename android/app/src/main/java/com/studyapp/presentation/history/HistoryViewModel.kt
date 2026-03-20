package com.studyapp.presentation.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
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
    val filterSubjectId: Long? = null,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val subjectRepository: SubjectRepository
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
                filterSubjectIdState
            ) { sessionsResult, subjectsResult, filterId ->
                Triple(sessionsResult, subjectsResult, filterId)
            }.collect { (sessionsResult, subjectsResult, filterId) ->
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
                
                val filteredSessions = filterId?.let { id ->
                    sessions.filter { it.subjectId == id }
                } ?: sessions
                
                _uiState.update { state ->
                    state.copy(
                        sessions = filteredSessions,
                        subjects = subjects,
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