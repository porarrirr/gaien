package com.studyapp.presentation.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject

data class ReportsUiState(
    val totalTime: Long = 0,
    val averageTime: Long = 0,
    val streakDays: Int = 0,
    val dailyData: List<DailyStudyData> = emptyList(),
    val weeklyData: List<WeeklyStudyData> = emptyList(),
    val monthlyData: List<MonthlyStudyData> = emptyList(),
    val subjectBreakdown: List<SubjectStudyData> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class ReportsViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val subjectRepository: SubjectRepository,
    private val clock: Clock
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ReportsUiState())
    val uiState: StateFlow<ReportsUiState> = _uiState.asStateFlow()
    
    init {
        loadReports()
    }
    
    private fun loadReports() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            val dailyDataDeferred = async { loadDailyData() }
            val weeklyDataDeferred = async { loadWeeklyData() }
            val monthlyDataDeferred = async { loadMonthlyData() }
            val subjectBreakdownDeferred = async { loadSubjectBreakdown() }

            val dailyData = when (val result = dailyDataDeferred.await()) {
                is Result.Success -> result.data
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, error = result.getErrorMessage())
                    }
                    return@launch
                }
            }
            val weeklyData = when (val result = weeklyDataDeferred.await()) {
                is Result.Success -> result.data
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, error = result.getErrorMessage())
                    }
                    return@launch
                }
            }
            val monthlyData = when (val result = monthlyDataDeferred.await()) {
                is Result.Success -> result.data
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, error = result.getErrorMessage())
                    }
                    return@launch
                }
            }
            val subjectBreakdown = when (val result = subjectBreakdownDeferred.await()) {
                is Result.Success -> result.data
                is Result.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, error = result.getErrorMessage())
                    }
                    return@launch
                }
            }
            
            val totalMinutes = monthlyData.sumOf { it.totalHours * 60L }
            val averageTime = if (dailyData.isNotEmpty()) {
                dailyData.sumOf { it.minutes } / dailyData.size
            } else {
                0L
            }
            val streakDays = calculateStreak()
            
            _uiState.update { state ->
                state.copy(
                    dailyData = dailyData,
                    weeklyData = weeklyData,
                    monthlyData = monthlyData,
                    subjectBreakdown = subjectBreakdown,
                    totalTime = totalMinutes,
                    averageTime = averageTime,
                    streakDays = streakDays,
                    isLoading = false,
                    error = null
                )
            }
        }
    }
    
    private suspend fun loadDailyData(): Result<List<DailyStudyData>> {
        return try {
            val subjects = when (val result = subjectRepository.getAllSubjects().first()) {
                is Result.Success -> result.data
                is Result.Error -> return result
            }
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val dailyData = mutableListOf<DailyStudyData>()
            val dateFormat = SimpleDateFormat("M/d (E)", Locale.JAPANESE)
            
            for (i in 0 until 7) {
                val dayStart = calendar.timeInMillis
                val dayEnd = dayStart + 24 * 60 * 60 * 1000
                
                when (val result = studySessionRepository.getSessionsBetweenDates(dayStart, dayEnd).first()) {
                    is Result.Success -> {
                        val segments = subjectSegments(subjects, result.data)
                        val dayMinutes = segments.sumOf { it.minutes }
                        dailyData.add(0, DailyStudyData(
                            dateLabel = dateFormat.format(Date(dayStart)),
                            dateMillis = dayStart,
                            minutes = dayMinutes,
                            hours = dayMinutes / 60f,
                            segments = segments
                        ))
                    }
                    is Result.Error -> return result
                }
                
                calendar.add(Calendar.DAY_OF_MONTH, -1)
            }
            
            Result.Success(dailyData)
        } catch (e: Exception) {
            Result.Error(e, "日次データの読み込みに失敗しました")
        }
    }
    
    private suspend fun loadWeeklyData(): Result<List<WeeklyStudyData>> {
        return try {
            val subjects = when (val result = subjectRepository.getAllSubjects().first()) {
                is Result.Success -> result.data
                is Result.Error -> return result
            }
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val weeklyData = mutableListOf<WeeklyStudyData>()
            
            for (i in 0 until 4) {
                val weekStart = calendar.timeInMillis
                val weekEnd = weekStart + 7 * 24 * 60 * 60 * 1000
                
                when (val result = studySessionRepository.getSessionsBetweenDates(weekStart, weekEnd).first()) {
                    is Result.Success -> {
                        val segments = subjectSegments(subjects, result.data)
                        val weekMinutes = segments.sumOf { it.minutes }
                        val startFormat = SimpleDateFormat("M/d", Locale.JAPANESE)
                        weeklyData.add(0, WeeklyStudyData(
                            weekLabel = "${startFormat.format(Date(weekStart))}週",
                            hours = weekMinutes / 60,
                            minutes = weekMinutes % 60,
                            segments = segments
                        ))
                    }
                    is Result.Error -> return result
                }
                
                calendar.add(Calendar.WEEK_OF_YEAR, -1)
            }
            
            Result.Success(weeklyData)
        } catch (e: Exception) {
            Result.Error(e, "週次データの読み込みに失敗しました")
        }
    }

    private fun subjectSegments(
        subjects: List<Subject>,
        sessions: List<StudySession>
    ): List<SubjectStudySegment> {
        return subjects.mapNotNull { subject ->
            val minutes = sessions
                .filter { it.subjectId == subject.id }
                .sumOf { it.durationMinutes }
            if (minutes <= 0) {
                null
            } else {
                SubjectStudySegment(
                    subjectId = subject.id,
                    subjectName = subject.name,
                    minutes = minutes,
                    color = subject.color
                )
            }
        }
    }
    
    private suspend fun loadMonthlyData(): Result<List<MonthlyStudyData>> {
        return try {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.DAY_OF_MONTH, 1)
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val monthlyData = mutableListOf<MonthlyStudyData>()
            val dateFormat = SimpleDateFormat("M月", Locale.JAPANESE)
            
            for (i in 0 until 6) {
                val monthStart = calendar.timeInMillis
                val monthLabel = dateFormat.format(Date(monthStart))
                calendar.add(Calendar.MONTH, 1)
                val monthEnd = calendar.timeInMillis
                
                when (val result = studySessionRepository.getTotalDurationBetweenDates(monthStart, monthEnd)) {
                    is Result.Success -> {
                        val monthMinutes = result.data / 60000
                        
                        monthlyData.add(0, MonthlyStudyData(
                            monthLabel = monthLabel,
                            totalHours = monthMinutes / 60
                        ))
                    }
                    is Result.Error -> return result
                }
                
                calendar.add(Calendar.MONTH, -2)
            }
            
            Result.Success(monthlyData)
        } catch (e: Exception) {
            Result.Error(e, "月次データの読み込みに失敗しました")
        }
    }
    
    private suspend fun loadSubjectBreakdown(): Result<List<SubjectStudyData>> {
        return try {
            val calendar = Calendar.getInstance()
            calendar.add(Calendar.MONTH, -1)
            val startTime = calendar.timeInMillis
            val endTime = clock.currentTimeMillis()
            
            val subjectsResult = subjectRepository.getAllSubjects().first()
            
            val subjects = when (subjectsResult) {
                is Result.Success -> subjectsResult.data
                is Result.Error -> return subjectsResult
            }
            
            val breakdown = subjects.mapNotNull { subject ->
                when (val result = studySessionRepository.getTotalDurationBySubjectBetweenDates(subject.id, startTime, endTime)) {
                    is Result.Success -> {
                        val minutes = result.data / 60000
                        if (minutes > 0) {
                            SubjectStudyData(
                                subjectName = subject.name,
                                hours = minutes / 60,
                                minutes = minutes % 60,
                                color = subject.color
                            )
                        } else null
                    }
                    is Result.Error -> null
                }
            }.sortedByDescending { it.hours * 60 + it.minutes }
            
            Result.Success(breakdown)
        } catch (e: Exception) {
            Result.Error(e, "科目別データの読み込みに失敗しました")
        }
    }
    
    private suspend fun calculateStreak(): Int {
        var streak = 0
        var currentDate = clock.startOfToday()
        
        for (i in 0 until 365) {
            val dayDuration = when (val result = studySessionRepository.getTotalDurationByDate(currentDate)) {
                is Result.Success -> result.data
                is Result.Error -> return streak
            }

            if (dayDuration > 0) {
                streak++
                currentDate -= DAY_MS
            } else if (i == 0) {
                currentDate -= DAY_MS
            } else {
                break
            }
        }
        
        return streak
    }
    
    fun refresh() {
        loadReports()
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
    }
}
