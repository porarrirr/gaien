package com.studyapp.presentation.subjects

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
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

data class SubjectsUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val subjects: List<Subject> = emptyList(),
    val subjectStudyMinutes: Map<Long, Long> = emptyMap()
)

@HiltViewModel
class SubjectsViewModel @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val studySessionRepository: StudySessionRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(SubjectsUiState())
    val uiState: StateFlow<SubjectsUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
    }
    
    private fun loadData() {
        combine(
            subjectRepository.getAllSubjects(),
            studySessionRepository.getAllSessions()
        ) { subjectsResult, sessionsResult ->
            val subjects = subjectsResult.getOrNull() ?: emptyList()
            val sessions = sessionsResult.getOrNull() ?: emptyList()
            
            val minutesMap = sessions
                .groupBy { it.subjectId }
                .mapValues { (_, sessions) ->
                    sessions.sumOf { it.duration / 60000 }
                }
            
            SubjectsUiState(
                isLoading = false,
                error = null,
                subjects = subjects,
                subjectStudyMinutes = minutesMap
            )
        }
        .onEach { state ->
            _uiState.update { state }
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
    }
    
    fun addSubject(name: String, color: Int) {
        viewModelScope.launch {
            subjectRepository.insertSubject(
                Subject(
                    name = name,
                    color = color
                )
            ).onError { error ->
                _uiState.update { it.copy(error = error.message ?: "科目の追加に失敗しました") }
            }
        }
    }
    
    fun updateSubject(subject: Subject) {
        viewModelScope.launch {
            subjectRepository.updateSubject(subject)
                .onError { error ->
                    _uiState.update { it.copy(error = error.message ?: "科目の更新に失敗しました") }
                }
        }
    }
    
    fun deleteSubject(subject: Subject) {
        viewModelScope.launch {
            subjectRepository.deleteSubject(subject)
                .onError { error ->
                    _uiState.update { it.copy(error = error.message ?: "科目の削除に失敗しました") }
                }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}