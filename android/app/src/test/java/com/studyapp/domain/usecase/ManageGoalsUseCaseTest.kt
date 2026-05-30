package com.studyapp.domain.usecase

import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.LogMockRule
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ManageGoalsUseCaseTest {
    @get:Rule
    val logMock = LogMockRule()

    private val repository = mockk<GoalRepository>()
    private val useCase = ManageGoalsUseCase(repository)

    @Test
    fun `getDailyGoal selects latest active goal for requested weekday`() = runTest {
        val oldMonday = goal(id = 1, targetMinutes = 30, day = StudyWeekday.MONDAY, updatedAt = 100)
        val newMonday = goal(id = 2, targetMinutes = 45, day = StudyWeekday.MONDAY, updatedAt = 200)
        val tuesday = goal(id = 3, targetMinutes = 90, day = StudyWeekday.TUESDAY, updatedAt = 300)
        every { repository.getActiveGoals() } returns flowOf(Result.Success(listOf(oldMonday, tuesday, newMonday)))

        val result = useCase.getDailyGoal(StudyWeekday.MONDAY).first()

        assertEquals(newMonday, result)
    }

    @Test
    fun `updateDailyGoal creates new goal when weekday has no active goal`() = runTest {
        every { repository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        coEvery { repository.insertGoal(any()) } returns Result.Success(10)

        val result = useCase.updateDailyGoal(StudyWeekday.TUESDAY, 45)

        assertTrue(result is Result.Success)
        coVerify {
            repository.insertGoal(match {
                it.type == GoalType.DAILY &&
                    it.dayOfWeek == StudyWeekday.TUESDAY &&
                    it.targetMinutes == 45 &&
                    it.isActive
            })
        }
    }

    @Test
    fun `updateDailyGoal updates existing weekday goal instead of inserting`() = runTest {
        val current = goal(id = 7, targetMinutes = 20, day = StudyWeekday.FRIDAY)
        every { repository.getActiveGoals() } returns flowOf(Result.Success(listOf(current)))
        coEvery { repository.updateGoal(any()) } returns Result.Success(Unit)

        val result = useCase.updateDailyGoal(StudyWeekday.FRIDAY, 80)

        assertTrue(result is Result.Success)
        coVerify {
            repository.updateGoal(match {
                it.id == 7L &&
                    it.type == GoalType.DAILY &&
                    it.dayOfWeek == StudyWeekday.FRIDAY &&
                    it.targetMinutes == 80
            })
        }
        coVerify(exactly = 0) { repository.insertGoal(any()) }
    }

    @Test
    fun `updateWeeklyGoal propagates active goal lookup error`() = runTest {
        val failure = Result.Error(IllegalStateException("db"), "目標の読み込みに失敗しました")
        every { repository.getActiveGoalByType(GoalType.WEEKLY) } returns flowOf(failure)

        val result = useCase.updateWeeklyGoal(300)

        assertTrue(result is Result.Error)
        assertEquals("目標の読み込みに失敗しました", result.getErrorMessage())
        coVerify(exactly = 0) { repository.updateGoal(any()) }
        coVerify(exactly = 0) { repository.insertGoal(any()) }
    }

    @Test
    fun `updateWeeklyGoal rejects non positive target minutes`() = runTest {
        val result = useCase.updateWeeklyGoal(0)

        assertTrue(result is Result.Error)
        assertEquals("目標時間は0より大きくしてください", result.getErrorMessage())
    }

    private fun goal(
        id: Long,
        targetMinutes: Int,
        day: StudyWeekday?,
        updatedAt: Long = 1_000
    ): Goal = Goal(
        id = id,
        syncId = "goal-$id",
        type = GoalType.DAILY,
        targetMinutes = targetMinutes,
        dayOfWeek = day,
        createdAt = id,
        updatedAt = updatedAt
    )
}
