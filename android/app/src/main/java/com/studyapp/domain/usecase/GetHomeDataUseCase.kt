package com.studyapp.domain.usecase

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetableLesson
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.model.TodayReviewProblem
import com.studyapp.domain.model.latestActiveDailyGoal
import com.studyapp.domain.model.latestActiveWeeklyGoal
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.ProblemReviewRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Clock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import java.time.LocalTime
import javax.inject.Inject

data class HomeData(
    val todayStudyMinutes: Long,
    val todaySessions: List<TodaySession>,
    val todayGoal: Goal?,
    val weeklyGoal: Goal?,
    val weeklyStudyMinutes: Long,
    val upcomingExams: List<Exam>,
    val timetableLesson: TimetableLesson? = null,
    val todayReviewProblems: List<TodayReviewProblem> = emptyList()
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
    private val materialRepository: MaterialRepository,
    private val subjectRepository: SubjectRepository,
    private val problemReviewRepository: ProblemReviewRepository,
    private val goalRepository: GoalRepository,
    private val examRepository: ExamRepository,
    private val timetableRepository: TimetableRepository,
    private val clock: Clock
) {
    operator fun invoke(): Flow<HomeData> {
        val todayStart = clock.startOfToday()
        val todayEnd = todayStart + DAY_MS - 1
        val weekStart = clock.startOfWeek()
        val todayStudyWeekday = StudyWeekday.fromDayOfWeek(clock.currentLocalDate().dayOfWeek)

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

        val allGoalsFlow = goalRepository.getAllGoals()
            .map { result -> result.getOrNull() ?: emptyList() }

        val todayGoalFlow: Flow<Goal?> = allGoalsFlow.map { goals ->
            goals.latestActiveDailyGoal(todayStudyWeekday)
        }

        val weeklyGoalFlow: Flow<Goal?> = allGoalsFlow.map { goals ->
            goals.latestActiveWeeklyGoal()
        }

        val weeklyStudyMinutesFlow: Flow<Long> = studySessionRepository
            .getSessionsBetweenDates(weekStart, weekStart + WEEK_MS)
            .map { result -> result.getOrNull() ?: emptyList() }
            .map { sessions ->
                sessions.sumOf { it.duration / 60000 }
            }

        val upcomingExamsFlow: Flow<List<Exam>> = examRepository.getUpcomingExams()
            .map { result -> result.getOrNull() ?: emptyList() }

        val todayReviewProblemsFlow: Flow<List<TodayReviewProblem>> = combine(
            problemReviewRepository.getActiveReviewRecords().map { it.getOrNull() ?: emptyList() },
            materialRepository.getAllMaterials().map { it.getOrNull() ?: emptyList() },
            subjectRepository.getAllSubjects().map { it.getOrNull() ?: emptyList() }
        ) { reviews, materials, subjects ->
            val materialMap = materials
                .filter { it.deletedAt == null }
                .associateBy { it.id }
            val subjectMap = subjects
                .filter { it.deletedAt == null }
                .associateBy { it.id }
            reviews
                .groupBy { it.problemId.ifBlank { com.studyapp.domain.model.ProblemReviewRecord.problemId(it.materialId, it.problemNumber) } }
                .mapNotNull { (_, problemReviews) ->
                    problemReviews.maxByOrNull { it.reviewedAt }
                }
                .filter { it.nextReviewDate <= todayEnd && it.deletedAt == null }
                .mapNotNull { review ->
                    val material = materialMap[review.materialId] ?: return@mapNotNull null
                    val subject = subjectMap[material.subjectId]
                    TodayReviewProblem(
                        materialId = material.id,
                        materialName = material.name,
                        subjectName = subject?.name.orEmpty(),
                        problemNumber = review.problemNumber,
                        nextReviewDate = review.nextReviewDate,
                        consecutiveCorrectCount = review.consecutiveCorrectCount,
                        wrongCount = review.wrongCount
                    )
                }
                .sortedWith(
                    compareBy<TodayReviewProblem> { it.nextReviewDate }
                        .thenBy { it.materialName }
                        .thenBy { it.problemNumber }
                )
        }

        val timetableLessonFlow: Flow<TimetableLesson?> = combine(
            timetableRepository.getAllPeriods().map { it.getOrNull() ?: emptyList() },
            timetableRepository.getAllEntries().map { it.getOrNull() ?: emptyList() },
            timetableRepository.getAllTerms().map { it.getOrNull() ?: emptyList() }
        ) { periods, entries, terms ->
            nextTimetableLesson(periods, entries, terms, LocalDate.now())
        }

        val todayDataFlow: Flow<Triple<Long, List<TodaySession>, Goal?>> = combine(
            todayStudyMinutesFlow,
            todaySessionsMappedFlow,
            todayGoalFlow
        ) { todayMinutes, todaySessions, todayGoal ->
            Triple(todayMinutes, todaySessions, todayGoal)
        }

        data class SecondaryHomeData(
            val weeklyGoal: Goal?,
            val weeklyMinutes: Long,
            val exams: List<Exam>,
            val timetableLesson: TimetableLesson?,
            val todayReviewProblems: List<TodayReviewProblem>
        )

        val secondaryHomeDataFlow: Flow<SecondaryHomeData> = combine(
            weeklyGoalFlow,
            weeklyStudyMinutesFlow,
            upcomingExamsFlow,
            timetableLessonFlow,
            todayReviewProblemsFlow
        ) { weeklyGoal, weeklyMinutes, exams, timetableLesson, todayReviewProblems ->
            SecondaryHomeData(
                weeklyGoal = weeklyGoal,
                weeklyMinutes = weeklyMinutes,
                exams = exams,
                timetableLesson = timetableLesson,
                todayReviewProblems = todayReviewProblems
            )
        }

        return combine(
            todayDataFlow,
            secondaryHomeDataFlow
        ) { todayData, secondaryData ->
            val (todayMinutes, todaySessions, todayGoal) = todayData
            HomeData(
                todayStudyMinutes = todayMinutes,
                todaySessions = todaySessions.sortedByDescending { it.startTime },
                todayGoal = todayGoal,
                weeklyGoal = secondaryData.weeklyGoal,
                weeklyStudyMinutes = secondaryData.weeklyMinutes,
                upcomingExams = secondaryData.exams.sortedBy { it.date },
                timetableLesson = secondaryData.timetableLesson,
                todayReviewProblems = secondaryData.todayReviewProblems
            )
        }
    }

    private fun nextTimetableLesson(
        periods: List<TimetablePeriod>,
        entries: List<TimetableEntry>,
        terms: List<TimetableTerm>,
        reference: LocalDate
    ): TimetableLesson? {
        val activePeriods = periods
            .filter { it.isActive && it.deletedAt == null && it.startMinute < it.endMinute }
            .sortedWith(compareBy<TimetablePeriod> { it.sortOrder }.thenBy { it.startMinute })
        if (activePeriods.isEmpty()) return null

        val periodMap = activePeriods.associateBy { it.id }
        val activeTerm = terms.firstOrNull { it.deletedAt == null && it.isActive && it.contains(reference) }
            ?: terms.filter { it.deletedAt == null && it.isActive }.maxByOrNull { it.endDate }
        val referenceDay = reference.toEpochDay()
        val activeEntries = entries.filter {
            it.deletedAt == null &&
            (it.termId == activeTerm?.id || it.termId == null) &&
            (it.validFromDate?.let { d -> referenceDay >= d } ?: true) &&
            (it.validToDate?.let { d -> referenceDay <= d } ?: true) &&
            StudyWeekday.timetableDays.contains(it.dayOfWeek) &&
            periodMap[it.periodId] != null
        }
        if (activeEntries.isEmpty()) return null

        val now = LocalTime.now()
        val currentMinutes = now.hour * 60 + now.minute
        val referenceWeekday = StudyWeekday.fromDayOfWeek(reference.dayOfWeek)

        for (offset in 0 until 7) {
            val date = reference.plusDays(offset.toLong())
            val day = StudyWeekday.fromDayOfWeek(date.dayOfWeek)
            if (!StudyWeekday.timetableDays.contains(day)) continue

            val dayEntries = activeEntries
                .filter { it.dayOfWeek == day }
                .mapNotNull { entry ->
                    val period = periodMap[entry.periodId] ?: return@mapNotNull null
                    Pair(entry, period)
                }
                .sortedBy { it.second.startMinute }

            for (pair in dayEntries) {
                val entry = pair.first
                val period = pair.second
                if (offset == 0 && day == referenceWeekday) {
                    if (currentMinutes >= period.startMinute && currentMinutes < period.endMinute) {
                        return TimetableLesson(entry = entry, period = period, dayOfWeek = day, date = date, isCurrent = true)
                    }
                    if (currentMinutes >= period.endMinute) continue
                }
                return TimetableLesson(entry = entry, period = period, dayOfWeek = day, date = date, isCurrent = false)
            }
        }

        return null
    }

    companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val WEEK_MS = 7 * DAY_MS
    }
}
