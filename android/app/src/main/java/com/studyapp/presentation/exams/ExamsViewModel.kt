package com.studyapp.presentation.exams

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Exam
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.usecase.GetUpcomingExamsUseCase
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExamsUiState(
    val exams: List<Exam> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class ExamsViewModel @Inject constructor(
    private val getUpcomingExamsUseCase: GetUpcomingExamsUseCase,
    private val examRepository: ExamRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ExamsUiState())
    val uiState = _uiState.asStateFlow()
    
    init {
        loadExams()
    }
    
    private fun loadExams() {
        viewModelScope.launch {
            getUpcomingExamsUseCase()
                .collect { exams ->
                    _uiState.update { 
                        it.copy(
                            exams = exams,
                            isLoading = false,
                            error = null
                        )
                    }
                }
        }
    }
    
    fun addExam(name: String, date: java.time.LocalDate, note: String?) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            val exam = Exam(
                name = name,
                date = date,
                note = note
            )
            
            when (val result = examRepository.insertExam(exam)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun updateExam(exam: Exam) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = examRepository.updateExam(exam)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun deleteExam(exam: Exam) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = examRepository.deleteExam(exam)) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(
                        isLoading = false,
                        error = result.message ?: result.exception.message
                    )}
                }
            }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}