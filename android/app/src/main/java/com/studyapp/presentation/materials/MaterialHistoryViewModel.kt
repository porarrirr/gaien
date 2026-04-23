package com.studyapp.presentation.materials

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import javax.inject.Inject

data class MaterialHistoryUiState(
    val material: Material? = null,
    val subject: Subject? = null,
    val sessions: List<StudySession> = emptyList(),
    val displayedMonth: YearMonth = YearMonth.now(),
    val selectedDate: LocalDate = LocalDate.now(),
    val studyMinutesByDay: Map<Int, Long> = emptyMap(),
    val selectedDateSessions: List<StudySession> = emptyList(),
    val selectedDateMinutes: Long = 0,
    val totalMinutes: Long = 0,
    val latestStudyDate: LocalDate? = null,
    val isLoading: Boolean = true,
    val error: String? = null
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class MaterialHistoryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val materialRepository: MaterialRepository,
    private val subjectRepository: SubjectRepository,
    private val studySessionRepository: StudySessionRepository
) : ViewModel() {

    private val materialId: Long = checkNotNull(savedStateHandle.get<Long>("materialId"))

    private val _uiState = MutableStateFlow(MaterialHistoryUiState())
    val uiState: StateFlow<MaterialHistoryUiState> = _uiState.asStateFlow()

    private var hasInitializedSelection = false

    init {
        observeHistory()
    }

    private fun observeHistory() {
        viewModelScope.launch {
            combine(
                materialRepository.getAllMaterials(),
                subjectRepository.getAllSubjects(),
                studySessionRepository.getSessionsByMaterial(materialId)
            ) { materialsResult, subjectsResult, sessionsResult ->
                Triple(materialsResult, subjectsResult, sessionsResult)
            }.collect { (materialsResult, subjectsResult, sessionsResult) ->
                val materials = when (materialsResult) {
                    is Result.Success -> materialsResult.data
                    is Result.Error -> {
                        publishError(materialsResult)
                        return@collect
                    }
                }
                val subjects = when (subjectsResult) {
                    is Result.Success -> subjectsResult.data
                    is Result.Error -> {
                        publishError(subjectsResult)
                        return@collect
                    }
                }
                val sessions = when (sessionsResult) {
                    is Result.Success -> sessionsResult.data.sortedByDescending { it.startTime }
                    is Result.Error -> {
                        publishError(sessionsResult)
                        return@collect
                    }
                }

                val material = materials.firstOrNull { it.id == materialId }
                val subject = material?.let { selected ->
                    subjects.firstOrNull { it.id == selected.subjectId }
                }
                val latestStudyDate = sessions.maxByOrNull { it.startTime }?.localDate()
                val selectedDate = if (!hasInitializedSelection) {
                    hasInitializedSelection = true
                    latestStudyDate ?: LocalDate.now()
                } else {
                    _uiState.value.selectedDate
                }
                val displayedMonth = if (_uiState.value.isLoading) {
                    YearMonth.from(selectedDate)
                } else {
                    _uiState.value.displayedMonth
                }

                _uiState.update {
                    buildState(
                        material = material,
                        subject = subject,
                        sessions = sessions,
                        displayedMonth = displayedMonth,
                        selectedDate = selectedDate,
                        latestStudyDate = latestStudyDate
                    )
                }
            }
        }
    }

    fun previousMonth() {
        _uiState.update { state ->
            val displayedMonth = state.displayedMonth.minusMonths(1)
            val selectedDate = displayedMonth.atDay(
                state.selectedDate.dayOfMonth.coerceAtMost(displayedMonth.lengthOfMonth())
            )
            buildState(
                material = state.material,
                subject = state.subject,
                sessions = state.sessions,
                displayedMonth = displayedMonth,
                selectedDate = selectedDate,
                latestStudyDate = state.latestStudyDate
            )
        }
    }

    fun nextMonth() {
        _uiState.update { state ->
            val displayedMonth = state.displayedMonth.plusMonths(1)
            val selectedDate = displayedMonth.atDay(
                state.selectedDate.dayOfMonth.coerceAtMost(displayedMonth.lengthOfMonth())
            )
            buildState(
                material = state.material,
                subject = state.subject,
                sessions = state.sessions,
                displayedMonth = displayedMonth,
                selectedDate = selectedDate,
                latestStudyDate = state.latestStudyDate
            )
        }
    }

    fun selectDate(date: LocalDate) {
        _uiState.update { state ->
            buildState(
                material = state.material,
                subject = state.subject,
                sessions = state.sessions,
                displayedMonth = YearMonth.from(date),
                selectedDate = date,
                latestStudyDate = state.latestStudyDate
            )
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun buildState(
        material: Material?,
        subject: Subject?,
        sessions: List<StudySession>,
        displayedMonth: YearMonth,
        selectedDate: LocalDate,
        latestStudyDate: LocalDate?
    ): MaterialHistoryUiState {
        val monthSessions = sessions.filter { YearMonth.from(it.localDate()) == displayedMonth }
        val studyMinutesByDay = monthSessions.groupBy { it.localDate().dayOfMonth }
            .mapValues { (_, daySessions) -> daySessions.sumOf { it.durationMinutes } }
        val selectedDateSessions = sessions
            .filter { it.localDate() == selectedDate }
            .sortedBy { it.startTime }
        return MaterialHistoryUiState(
            material = material,
            subject = subject,
            sessions = sessions,
            displayedMonth = displayedMonth,
            selectedDate = selectedDate,
            studyMinutesByDay = studyMinutesByDay,
            selectedDateSessions = selectedDateSessions,
            selectedDateMinutes = selectedDateSessions.sumOf { it.durationMinutes },
            totalMinutes = sessions.sumOf { it.durationMinutes },
            latestStudyDate = latestStudyDate,
            isLoading = false,
            error = null
        )
    }

    private fun publishError(result: Result.Error) {
        _uiState.update { state ->
            state.copy(
                isLoading = false,
                error = result.message ?: result.exception.message
            )
        }
    }

    private fun StudySession.localDate(): LocalDate {
        return Instant.ofEpochMilli(sessionStartTime).atZone(ZoneId.systemDefault()).toLocalDate()
    }
}
