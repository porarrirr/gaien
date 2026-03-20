package com.studyapp.presentation.goals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Goal
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.usecase.ManageGoalsUseCase
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class GoalsUiState(
    val dailyGoal: Goal? = null,
    val weeklyGoal: Goal? = null,
    val todayMinutes: Long = 0,
    val weekMinutes: Long = 0,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class GoalsViewModel @Inject constructor(
    private val manageGoalsUseCase: ManageGoalsUseCase,
    private val studySessionRepository: StudySessionRepository,
    private val clock: Clock
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(GoalsUiState())
    val uiState: StateFlow<GoalsUiState> = _uiState.asStateFlow()
    
    init {
        observeData()
    }
    
    private fun observeData() {
        viewModelScope.launch {
            combine(
                manageGoalsUseCase.getActiveDailyGoal(),
                manageGoalsUseCase.getActiveWeeklyGoal()
            ) { dailyGoal, weeklyGoal ->
                Pair(dailyGoal, weeklyGoal)
            }.collect { (dailyGoal, weeklyGoal) ->
                _uiState.update { state ->
                    state.copy(
                        dailyGoal = dailyGoal,
                        weeklyGoal = weeklyGoal,
                        isLoading = false
                    )
                }
            }
        }
        
        val todayStart = clock.startOfToday()
        studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + DAY_MS)
            .map { result -> result.getOrNull() ?: emptyList() }
            .map { sessions -> sessions.sumOf { it.duration / 60000 } }
            .onEach { todayMinutes ->
                _uiState.update { state -> state.copy(todayMinutes = todayMinutes) }
            }
            .catch { e ->
                _uiState.update { state -> state.copy(error = e.message ?: "データの読み込みに失敗しました") }
            }
            .launchIn(viewModelScope)
        
        val weekStart = clock.startOfWeek()
        studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + WEEK_MS)
            .map { result -> result.getOrNull() ?: emptyList() }
            .map { sessions -> sessions.sumOf { it.duration / 60000 } }
            .onEach { weekMinutes ->
                _uiState.update { state -> state.copy(weekMinutes = weekMinutes) }
            }
            .catch { e ->
                _uiState.update { state -> state.copy(error = e.message ?: "データの読み込みに失敗しました") }
            }
            .launchIn(viewModelScope)
    }
    
    fun updateDailyGoal(minutes: Int) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = manageGoalsUseCase.updateDailyGoal(minutes.toLong())) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(isLoading = false, error = result.message ?: result.exception.message) }
                }
            }
        }
    }
    
    fun updateWeeklyGoal(minutes: Int) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            
            when (val result = manageGoalsUseCase.updateWeeklyGoal(minutes.toLong())) {
                is Result.Success -> {
                    _uiState.update { it.copy(isLoading = false, error = null) }
                }
                is Result.Error -> {
                    _uiState.update { it.copy(isLoading = false, error = result.message ?: result.exception.message) }
                }
            }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
    
    companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val WEEK_MS = 7 * DAY_MS
    }
}