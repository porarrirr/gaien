package com.studyapp.presentation.calendar

import com.studyapp.domain.model.StudySession
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.util.Result
import io.mockk.coEvery
import io.mockk.coVerify
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
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class CalendarViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var studySessionRepository: StudySessionRepository

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        studySessionRepository = mockk()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `selectDate loads sorted sessions and total minutes`() = runTest {
        val dayStart = Calendar.getInstance().run {
            set(2026, Calendar.MARCH, 12, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
            timeInMillis
        }
        val selectedDate = Date(dayStart + 9 * 60 * 60 * 1000L)
        val monthSessions = listOf(
            session(
                id = 10L,
                startTime = dayStart + 9 * 60 * 60 * 1000L,
                endTime = dayStart + 10 * 60 * 60 * 1000L
            ),
            session(
                id = 11L,
                startTime = dayStart + 13 * 60 * 60 * 1000L,
                endTime = dayStart + 15 * 60 * 60 * 1000L
            )
        )
        val daySessions = listOf(
            session(
                id = 2L,
                subjectName = "英語",
                startTime = dayStart + 14 * 60 * 60 * 1000L,
                endTime = dayStart + 15 * 60 * 60 * 1000L
            ),
            session(
                id = 1L,
                subjectName = "数学",
                startTime = dayStart + 9 * 60 * 60 * 1000L,
                endTime = dayStart + 11 * 60 * 60 * 1000L
            )
        )

        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(monthSessions))
        every { studySessionRepository.getSessionsByDate(dayStart) } returns
            flowOf(Result.Success(daySessions))

        val viewModel = CalendarViewModel(studySessionRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectDate(selectedDate)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(180L, viewModel.uiState.value.studyDataByDate[12])
        assertEquals(listOf(1L, 2L), viewModel.uiState.value.selectedDateSessions.map { it.id })
        assertEquals(180L, viewModel.uiState.value.selectedDateMinutes)
    }

    @Test
    fun `updateSessionNote stores blank note as null`() = runTest {
        every { studySessionRepository.getSessionsBetweenDates(any(), any()) } returns
            flowOf(Result.Success(emptyList()))
        coEvery { studySessionRepository.updateSession(any()) } returns Result.Success(Unit)

        val viewModel = CalendarViewModel(studySessionRepository)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.updateSessionNote(
            session(
                id = 9L,
                startTime = 1_710_000_000_000L,
                endTime = 1_710_000_180_000L,
                note = "before"
            ),
            "   "
        )
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify {
            studySessionRepository.updateSession(
                match { updated ->
                    updated.id == 9L && updated.note == null
                }
            )
        }
        assertNull(viewModel.uiState.value.updatingSessionId)
    }

    private fun session(
        id: Long,
        subjectName: String = "",
        startTime: Long,
        endTime: Long,
        note: String? = null
    ): StudySession {
        return StudySession(
            id = id,
            subjectId = 1L,
            subjectName = subjectName,
            startTime = startTime,
            endTime = endTime,
            note = note,
            materialId = null
        )
    }
}
