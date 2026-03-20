package com.studyapp.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.usecase.GetHomeDataUseCase
import com.studyapp.domain.usecase.HomeData
import com.studyapp.domain.usecase.TodaySession
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import javax.inject.Inject

data class HomeUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val todayStudyMinutes: Long = 0,
    val todaySessions: List<TodaySession> = emptyList(),
    val weeklyGoal: Goal? = null,
    val weeklyStudyMinutes: Long = 0,
    val upcomingExams: List<Exam> = emptyList()
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getHomeDataUseCase: GetHomeDataUseCase
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
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
    
    fun retry() {
        _uiState.update { it.copy(isLoading = true, error = null) }
        loadData()
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}