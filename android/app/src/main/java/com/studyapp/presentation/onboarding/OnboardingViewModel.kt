package com.studyapp.presentation.onboarding

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class OnboardingUiState {
    object Loading : OnboardingUiState()
    object ShowOnboarding : OnboardingUiState()
    object ShowMain : OnboardingUiState()
    data class Error(val message: String) : OnboardingUiState()
}

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val onboardingPreferences: OnboardingPreferences
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<OnboardingUiState>(OnboardingUiState.Loading)
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()
    private var onboardingStatusJob: Job? = null
    
    val pages: List<OnboardingPage> = listOf(
        OnboardingPage(
            title = "学習時間を記録",
            description = "タイマーを使って学習時間を簡単に記録できます。\n手動入力にも対応しています。",
            icon = Icons.Filled.Alarm,
            iconColor = Color(0xFF4CAF50)
        ),
        OnboardingPage(
            title = "教材を管理",
            description = "参考書や問題集を登録して、\n学習進捗を可視化しましょう。",
            icon = Icons.Filled.Description,
            iconColor = Color(0xFF2196F3)
        ),
        OnboardingPage(
            title = "目標を設定",
            description = "1日の目標や週間目標を設定して、\nモチベーションを維持しましょう。",
            icon = Icons.Filled.Star,
            iconColor = Color(0xFFFF9800)
        ),
        OnboardingPage(
            title = "学習を分析",
            description = "グラフで学習時間を可視化し、\n自分の学習傾向を把握しましょう。",
            icon = Icons.Filled.Analytics,
            iconColor = Color(0xFF9C27B0)
        )
    )
    
    init {
        checkOnboardingStatus()
    }
    
    private fun checkOnboardingStatus() {
        onboardingStatusJob?.cancel()
        onboardingStatusJob = viewModelScope.launch {
            try {
                onboardingPreferences.isOnboardingCompleted().collect { completed ->
                    _uiState.value = if (completed) {
                        OnboardingUiState.ShowMain
                    } else {
                        OnboardingUiState.ShowOnboarding
                    }
                }
            } catch (e: Exception) {
                _uiState.value = OnboardingUiState.Error("オンボーディングの確認に失敗しました")
            }
        }
    }

    fun retry() {
        _uiState.value = OnboardingUiState.Loading
        checkOnboardingStatus()
    }
    
    fun completeOnboarding() {
        viewModelScope.launch {
            try {
                onboardingPreferences.setOnboardingCompleted(true)
                _uiState.value = OnboardingUiState.ShowMain
            } catch (e: Exception) {
                _uiState.value = OnboardingUiState.Error("オンボーディングの完了に失敗しました")
            }
        }
    }
}
