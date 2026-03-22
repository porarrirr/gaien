package com.studyapp.presentation.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Date
import javax.inject.Inject

data class CalendarUiState(
    val currentYear: Int = Calendar.getInstance().get(Calendar.YEAR),
    val currentMonth: Int = Calendar.getInstance().get(Calendar.MONTH) + 1,
    val selectedDate: Date? = null,
    val studyDataByDate: Map<Int, Long> = emptyMap(),
    val selectedDateMinutes: Long = 0,
    val selectedDateSessions: List<StudySession> = emptyList(),
    val isLoading: Boolean = true,
    val isDetailLoading: Boolean = false,
    val updatingSessionId: Long? = null,
    val error: String? = null
)

private data class SelectedDateSessionsState(
    val selectedDate: Date?,
    val result: Result<List<StudySession>>
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository
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
        observeMonthData()
        observeSelectedDateData()
    }

    private fun observeMonthData() {
        viewModelScope.launch {
            currentMonthState
                .flatMapLatest { (year, monthValue) ->
                    val calendar = Calendar.getInstance()
                    calendar.set(year, monthValue - 1, 1, 0, 0, 0)
                    calendar.set(Calendar.MILLISECOND, 0)
                    val monthStart = calendar.timeInMillis
                    calendar.add(Calendar.MONTH, 1)
                    val monthEnd = calendar.timeInMillis

                    studySessionRepository.getSessionsBetweenDates(monthStart, monthEnd)
                        .map { result -> Triple(year, monthValue, result) }
                }
                .collect { (year, month, result) ->
                    when (result) {
                        is Result.Success -> {
                            val studyData = mutableMapOf<Int, Long>()
                            result.data.forEach { session ->
                                val day = session.date.dayOfMonth
                                studyData[day] = (studyData[day] ?: 0L) + session.durationMinutes
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
    }

    private fun observeSelectedDateData() {
        viewModelScope.launch {
            selectedDateState
                .flatMapLatest { selectedDate ->
                    if (selectedDate == null) {
                        flowOf(
                            SelectedDateSessionsState(
                                selectedDate = null,
                                result = Result.Success(emptyList())
                            )
                        )
                    } else {
                        val dayStart = selectedDate.startOfDayMillis()
                        studySessionRepository.getSessionsByDate(dayStart)
                            .map { result ->
                                SelectedDateSessionsState(
                                    selectedDate = selectedDate,
                                    result = result
                                )
                            }
                    }
                }
                .collect { detailState ->
                    when (val result = detailState.result) {
                        is Result.Success -> {
                            val sessions = result.data.sortedBy { it.startTime }
                            _uiState.update { state ->
                                state.copy(
                                    selectedDate = detailState.selectedDate,
                                    selectedDateSessions = sessions,
                                    selectedDateMinutes = sessions.sumOf { it.durationMinutes },
                                    isDetailLoading = false,
                                    error = null
                                )
                            }
                        }

                        is Result.Error -> {
                            _uiState.update { state ->
                                state.copy(
                                    isDetailLoading = false,
                                    error = result.message ?: result.exception.message
                                )
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
        clearSelectedDate()
        _uiState.update { state ->
            state.copy(isLoading = true)
        }
    }

    fun nextMonth() {
        currentMonthState.update { (year, month) ->
            val newMonth = if (month == 12) 1 else month + 1
            val newYear = if (month == 12) year + 1 else year
            Pair(newYear, newMonth)
        }
        clearSelectedDate()
        _uiState.update { state ->
            state.copy(isLoading = true)
        }
    }

    fun selectDate(date: Date) {
        _uiState.update { state ->
            state.copy(
                selectedDate = date,
                selectedDateSessions = emptyList(),
                selectedDateMinutes = 0,
                isDetailLoading = true
            )
        }
        selectedDateState.value = date
    }

    fun updateSessionNote(session: StudySession, note: String) {
        viewModelScope.launch {
            _uiState.update { state ->
                state.copy(updatingSessionId = session.id)
            }

            when (
                val result = studySessionRepository.updateSession(
                    session.copy(note = note.trim().takeIf { it.isNotEmpty() })
                )
            ) {
                is Result.Success -> {
                    _uiState.update { state ->
                        state.copy(updatingSessionId = null)
                    }
                }

                is Result.Error -> {
                    _uiState.update { state ->
                        state.copy(
                            updatingSessionId = null,
                            error = result.message ?: result.exception.message
                        )
                    }
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun clearSelectedDate() {
        selectedDateState.value = null
        _uiState.update { state ->
            state.copy(
                selectedDate = null,
                selectedDateSessions = emptyList(),
                selectedDateMinutes = 0,
                isDetailLoading = false,
                updatingSessionId = null
            )
        }
    }

    private fun Date.startOfDayMillis(): Long {
        return Calendar.getInstance().run {
            time = this@startOfDayMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            timeInMillis
        }
    }
}
