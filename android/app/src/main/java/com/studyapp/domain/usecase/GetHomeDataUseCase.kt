package com.studyapp.domain.usecase

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Clock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import javax.inject.Inject

data class HomeData(
    val todayStudyMinutes: Long,
    val todaySessions: List<TodaySession>,
    val todayGoal: Goal?,
    val weeklyGoal: Goal?,
    val weeklyStudyMinutes: Long,
    val upcomingExams: List<Exam>
)

data class TodaySession(
    val id: Long,
    val subjectName: String,
    val materialName: String,
    val duration: Long,
    val startTime: Long
)

class GetHomeDataUseCase @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val goalRepository: GoalRepository,
    private val examRepository: ExamRepository,
    private val clock: Clock
) {
    operator fun invoke(): Flow<HomeData> {
        val todayStart = clock.startOfToday()
        val weekStart = clock.startOfWeek()
        val todayDayOfWeek = clock.currentLocalDate().dayOfWeek
        
        val todaySessionsFlow: Flow<List<StudySession>> = studySessionRepository
            .getSessionsBetweenDates(todayStart, todayStart + DAY_MS)
            .map { result -> result.getOrNull() ?: emptyList() }
        
        val todayStudyMinutesFlow: Flow<Long> = todaySessionsFlow.map { sessions ->
            sessions.sumOf { it.duration / 60000 }
        }
        
        val todaySessionsMappedFlow: Flow<List<TodaySession>> = todaySessionsFlow.map { sessions ->
            sessions.map { session ->
                TodaySession(
                    id = session.id,
                    subjectName = session.subjectName,
                    materialName = session.materialName,
                    duration = session.duration,
                    startTime = session.startTime
                )
            }
        }
        
        val todayGoalFlow: Flow<Goal?> = goalRepository.getActiveGoals()
            .map { result ->
                result.getOrNull()
                    .orEmpty()
                    .firstOrNull { it.type == GoalType.DAILY && it.dayOfWeek == todayDayOfWeek }
            }

        val weeklyGoalFlow: Flow<Goal?> = goalRepository.getActiveGoalByType(GoalType.WEEKLY)
            .map { result -> result.getOrNull() }
        
        val weeklyStudyMinutesFlow: Flow<Long> = studySessionRepository
            .getSessionsBetweenDates(weekStart, weekStart + WEEK_MS)
            .map { result -> result.getOrNull() ?: emptyList() }
            .map { sessions ->
                sessions.sumOf { it.duration / 60000 }
            }
        
        val upcomingExamsFlow: Flow<List<Exam>> = examRepository.getUpcomingExams()
            .map { result -> result.getOrNull() ?: emptyList() }
        
        val todayDataFlow: Flow<Triple<Long, List<TodaySession>, Goal?>> = combine(
            todayStudyMinutesFlow,
            todaySessionsMappedFlow,
            todayGoalFlow
        ) { todayMinutes, todaySessions, todayGoal ->
            Triple(todayMinutes, todaySessions, todayGoal)
        }

        return combine(
            todayDataFlow,
            weeklyGoalFlow,
            weeklyStudyMinutesFlow,
            upcomingExamsFlow
        ) { todayData, weeklyGoal, weeklyMinutes, exams ->
            val (todayMinutes, todaySessions, todayGoal) = todayData
            HomeData(
                todayStudyMinutes = todayMinutes,
                todaySessions = todaySessions.sortedByDescending { it.startTime },
                todayGoal = todayGoal,
                weeklyGoal = weeklyGoal,
                weeklyStudyMinutes = weeklyMinutes,
                upcomingExams = exams.sortedBy { it.date.toEpochDay() }
            )
        }
    }
    
    companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val WEEK_MS = 7 * DAY_MS
    }
}
