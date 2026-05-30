package com.studyapp.domain.usecase

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.ProblemReviewRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.FixedClock
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GetHomeDataUseCaseTest {
    private val zoneId = ZoneId.systemDefault()
    private val referenceDate = LocalDate.of(2026, 5, 4)
    private val now = LocalDateTime.of(2026, 5, 4, 9, 30)
    private val nowMillis = now.atZone(zoneId).toInstant().toEpochMilli()
    private val todayStart = referenceDate.atStartOfDay(zoneId).toInstant().toEpochMilli()
    private val weekStart = LocalDate.of(2026, 5, 4).atStartOfDay(zoneId).toInstant().toEpochMilli()

    @Test
    fun `home data combines totals goals exams review problems and timetable lessons`() = runTest {
        val todaySessionEarly = session(id = 1, day = referenceDate, hour = 8, minutes = 25, subjectName = "数学")
        val todaySessionLate = session(id = 2, day = referenceDate, hour = 18, minutes = 35, subjectName = "英語")
        val weekSession = session(id = 3, day = referenceDate.plusDays(1), hour = 10, minutes = 40, subjectName = "数学")
        val todayGoalOld = goal(id = 1, type = GoalType.DAILY, targetMinutes = 30, day = StudyWeekday.MONDAY, updatedAt = 100)
        val todayGoalNew = goal(id = 2, type = GoalType.DAILY, targetMinutes = 90, day = StudyWeekday.MONDAY, updatedAt = 200)
        val weeklyGoal = goal(id = 3, type = GoalType.WEEKLY, targetMinutes = 420, day = null, updatedAt = 300)
        val material = Material(id = 10, syncId = "material-10", name = "数学問題集", subjectId = 20)
        val subject = Subject(id = 20, syncId = "subject-20", name = "数学", color = 0x4CAF50)
        val firstPeriod = TimetablePeriod(id = 1, name = "1限", startMinute = 9 * 60, endMinute = 10 * 60, sortOrder = 1)
        val secondPeriod = TimetablePeriod(id = 2, name = "2限", startMinute = 11 * 60, endMinute = 12 * 60, sortOrder = 2)
        val term = TimetableTerm(id = 1, name = "前期", startDate = referenceDate.toEpochDay(), endDate = referenceDate.plusDays(10).toEpochDay())

        val useCase = makeUseCase(
            todaySessions = listOf(todaySessionEarly, todaySessionLate),
            weekSessions = listOf(todaySessionEarly, todaySessionLate, weekSession),
            goals = listOf(todayGoalOld, weeklyGoal, todayGoalNew),
            exams = listOf(
                Exam(id = 1, name = "期末", date = referenceDate.plusDays(10).toEpochDay()),
                Exam(id = 2, name = "小テスト", date = referenceDate.plusDays(3).toEpochDay())
            ),
            materials = listOf(material),
            subjects = listOf(subject),
            reviews = listOf(review(materialId = 10, problemNumber = 12, reviewedAt = nowMillis - DAY_MS - 1)),
            periods = listOf(secondPeriod, firstPeriod),
            entries = listOf(
                TimetableEntry(id = 1, termId = 1, dayOfWeek = StudyWeekday.MONDAY, periodId = 1, subjectName = "数学"),
                TimetableEntry(id = 2, termId = 1, dayOfWeek = StudyWeekday.MONDAY, periodId = 2, subjectName = "英語")
            ),
            terms = listOf(term)
        )

        val result = useCase().first()

        assertEquals(60L, result.todayStudyMinutes)
        assertEquals(listOf(2L, 1L), result.todaySessions.map { it.id })
        assertEquals(90, result.todayGoal?.targetMinutes)
        assertEquals(420, result.weeklyGoal?.targetMinutes)
        assertEquals(100L, result.weeklyStudyMinutes)
        assertEquals(listOf("小テスト", "期末"), result.upcomingExams.map { it.name })
        assertEquals("数学", result.timetableLesson?.entry?.subjectName)
        assertEquals("英語", result.upcomingTimetableLesson?.entry?.subjectName)
        assertEquals(1, result.todayReviewProblems.size)
        assertEquals("数学問題集", result.todayReviewProblems.first().materialName)
        assertEquals("数学", result.todayReviewProblems.first().subjectName)
        assertEquals("12問", result.todayReviewProblems.first().problemLabel)
    }

    @Test
    fun `today review problems use latest record and exclude good deleted and too recent records`() = runTest {
        val material = Material(id = 10, name = "数学問題集", subjectId = 20)
        val deletedMaterial = material.copy(id = 11, name = "削除済み", deletedAt = nowMillis)
        val subject = Subject(id = 20, name = "数学", color = 0x4CAF50)
        val latestGoodWins = review(materialId = 10, problemNumber = 13, reviewedAt = nowMillis - DAY_MS * 3)
        val useCase = makeUseCase(
            materials = listOf(material, deletedMaterial),
            subjects = listOf(subject),
            reviews = listOf(
                review(materialId = 10, problemNumber = 12, reviewedAt = nowMillis - DAY_MS - 1),
                review(materialId = 10, problemNumber = 99, reviewedAt = nowMillis - 10_000),
                latestGoodWins,
                latestGoodWins.copy(syncId = "latest-good", reviewedAt = nowMillis - DAY_MS - 1, rating = ProblemReviewRating.GOOD),
                review(materialId = 11, problemNumber = 20, reviewedAt = nowMillis - DAY_MS - 1)
            )
        )

        val result = useCase().first()

        assertEquals(listOf(12), result.todayReviewProblems.map { it.problemNumber })
        assertEquals("12問", result.todayReviewProblems.single().problemLabel)
    }

    @Test
    fun `home data leaves timetable lessons empty when periods are invalid or inactive`() = runTest {
        val useCase = makeUseCase(
            periods = listOf(TimetablePeriod(id = 1, name = "壊れた枠", startMinute = 600, endMinute = 600, sortOrder = 1)),
            entries = listOf(TimetableEntry(id = 1, dayOfWeek = StudyWeekday.MONDAY, periodId = 1, subjectName = "数学")),
            terms = listOf(TimetableTerm(id = 1, name = "前期", startDate = referenceDate.toEpochDay(), endDate = referenceDate.toEpochDay()))
        )

        val result = useCase().first()

        assertNull(result.timetableLesson)
        assertNull(result.upcomingTimetableLesson)
    }

    private fun makeUseCase(
        todaySessions: List<StudySession> = emptyList(),
        weekSessions: List<StudySession> = emptyList(),
        goals: List<Goal> = emptyList(),
        exams: List<Exam> = emptyList(),
        materials: List<Material> = emptyList(),
        subjects: List<Subject> = emptyList(),
        reviews: List<ProblemReviewRecord> = emptyList(),
        periods: List<TimetablePeriod> = emptyList(),
        entries: List<TimetableEntry> = emptyList(),
        terms: List<TimetableTerm> = emptyList()
    ): GetHomeDataUseCase {
        val studySessionRepository = mockk<StudySessionRepository>()
        val materialRepository = mockk<MaterialRepository>()
        val subjectRepository = mockk<SubjectRepository>()
        val problemReviewRepository = mockk<ProblemReviewRepository>()
        val goalRepository = mockk<GoalRepository>()
        val examRepository = mockk<ExamRepository>()
        val timetableRepository = mockk<TimetableRepository>()

        every { studySessionRepository.getSessionsBetweenDates(todayStart, todayStart + DAY_MS) } returns
            flowOf(Result.Success(todaySessions))
        every { studySessionRepository.getSessionsBetweenDates(weekStart, weekStart + WEEK_MS) } returns
            flowOf(Result.Success(weekSessions))
        every { goalRepository.getAllGoals() } returns flowOf(Result.Success(goals))
        every { examRepository.getUpcomingExams() } returns flowOf(Result.Success(exams))
        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(materials))
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(subjects))
        every { problemReviewRepository.getActiveReviewRecords() } returns flowOf(Result.Success(reviews))
        every { timetableRepository.getAllPeriods() } returns flowOf(Result.Success(periods))
        every { timetableRepository.getAllEntries() } returns flowOf(Result.Success(entries))
        every { timetableRepository.getAllTerms() } returns flowOf(Result.Success(terms))

        return GetHomeDataUseCase(
            studySessionRepository = studySessionRepository,
            materialRepository = materialRepository,
            subjectRepository = subjectRepository,
            problemReviewRepository = problemReviewRepository,
            goalRepository = goalRepository,
            examRepository = examRepository,
            timetableRepository = timetableRepository,
            clock = FixedClock(nowMillis, zoneId)
        )
    }

    private fun session(id: Long, day: LocalDate, hour: Int, minutes: Long, subjectName: String): StudySession {
        val start = day.atTime(hour, 0).atZone(zoneId).toInstant().toEpochMilli()
        return StudySession(
            id = id,
            syncId = "session-$id",
            subjectId = id,
            subjectName = subjectName,
            materialName = "教材$id",
            startTime = start,
            endTime = start + minutes * 60_000
        )
    }

    private fun goal(
        id: Long,
        type: GoalType,
        targetMinutes: Int,
        day: StudyWeekday?,
        updatedAt: Long
    ) = Goal(
        id = id,
        syncId = "goal-$id",
        type = type,
        targetMinutes = targetMinutes,
        dayOfWeek = day,
        createdAt = id,
        updatedAt = updatedAt
    )

    private fun review(
        materialId: Long,
        problemNumber: Int,
        reviewedAt: Long,
        rating: ProblemReviewRating = ProblemReviewRating.AGAIN
    ) = ProblemReviewRecord(
        syncId = "review-$materialId-$problemNumber-$reviewedAt",
        problemId = ProblemReviewRecord.problemId(materialId, problemNumber),
        materialId = materialId,
        materialSyncId = "material-$materialId",
        problemNumber = problemNumber,
        reviewedAt = reviewedAt,
        rating = rating,
        nextReviewDate = reviewedAt,
        consecutiveCorrectCount = 0,
        wrongCount = 1,
        createdAt = reviewedAt,
        updatedAt = reviewedAt
    )

    private companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
        private const val WEEK_MS = 7 * DAY_MS
    }
}
