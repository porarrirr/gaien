package com.studyapp.presentation.materials

import androidx.lifecycle.SavedStateHandle
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalCoroutinesApi::class)
class MaterialHistoryViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var materialRepository: MaterialRepository
    private lateinit var subjectRepository: SubjectRepository
    private lateinit var studySessionRepository: StudySessionRepository

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        materialRepository = mockk()
        subjectRepository = mockk()
        studySessionRepository = mockk()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial selection uses latest study date and filters material sessions`() = runTest {
        val material = Material(id = 7L, name = "英文法", subjectId = 2L, totalPages = 100, currentPage = 40)
        val subject = Subject(id = 2L, name = "英語", color = 0x4CAF50)
        val oldSession = session(
            id = 1L,
            materialId = 7L,
            date = LocalDate.of(2026, 3, 10),
            startHour = 9,
            minutes = 30,
            note = "1章"
        )
        val latestSession = session(
            id = 2L,
            materialId = 7L,
            date = LocalDate.of(2026, 3, 12),
            startHour = 20,
            minutes = 45,
            note = "2章"
        )

        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(listOf(material)))
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(listOf(subject)))
        every { studySessionRepository.getSessionsByMaterial(7L) } returns
            flowOf(Result.Success(listOf(oldSession, latestSession)))

        val viewModel = MaterialHistoryViewModel(
            SavedStateHandle(mapOf("materialId" to 7L)),
            materialRepository,
            subjectRepository,
            studySessionRepository
        )
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(material, state.material)
        assertEquals(subject, state.subject)
        assertEquals(LocalDate.of(2026, 3, 12), state.selectedDate)
        assertEquals(75L, state.totalMinutes)
        assertEquals(1, state.selectedDateSessions.size)
        assertEquals("2章", state.selectedDateSessions.first().note)
        assertEquals(30L, state.studyMinutesByDay[10])
        assertEquals(45L, state.studyMinutesByDay[12])
    }

    @Test
    fun `selectDate updates selected sessions and daily total`() = runTest {
        val material = Material(id = 7L, name = "英文法", subjectId = 2L)
        val targetDate = LocalDate.of(2026, 3, 9)
        val sessions = listOf(
            session(id = 1L, materialId = 7L, date = targetDate, startHour = 9, minutes = 20, note = "p10"),
            session(id = 2L, materialId = 7L, date = targetDate, startHour = 11, minutes = 40, note = "p11"),
            session(id = 3L, materialId = 7L, date = LocalDate.of(2026, 3, 10), startHour = 11, minutes = 15)
        )

        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(listOf(material)))
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getSessionsByMaterial(7L) } returns flowOf(Result.Success(sessions))

        val viewModel = MaterialHistoryViewModel(
            SavedStateHandle(mapOf("materialId" to 7L)),
            materialRepository,
            subjectRepository,
            studySessionRepository
        )
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectDate(targetDate)

        val state = viewModel.uiState.value
        assertEquals(targetDate, state.selectedDate)
        assertEquals(60L, state.selectedDateMinutes)
        assertEquals(listOf(1L, 2L), state.selectedDateSessions.map { it.id })
    }

    @Test
    fun `empty history selects today and has no latest study date`() = runTest {
        val material = Material(id = 7L, name = "英文法", subjectId = 2L)

        every { materialRepository.getAllMaterials() } returns flowOf(Result.Success(listOf(material)))
        every { subjectRepository.getAllSubjects() } returns flowOf(Result.Success(emptyList()))
        every { studySessionRepository.getSessionsByMaterial(7L) } returns flowOf(Result.Success(emptyList()))

        val viewModel = MaterialHistoryViewModel(
            SavedStateHandle(mapOf("materialId" to 7L)),
            materialRepository,
            subjectRepository,
            studySessionRepository
        )
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(LocalDate.now(), state.selectedDate)
        assertNull(state.latestStudyDate)
        assertEquals(0L, state.totalMinutes)
        assertEquals(emptyList<StudySession>(), state.selectedDateSessions)
    }

    private fun session(
        id: Long,
        materialId: Long,
        date: LocalDate,
        startHour: Int,
        minutes: Long,
        note: String? = null
    ): StudySession {
        val start = date.atTime(startHour, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val end = start + minutes * 60_000
        return StudySession(
            id = id,
            materialId = materialId,
            materialName = "英文法",
            subjectId = 2L,
            subjectName = "英語",
            startTime = start,
            endTime = end,
            note = note
        )
    }
}
