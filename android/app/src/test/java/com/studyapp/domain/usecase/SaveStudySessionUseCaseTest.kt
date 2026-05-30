package com.studyapp.domain.usecase

import com.studyapp.domain.model.Material
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.FixedClock
import com.studyapp.testutil.LogMockRule
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class SaveStudySessionUseCaseTest {
    @get:Rule
    val logMock = LogMockRule()

    private val studySessionRepository = mockk<StudySessionRepository>()
    private val subjectRepository = mockk<SubjectRepository>()
    private val materialRepository = mockk<MaterialRepository>()
    private val clock = FixedClock(1_700_000_000_000L)
    private val useCase = SaveStudySessionUseCase(
        studySessionRepository,
        subjectRepository,
        materialRepository,
        clock
    )

    @Test
    fun `invoke resolves ids and sync ids and saves exact generated session`() = runTest {
        val captured = slot<StudySession>()
        coEvery { subjectRepository.getSubjectById(1) } returns Result.Success(subject())
        coEvery { materialRepository.getMaterialById(2) } returns Result.Success(material())
        coEvery { studySessionRepository.insertSession(capture(captured)) } returns Result.Success(99)

        val result = useCase(
            subjectId = 1,
            materialId = 2,
            duration = 45 * 60_000L,
            sessionType = StudySessionType.TIMER
        )

        assertEquals(99L, result.getOrNull())
        val session = captured.captured
        assertEquals(1L, session.subjectId)
        assertEquals("subject-sync", session.subjectSyncId)
        assertEquals("数学", session.subjectName)
        assertEquals(2L, session.materialId)
        assertEquals("material-sync", session.materialSyncId)
        assertEquals("問題集", session.materialName)
        assertEquals(StudySessionType.TIMER, session.sessionType)
        assertEquals(clock.currentTimeMillis() - 45 * 60_000L, session.startTime)
        assertEquals(clock.currentTimeMillis(), session.endTime)
        assertEquals(listOf(StudySessionInterval(clock.currentTimeMillis() - 45 * 60_000L, clock.currentTimeMillis())), session.intervals)
    }

    @Test
    fun `invoke resolves subject and material by sync id when local ids are missing`() = runTest {
        val captured = slot<StudySession>()
        coEvery { subjectRepository.getSubjectBySyncId("subject-sync") } returns Result.Success(subject())
        coEvery { materialRepository.getMaterialBySyncId("material-sync") } returns Result.Success(material())
        coEvery { studySessionRepository.insertSession(capture(captured)) } returns Result.Success(10)

        val result = useCase(
            subjectId = null,
            subjectSyncId = "subject-sync",
            materialId = null,
            materialSyncId = "material-sync",
            duration = 30_000L
        )

        assertTrue(result is Result.Success)
        assertEquals(1L, captured.captured.subjectId)
        assertEquals(2L, captured.captured.materialId)
    }

    @Test
    fun `invoke preserves explicit intervals and uses their boundaries`() = runTest {
        val intervals = listOf(
            StudySessionInterval(1_000, 11_000),
            StudySessionInterval(20_000, 50_000)
        )
        val captured = slot<StudySession>()
        coEvery { subjectRepository.getSubjectById(1) } returns Result.Success(subject())
        coEvery { studySessionRepository.insertSession(capture(captured)) } returns Result.Success(7)

        val result = useCase(
            subjectId = 1,
            materialId = null,
            duration = 40_000,
            intervals = intervals,
            sessionType = StudySessionType.STOPWATCH
        )

        assertTrue(result is Result.Success)
        assertEquals(intervals, captured.captured.intervals)
        assertEquals(1_000L, captured.captured.startTime)
        assertEquals(50_000L, captured.captured.endTime)
        assertNull(captured.captured.materialId)
        assertEquals("", captured.captured.materialName)
    }

    @Test
    fun `invoke rejects non positive duration before resolving repositories`() = runTest {
        val result = useCase(subjectId = 1, materialId = null, duration = 0)

        assertTrue(result is Result.Error)
        assertEquals("学習時間は0より大きくしてください", result.getErrorMessage())
        coVerify(exactly = 0) { subjectRepository.getSubjectById(any()) }
        coVerify(exactly = 0) { studySessionRepository.insertSession(any()) }
    }

    @Test
    fun `invoke returns subject missing error without saving`() = runTest {
        coEvery { subjectRepository.getSubjectById(404) } returns Result.Success(null)

        val result = useCase(subjectId = 404, materialId = null, duration = 60_000)

        assertTrue(result is Result.Error)
        assertEquals("科目が見つかりません", result.getErrorMessage())
        coVerify(exactly = 0) { studySessionRepository.insertSession(any()) }
    }

    @Test
    fun `invoke passes repository save error through`() = runTest {
        coEvery { subjectRepository.getSubjectById(1) } returns Result.Success(subject())
        coEvery { studySessionRepository.insertSession(any()) } returns
            Result.Error(IllegalStateException("db"), "データベースエラー")

        val result = useCase(subjectId = 1, materialId = null, duration = 60_000)

        assertTrue(result is Result.Error)
        assertEquals("データベースエラー", result.getErrorMessage())
    }

    private fun subject() = Subject(
        id = 1,
        syncId = "subject-sync",
        name = "数学",
        color = 0x336699
    )

    private fun material() = Material(
        id = 2,
        syncId = "material-sync",
        name = "問題集",
        subjectId = 1,
        subjectSyncId = "subject-sync"
    )
}
