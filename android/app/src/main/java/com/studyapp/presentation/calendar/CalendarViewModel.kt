package com.studyapp.presentation.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.Calendar
import java.util.Date
import javax.inject.Inject

enum class CalendarDetailMode { SUMMARY, TIMELINE }

data class CalendarUiState(
    val currentYear: Int = Calendar.getInstance().get(Calendar.YEAR),
    val currentMonth: Int = Calendar.getInstance().get(Calendar.MONTH) + 1,
    val selectedDate: Date? = null,
    val studyDataByDate: Map<Int, Long> = emptyMap(),
    val selectedDateMinutes: Long = 0,
    val selectedDateSessions: List<StudySession> = emptyList(),
    val selectedDateTimeline: List<TimelineItem> = emptyList(),
    val isLoading: Boolean = true,
    val isDetailLoading: Boolean = false,
    val updatingSessionId: Long? = null,
    val error: String? = null,
    val detailMode: CalendarDetailMode = CalendarDetailMode.TIMELINE,
    val monthlyStudyDays: Int = 0,
    val monthlyTotalMinutes: Long = 0
)

sealed class TimelineItem {
    abstract val sortMinute: Int

    data class Lesson(
        val entry: TimetableEntry,
        val period: TimetablePeriod
    ) : TimelineItem() {
        override val sortMinute: Int get() = period.startMinute
    }

    data class Session(
        val session: StudySession
    ) : TimelineItem() {
        override val sortMinute: Int
            get() {
                val cal = Calendar.getInstance()
                cal.timeInMillis = session.startTime
                return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            }
    }

    data class Gap(
        val startMinute: Int,
        val endMinute: Int
    ) : TimelineItem() {
        override val sortMinute: Int get() = startMinute
    }
}

private data class SelectedDateSessionsState(
    val selectedDate: Date?,
    val result: Result<List<StudySession>>
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val timetableRepository: TimetableRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CalendarUiState())
    val uiState: StateFlow<CalendarUiState> = _uiState.asStateFlow()
    private var cachedPeriods: List<TimetablePeriod> = emptyList()
    private var cachedEntries: List<TimetableEntry> = emptyList()
    private var cachedTerms: List<TimetableTerm> = emptyList()
    private val timelineCache = mutableMapOf<Long, List<TimelineItem>>()

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
        observeTimetableCache()
    }

    private fun observeTimetableCache() {
        viewModelScope.launch {
            combine(
                timetableRepository.getAllPeriods(),
                timetableRepository.getAllEntries(),
                timetableRepository.getAllTerms()
            ) { periodsResult, entriesResult, termsResult ->
                Triple(periodsResult, entriesResult, termsResult)
            }.collect { (periodsResult, entriesResult, termsResult) ->
                cachedPeriods = when (val result = periodsResult) {
                    is Result.Success -> result.data.filter { it.deletedAt == null && it.isActive }
                    is Result.Error -> emptyList()
                }
                cachedEntries = when (val result = entriesResult) {
                    is Result.Success -> result.data.filter { it.deletedAt == null }
                    is Result.Error -> emptyList()
                }
                cachedTerms = when (val result = termsResult) {
                    is Result.Success -> result.data.filter { it.deletedAt == null }
                    is Result.Error -> emptyList()
                }
                timelineCache.clear()
            }
        }
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
                                val day = LocalDate.ofEpochDay(session.date).dayOfMonth
                                studyData[day] = (studyData[day] ?: 0L) + session.durationMinutes.toLong()
                            }

                            val monthlyTotalMinutes = studyData.values.sum()
                            val monthlyStudyDays = studyData.size

                            _uiState.update { state ->
                                state.copy(
                                    currentYear = year,
                                    currentMonth = month,
                                    studyDataByDate = studyData,
                                    monthlyTotalMinutes = monthlyTotalMinutes,
                                    monthlyStudyDays = monthlyStudyDays,
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
                            val timeline = buildTimeline(detailState.selectedDate, sessions)
                            _uiState.update { state ->
                                state.copy(
                                    selectedDate = detailState.selectedDate,
                                    selectedDateSessions = sessions,
                                    selectedDateMinutes = sessions.sumOf { it.durationMinutes.toLong() },
                                    selectedDateTimeline = timeline,
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

    private suspend fun buildTimeline(date: Date?, sessions: List<StudySession>): List<TimelineItem> {
        if (date == null) return emptyList()
        val dayKey = date.startOfDayMillis()
        timelineCache[dayKey]?.let { return it }

        val localDate = LocalDate.ofEpochDay(date.startOfDayMillis() / (24 * 60 * 60 * 1000L))
        val weekday = StudyWeekday.fromDayOfWeek(localDate.dayOfWeek)
        if (!StudyWeekday.timetableDays.contains(weekday)) {
            val sessionOnly = sessions.map { TimelineItem.Session(it) }
            timelineCache[dayKey] = sessionOnly
            return sessionOnly
        }

        val periods = cachedPeriods
        val entries = cachedEntries
        val terms = cachedTerms

        val epochDay = localDate.toEpochDay()
        val activeTerm = terms.firstOrNull { it.isActive && it.contains(localDate) }
        val periodMap = periods.associateBy { it.id }

        val lessons = entries
            .filter { entry ->
                entry.dayOfWeek == weekday &&
                (entry.termId == activeTerm?.id || entry.termId == null) &&
                (entry.validFromDate?.let { epochDay >= it } ?: true) &&
                (entry.validToDate?.let { epochDay <= it } ?: true) &&
                periodMap[entry.periodId] != null
            }
            .mapNotNull { entry ->
                val period = periodMap[entry.periodId] ?: return@mapNotNull null
                TimelineItem.Lesson(entry, period)
            }
            .sortedBy { it.period.startMinute }

        val sessionItems = sessions.map { TimelineItem.Session(it) }
        val allItems = (lessons + sessionItems).sortedBy { it.sortMinute }

        val result = mutableListOf<TimelineItem>()
        var lastEndMinute = 0
        for (item in allItems) {
            val startMinute = when (item) {
                is TimelineItem.Lesson -> item.period.startMinute
                is TimelineItem.Session -> item.sortMinute
                is TimelineItem.Gap -> item.startMinute
            }
            if (startMinute > lastEndMinute + 5) {
                result.add(TimelineItem.Gap(lastEndMinute, startMinute))
            }
            result.add(item)
            lastEndMinute = when (item) {
                is TimelineItem.Lesson -> item.period.endMinute
                is TimelineItem.Session -> {
                    val cal = Calendar.getInstance()
                    cal.timeInMillis = item.session.endTime
                    cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                }
                is TimelineItem.Gap -> item.endMinute
            }
        }
        timelineCache[dayKey] = result
        return result
    }

    fun previousMonth() {
        timelineCache.clear()
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
        timelineCache.clear()
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

    fun setDetailMode(mode: CalendarDetailMode) {
        _uiState.update { state -> state.copy(detailMode = mode) }
    }

    fun deleteSession(session: StudySession) {
        viewModelScope.launch {
            _uiState.update { state ->
                state.copy(updatingSessionId = session.id)
            }

            when (val result = studySessionRepository.deleteSession(session)) {
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

    fun updateSession(session: StudySession) {
        viewModelScope.launch {
            _uiState.update { state ->
                state.copy(updatingSessionId = session.id)
            }

            when (val result = studySessionRepository.updateSession(session)) {
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
