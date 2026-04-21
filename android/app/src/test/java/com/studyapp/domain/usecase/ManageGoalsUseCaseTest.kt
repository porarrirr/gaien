package com.studyapp.domain.usecase

import app.cash.turbine.test
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.LogMock
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.time.DayOfWeek
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ManageGoalsUseCaseTest {

    private lateinit var goalRepository: GoalRepository
    private lateinit var manageGoalsUseCase: ManageGoalsUseCase

    @Before
    fun setup() {
        LogMock.setup()
        goalRepository = mockk()
        manageGoalsUseCase = ManageGoalsUseCase(goalRepository)
    }

    @After
    fun teardown() {
        LogMock.teardown()
    }

    @Test
    fun `getDailyGoals returns weekday map`() = runTest {
        val mondayGoal = Goal(type = GoalType.DAILY, targetMinutes = 60, dayOfWeek = DayOfWeek.MONDAY)
        val tuesdayGoal = Goal(type = GoalType.DAILY, targetMinutes = 90, dayOfWeek = DayOfWeek.TUESDAY)

        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(listOf(mondayGoal, tuesdayGoal)))

        manageGoalsUseCase.getDailyGoals().test {
            val result = awaitItem()
            assertEquals(2, result.size)
            assertEquals(60, result[DayOfWeek.MONDAY]?.targetMinutes)
            assertEquals(90, result[DayOfWeek.TUESDAY]?.targetMinutes)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `getDailyGoal returns null when weekday goal is missing`() = runTest {
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))

        manageGoalsUseCase.getDailyGoal(DayOfWeek.SUNDAY).test {
            assertNull(awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `getActiveWeeklyGoal returns goal when exists`() = runTest {
        val goal = Goal(id = 2, type = GoalType.WEEKLY, targetMinutes = 600, isActive = true)

        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns flowOf(Result.Success(goal))

        manageGoalsUseCase.getActiveWeeklyGoal().test {
            val result = awaitItem()
            assertNotNull(result)
            assertEquals(600, result?.targetMinutes)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `updateDailyGoal creates new weekday goal when none exists`() = runTest {
        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(emptyList()))
        coEvery { goalRepository.insertGoal(any()) } returns Result.Success(1L)

        val result = manageGoalsUseCase.updateDailyGoal(DayOfWeek.WEDNESDAY, 120L)

        assertTrue(result.isSuccess)
    }

    @Test
    fun `updateDailyGoal updates existing weekday goal`() = runTest {
        val existingGoal = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 60,
            dayOfWeek = DayOfWeek.WEDNESDAY,
            isActive = true
        )

        every { goalRepository.getActiveGoals() } returns flowOf(Result.Success(listOf(existingGoal)))
        coEvery { goalRepository.updateGoal(any()) } returns Result.Success(Unit)

        val result = manageGoalsUseCase.updateDailyGoal(DayOfWeek.WEDNESDAY, 120L)

        assertTrue(result.isSuccess)
    }

    @Test
    fun `updateWeeklyGoal updates existing goal`() = runTest {
        val existingGoal = Goal(id = 2, type = GoalType.WEEKLY, targetMinutes = 300, isActive = true)

        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns flowOf(Result.Success(existingGoal))
        coEvery { goalRepository.updateGoal(any()) } returns Result.Success(Unit)

        val result = manageGoalsUseCase.updateWeeklyGoal(600L)

        assertTrue(result.isSuccess)
    }

    @Test
    fun `updateDailyGoal returns error when targetMinutes is zero`() = runTest {
        val result = manageGoalsUseCase.updateDailyGoal(DayOfWeek.MONDAY, 0L)
        assertTrue(result.isFailure)
    }

    @Test
    fun `deactivateGoal succeeds when goal exists`() = runTest {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 60, dayOfWeek = DayOfWeek.MONDAY, isActive = true)

        coEvery { goalRepository.getGoalById(1L) } returns Result.Success(goal)
        coEvery { goalRepository.updateGoal(any()) } returns Result.Success(Unit)

        val result = manageGoalsUseCase.deactivateGoal(1L)

        assertTrue(result.isSuccess)
    }

    @Test
    fun `deactivateGoal returns error when goal not found`() = runTest {
        coEvery { goalRepository.getGoalById(999L) } returns Result.Success(null)

        val result = manageGoalsUseCase.deactivateGoal(999L)

        assertTrue(result.isFailure)
        assertFalse(result.isSuccess)
    }
}
