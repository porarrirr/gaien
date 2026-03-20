package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.first
import java.time.DayOfWeek
import java.time.temporal.WeekFields
import java.util.Locale
import javax.inject.Inject

data class DailyStudyData(
    val date: Long,
    val dayOfWeek: DayOfWeek,
    val totalMinutes: Long
)

data class WeeklyStudyData(
    val weekStart: Long,
    val weekEnd: Long,
    val totalMinutes: Long,
    val averageMinutes: Long
)

data class MonthlyStudyData(
    val monthStart: Long,
    val totalMinutes: Long,
    val activeDays: Int
)

data class ReportsData(
    val dailyData: List<DailyStudyData>,
    val weeklyData: List<WeeklyStudyData>,
    val monthlyData: List<MonthlyStudyData>,
    val streak: Int,
    val bestStreak: Int
)

class GetReportsDataUseCase @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val clock: Clock
) {
    suspend operator fun invoke(): ReportsData {
        Log.d(TAG, "Generating reports data")
        
        val now = clock.currentTimeMillis()
        val dailyData = getDailyData(now)
        val weeklyData = getWeeklyData(now)
        val monthlyData = getMonthlyData(now)
        val streak = calculateStreak(now)
        val bestStreak = calculateBestStreak(now)
        
        Log.i(TAG, "Reports data generated: daily=${dailyData.size}, weekly=${weeklyData.size}, monthly=${monthlyData.size}, streak=$streak, bestStreak=$bestStreak")
        
        return ReportsData(
            dailyData = dailyData,
            weeklyData = weeklyData,
            monthlyData = monthlyData,
            streak = streak,
            bestStreak = bestStreak
        )
    }
    
    private suspend fun getSessionsBetween(startDate: Long, endDate: Long): List<com.studyapp.domain.model.StudySession> {
        return studySessionRepository.getSessionsBetweenDates(startDate, endDate).first()
            .getOrNull() ?: emptyList()
    }
    
    private suspend fun getDailyData(now: Long): List<DailyStudyData> {
        val startTime = now - (DAYS_TO_ANALYZE * DAY_MS)
        val sessions = getSessionsBetween(startTime, now)
        
        return sessions
            .groupBy { session -> session.date }
            .map { (date, daySessions) ->
                DailyStudyData(
                    date = daySessions.first().startTime,
                    dayOfWeek = date.dayOfWeek,
                    totalMinutes = daySessions.sumOf { it.duration / 60000 }
                )
            }
            .sortedBy { it.date }
    }
    
    private suspend fun getWeeklyData(now: Long): List<WeeklyStudyData> {
        val sessions = getSessionsBetween(
            now - (WEEKS_TO_ANALYZE * WEEK_MS),
            now
        )
        
        return sessions
            .groupBy { session ->
                val localDate = session.date
                val weekFields = WeekFields.of(Locale.getDefault()).firstDayOfWeek
                val startOfWeek = localDate.with(weekFields)
                startOfWeek.toEpochDay() * DAY_MS
            }
            .map { (weekStart, weekSessions) ->
                WeeklyStudyData(
                    weekStart = weekStart,
                    weekEnd = weekStart + WEEK_MS,
                    totalMinutes = weekSessions.sumOf { it.duration / 60000 },
                    averageMinutes = weekSessions.sumOf { it.duration / 60000 } / 7
                )
            }
            .sortedBy { it.weekStart }
    }
    
    private suspend fun getMonthlyData(now: Long): List<MonthlyStudyData> {
        val sessions = getSessionsBetween(
            now - (MONTHS_TO_ANALYZE * MONTH_MS),
            now
        )
        
        return sessions
            .groupBy { session ->
                val localDate = session.date
                localDate.withDayOfMonth(1).toEpochDay() * DAY_MS
            }
            .map { (monthStart, monthSessions) ->
                MonthlyStudyData(
                    monthStart = monthStart,
                    totalMinutes = monthSessions.sumOf { it.duration / 60000 },
                    activeDays = monthSessions.distinctBy { it.date }.size
                )
            }
            .sortedBy { it.monthStart }
    }
    
    private suspend fun calculateStreak(now: Long): Int {
        var streak = 0
        var currentDate = clock.startOfToday()
        
        repeat(MAX_STREAK_DAYS) {
            val sessions = getSessionsBetween(currentDate, currentDate + DAY_MS)
            
            if (sessions.isNotEmpty()) {
                streak++
                currentDate -= DAY_MS
            } else {
                return@repeat
            }
        }
        
        return streak
    }
    
    private suspend fun calculateBestStreak(now: Long): Int {
        val sessions = studySessionRepository.getAllSessions().first()
            .getOrNull() ?: return 0
        
        if (sessions.isEmpty()) return 0
        
        val studyDates = sessions
            .map { it.date.toEpochDay() * DAY_MS }
            .distinct()
            .sorted()
        
        var bestStreak = 1
        var currentStreak = 1
        
        for (i in 1 until studyDates.size) {
            if (studyDates[i] - studyDates[i - 1] == DAY_MS) {
                currentStreak++
                bestStreak = maxOf(bestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return bestStreak
    }
    
    companion object {
        private const val TAG = "GetReportsDataUseCase"
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val WEEK_MS = 7 * DAY_MS
        private const val MONTH_MS = 30 * DAY_MS
        private const val DAYS_TO_ANALYZE = 30
        private const val WEEKS_TO_ANALYZE = 12
        private const val MONTHS_TO_ANALYZE = 6
        private const val MAX_STREAK_DAYS = 365
    }
}