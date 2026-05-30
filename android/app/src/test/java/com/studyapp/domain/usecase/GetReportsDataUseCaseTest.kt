package com.studyapp.domain.usecase

import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.FixedClock
import com.studyapp.testutil.LogMockRule
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.WeekFields
import java.util.Locale
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class GetReportsDataUseCaseTest {
    @get:Rule
    val logMock = LogMockRule()

    private val zoneId = ZoneId.systemDefault()
    private val reference = LocalDateTime.of(2026, 5, 6, 20, 0)
    private val nowMillis = reference.atZone(zoneId).toInstant().toEpochMilli()

    @Test
    fun `invoke returns exact daily weekly monthly and streak aggregates`() = runTest {
        val sessions = listOf(
            session(1, LocalDate.of(2026, 5, 6), 8, 60),
            session(2, LocalDate.of(2026, 5, 6), 11, 30),
            session(3, LocalDate.of(2026, 5, 5), 9, 45),
            session(4, LocalDate.of(2026, 5, 4), 18, 15),
            session(5, LocalDate.of(2026, 4, 28), 7, 120),
            session(6, LocalDate.of(2026, 4, 29), 7, 60),
            session(7, LocalDate.of(2026, 4, 30), 7, 30),
            session(8, LocalDate.of(2026, 5, 1), 7, 30),
            session(9, LocalDate.of(2026, 3, 10), 7, 180)
        )
        val useCase = GetReportsDataUseCase(
            studySessionRepository = FakeStudySessionRepository(sessions),
            clock = FixedClock(nowMillis, zoneId)
        )

        val result = useCase()

        assertEquals(listOf(120L, 60L, 30L, 30L, 15L, 45L, 90L), result.dailyData.map { it.totalMinutes })
        assertEquals(3, result.streak)
        assertEquals(4, result.bestStreak)

        val currentWeekStart = weekStartMillis(LocalDate.of(2026, 5, 6))
        val currentWeek = result.weeklyData.single { it.weekStart == currentWeekStart }
        assertEquals(150L, currentWeek.totalMinutes)
        assertEquals(21L, currentWeek.averageMinutes)

        val mayStart = monthStartMillis(LocalDate.of(2026, 5, 1))
        val may = result.monthlyData.single { it.monthStart == mayStart }
        assertEquals(180L, may.totalMinutes)
        assertEquals(4, may.activeDays)
    }

    @Test
    fun `invoke returns empty report when repositories fail`() = runTest {
        val useCase = GetReportsDataUseCase(
            studySessionRepository = FakeStudySessionRepository(
                sessions = emptyList(),
                result = Result.Error(IllegalStateException("db"), "読み込み失敗")
            ),
            clock = FixedClock(nowMillis, zoneId)
        )

        val result = useCase()

        assertTrue(result.dailyData.isEmpty())
        assertTrue(result.weeklyData.isEmpty())
        assertTrue(result.monthlyData.isEmpty())
        assertEquals(0, result.streak)
        assertEquals(0, result.bestStreak)
    }

    private fun session(id: Long, date: LocalDate, hour: Int, minutes: Long): StudySession {
        val start = date.atTime(hour, 0).atZone(zoneId).toInstant().toEpochMilli()
        return StudySession(
            id = id,
            syncId = "session-$id",
            subjectId = 1,
            subjectName = "数学",
            startTime = start,
            endTime = start + minutes * 60_000
        )
    }

    private fun weekStartMillis(date: LocalDate): Long {
        val firstDay = WeekFields.of(Locale.getDefault()).firstDayOfWeek
        return date.with(firstDay).toEpochDay() * DAY_MS
    }

    private fun monthStartMillis(date: LocalDate): Long =
        date.withDayOfMonth(1).toEpochDay() * DAY_MS

    private companion object {
        private const val DAY_MS = 24 * 60 * 60 * 1000L
    }

    private class FakeStudySessionRepository(
        private val sessions: List<StudySession>,
        private val result: Result<List<StudySession>>? = null
    ) : StudySessionRepository {
        override fun getAllSessions(): Flow<Result<List<StudySession>>> =
            flowOf(result ?: Result.Success(sessions))

        override fun getSessionsByDate(date: Long): Flow<Result<List<StudySession>>> =
            flowOf(result ?: Result.Success(sessions.filter { it.date == date }))

        override fun getSessionsBetweenDates(startDate: Long, endDate: Long): Flow<Result<List<StudySession>>> =
            flowOf(result ?: Result.Success(sessions.filter { it.startTime >= startDate && it.startTime < endDate }))

        override fun getSessionsBySubject(subjectId: Long): Flow<Result<List<StudySession>>> =
            flowOf(result ?: Result.Success(sessions.filter { it.subjectId == subjectId }))

        override fun getSessionsByMaterial(materialId: Long): Flow<Result<List<StudySession>>> =
            flowOf(result ?: Result.Success(sessions.filter { it.materialId == materialId }))

        override suspend fun getTotalDurationByDate(date: Long): Result<Long> =
            Result.Success(sessions.filter { it.date == date }.sumOf { it.duration })

        override suspend fun getTotalDurationBetweenDates(startDate: Long, endDate: Long): Result<Long> =
            Result.Success(sessions.filter { it.startTime >= startDate && it.startTime < endDate }.sumOf { it.duration })

        override suspend fun getTotalDurationBySubjectBetweenDates(
            subjectId: Long,
            startDate: Long,
            endDate: Long
        ): Result<Long> = Result.Success(
            sessions.filter { it.subjectId == subjectId && it.startTime >= startDate && it.startTime < endDate }
                .sumOf { it.duration }
        )

        override suspend fun getSessionById(id: Long): Result<StudySession?> =
            Result.Success(sessions.firstOrNull { it.id == id })

        override suspend fun insertSession(session: StudySession): Result<Long> =
            error("not used")

        override suspend fun updateSession(session: StudySession): Result<Unit> =
            error("not used")

        override suspend fun deleteSession(session: StudySession): Result<Unit> =
            error("not used")
    }
}
