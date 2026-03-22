package com.studyapp.widgets

import android.content.Context
import android.util.Log
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first

@Singleton
class StudyWidgetSnapshotBuilder @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val goalRepository: GoalRepository,
    private val examRepository: ExamRepository,
    private val clock: Clock
) {
    suspend fun build(): StudyWidgetSnapshot {
        val nowMillis = clock.currentTimeMillis()
        val zoneId = ZoneId.systemDefault()
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        val todayStart = clock.startOfToday()
        val weekStart = clock.startOfWeek()

        val sessions = studySessionRepository.getAllSessions().first().getOrNull().orEmpty()
        val dailyGoal = goalRepository.getActiveGoalByType(GoalType.DAILY).first().getOrNull()
        val weeklyGoal = goalRepository.getActiveGoalByType(GoalType.WEEKLY).first().getOrNull()
        val upcomingExams = examRepository.getUpcomingExams().first().getOrNull().orEmpty()

        val todaySessions = sessions.filter { session ->
            session.startTime >= todayStart && session.startTime < todayStart + DAY_MS
        }
        val weeklySessions = sessions.filter { session ->
            session.startTime >= weekStart && session.startTime < weekStart + WEEK_MS
        }
        val studyDates = sessions.map { it.date }.distinct().sorted()
        val minutesByDate = sessions
            .groupBy { it.date }
            .mapValues { (_, daySessions) -> daySessions.sumOf { it.durationMinutes } }

        return StudyWidgetSnapshot(
            generatedAt = nowMillis,
            todayStudyMinutes = todaySessions.sumOf { it.durationMinutes },
            todaySessionCount = todaySessions.size,
            dailyGoalMinutes = dailyGoal?.targetMinutes,
            weeklyGoalMinutes = weeklyGoal?.targetMinutes,
            weeklyStudyMinutes = weeklySessions.sumOf { it.durationMinutes },
            streakDays = calculateStreak(today, studyDates),
            bestStreak = calculateBestStreak(studyDates),
            upcomingExams = upcomingExams
                .sortedBy { it.date }
                .take(MAX_EXAMS)
                .map { exam ->
                    WidgetExamSummary(
                        name = exam.name,
                        epochDay = exam.date.toEpochDay(),
                        daysRemaining = exam.getDaysRemaining(today)
                    )
                },
            weekActivity = buildWeekActivity(today, minutesByDate)
        )
    }

    private fun buildWeekActivity(
        today: LocalDate,
        minutesByDate: Map<LocalDate, Long>
    ): List<WidgetActivitySummary> {
        return (6 downTo 0).map { offset ->
            val date = today.minusDays(offset.toLong())
            WidgetActivitySummary(
                dayLabel = date.dayOfWeek.toJapaneseShortLabel(),
                minutes = minutesByDate[date] ?: 0L,
                isToday = offset == 0
            )
        }
    }

    private fun calculateStreak(today: LocalDate, studyDates: List<LocalDate>): Int {
        if (studyDates.isEmpty()) return 0
        val studyDateSet = studyDates.toSet()
        var streak = 0
        var cursor = today
        while (studyDateSet.contains(cursor)) {
            streak++
            cursor = cursor.minusDays(1)
        }
        return streak
    }

    private fun calculateBestStreak(studyDates: List<LocalDate>): Int {
        if (studyDates.isEmpty()) return 0
        var best = 1
        var current = 1
        for (index in 1 until studyDates.size) {
            if (studyDates[index - 1].plusDays(1) == studyDates[index]) {
                current++
                best = maxOf(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    companion object {
        private const val DAY_MS = 24L * 60L * 60L * 1000L
        private const val WEEK_MS = 7L * DAY_MS
        private const val MAX_EXAMS = 3
    }
}

@EntryPoint
@InstallIn(SingletonComponent::class)
interface StudyWidgetEntryPoint {
    fun snapshotBuilder(): StudyWidgetSnapshotBuilder
    fun stackWidgetConfigStore(): StackStudyWidgetConfigStore
    fun stackStudyWidgetSnapshotMapper(): StackStudyWidgetSnapshotMapper
}

suspend fun loadStudyWidgetSnapshot(context: Context): StudyWidgetSnapshot {
    return try {
        val entryPoint = EntryPointAccessors.fromApplication(
            context.applicationContext,
            StudyWidgetEntryPoint::class.java
        )
        entryPoint.snapshotBuilder().build()
    } catch (exception: Exception) {
        Log.e("StudyWidgetSnapshot", "Failed to build widget snapshot", exception)
        StudyWidgetSnapshot.Empty
    }
}
