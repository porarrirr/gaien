package com.studyapp.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.usecase.GetHomeDataUseCase
import com.studyapp.domain.usecase.HomeData
import com.studyapp.domain.usecase.TodaySession
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val todayStudyMinutes: Long = 0,
    val todaySessions: List<TodaySession> = emptyList(),
    val weeklyGoal: Goal? = null,
    val weeklyStudyMinutes: Long = 0,
    val upcomingExams: List<Exam> = emptyList(),
    val ankiStats: AnkiTodayStats = AnkiTodayStats(),
    val isRefreshingAnkiStats: Boolean = true
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getHomeDataUseCase: GetHomeDataUseCase,
    private val ankiRepository: AnkiRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    private var ankiRefreshJob: Job? = null
    
    init {
        observeAnkiStats()
        loadData()
        refreshAnkiStats()
    }
    
    private fun loadData() {
        getHomeDataUseCase()
            .onEach { data: HomeData ->
                _uiState.update { state ->
                    state.copy(
                        isLoading = false,
                        error = null,
                        todayStudyMinutes = data.todayStudyMinutes,
                        todaySessions = data.todaySessions,
                        weeklyGoal = data.weeklyGoal,
                        weeklyStudyMinutes = data.weeklyStudyMinutes,
                        upcomingExams = data.upcomingExams
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
    }

    private fun observeAnkiStats() {
        ankiRepository.observeTodayStats()
            .onEach { stats ->
                _uiState.update { state ->
                    state.copy(
                        ankiStats = stats,
                        isRefreshingAnkiStats = false
                    )
                }
            }
            .launchIn(viewModelScope)
    }
    
    fun retry() {
        _uiState.update { it.copy(isLoading = true, error = null) }
        loadData()
        refreshAnkiStats()
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun refreshAnkiStats() {
        if (ankiRefreshJob?.isActive == true) {
            return
        }
        ankiRefreshJob = viewModelScope.launch {
            _uiState.update { it.copy(isRefreshingAnkiStats = true) }
            try {
                ankiRepository.refreshTodayStats()
            } finally {
                _uiState.update { it.copy(isRefreshingAnkiStats = false) }
            }
        }
    }
}
