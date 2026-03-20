package com.studyapp.presentation.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.*
import javax.inject.Inject

data class CalendarUiState(
    val currentYear: Int = Calendar.getInstance().get(Calendar.YEAR),
    val currentMonth: Int = Calendar.getInstance().get(Calendar.MONTH) + 1,
    val selectedDate: Date? = null,
    val studyDataByDate: Map<Int, Long> = emptyMap(),
    val selectedDateMinutes: Long = 0,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val clock: Clock
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(CalendarUiState())
    val uiState: StateFlow<CalendarUiState> = _uiState.asStateFlow()
    
    private val currentMonthState = MutableStateFlow(
        Pair(
            Calendar.getInstance().get(Calendar.YEAR),
            Calendar.getInstance().get(Calendar.MONTH) + 1
        )
    )
    
    private val selectedDateState = MutableStateFlow<Date?>(null)
    
    init {
        observeData()
    }
    
    private fun observeData() {
        viewModelScope.launch {
            combine(
                currentMonthState,
                selectedDateState
            ) { month, selectedDate ->
                Pair(month, selectedDate)
            }.flatMapLatest { (month, selectedDate) ->
                val (year, monthValue) = month
                
                val calendar = Calendar.getInstance()
                calendar.set(year, monthValue - 1, 1, 0, 0, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                val monthStart = calendar.timeInMillis
                calendar.add(Calendar.MONTH, 1)
                val monthEnd = calendar.timeInMillis
                
                studySessionRepository.getSessionsBetweenDates(monthStart, monthEnd)
                    .map { result ->
                        Triple(year, monthValue, result)
                    }
            }.collect { (year, month, result) ->
                when (result) {
                    is Result.Success -> {
                        val studyData = mutableMapOf<Int, Long>()
                        result.data.forEach { session ->
                            val day = session.date.dayOfMonth
                            studyData[day] = (studyData[day] ?: 0L) + session.duration / 60000
                        }
                        
                        _uiState.update { state ->
                            state.copy(
                                currentYear = year,
                                currentMonth = month,
                                studyDataByDate = studyData,
                                isLoading = false,
                                error = null
                            )
                        }
                    }
                    is Result.Error -> {
                        _uiState.update { state ->
                            state.copy(
                                isLoading = false,
                                error = result.message ?: result.exception.message
                            )
                        }
                    }
                }
            }
        }
        
        viewModelScope.launch {
            selectedDateState.filterNotNull().collect { date ->
                val calendar = Calendar.getInstance()
                calendar.time = date
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                val dayStart = calendar.timeInMillis
                
                when (val result = studySessionRepository.getTotalDurationByDate(dayStart)) {
                    is Result.Success -> {
                        _uiState.update { state ->
                            state.copy(
                                selectedDate = date,
                                selectedDateMinutes = result.data / 60000,
                                error = null
                            )
                        }
                    }
                    is Result.Error -> {
                        _uiState.update { state ->
                            state.copy(error = result.message ?: result.exception.message)
                        }
                    }
                }
            }
        }
    }
    
    fun previousMonth() {
        currentMonthState.update { (year, month) ->
            val newMonth = if (month == 1) 12 else month - 1
            val newYear = if (month == 1) year - 1 else year
            Pair(newYear, newMonth)
        }
        _uiState.update { state ->
            state.copy(selectedDate = null, isLoading = true)
        }
        selectedDateState.value = null
    }
    
    fun nextMonth() {
        currentMonthState.update { (year, month) ->
            val newMonth = if (month == 12) 1 else month + 1
            val newYear = if (month == 12) year + 1 else year
            Pair(newYear, newMonth)
        }
        _uiState.update { state ->
            state.copy(selectedDate = null, isLoading = true)
        }
        selectedDateState.value = null
    }
    
    fun selectDate(date: Date) {
        selectedDateState.value = date
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}