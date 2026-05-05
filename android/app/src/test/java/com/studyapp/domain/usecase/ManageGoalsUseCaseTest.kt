package com.studyapp.domain.usecase

import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.util.Result
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ManageGoalsUseCaseTest {
    @Test
    fun `getDailyGoal selects goal by StudyWeekday`() = runTest {
        val repository = mockk<GoalRepository>()
        val monday = Goal(type = GoalType.DAILY, targetMinutes = 30, dayOfWeek = StudyWeekday.MONDAY)
        every { repository.getActiveGoals() } returns flowOf(Result.Success(listOf(monday)))

        val result = ManageGoalsUseCase(repository).getDailyGoal(StudyWeekday.MONDAY).first()

        assertEquals(monday, result)
    }

    @Test
    fun `updateDailyGoal creates new goal when none exists`() = runTest {
        val repository = mockk<GoalRepository>()
        every { repository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        coEvery { repository.insertGoal(any()) } returns Result.Success(1)

        val result = ManageGoalsUseCase(repository).updateDailyGoal(StudyWeekday.TUESDAY, 45)

        assertTrue(result is Result.Success)
        coVerify {
            repository.insertGoal(match {
                it.type == GoalType.DAILY &&
                    it.dayOfWeek == StudyWeekday.TUESDAY &&
                    it.targetMinutes == 45
            })
        }
    }
}
