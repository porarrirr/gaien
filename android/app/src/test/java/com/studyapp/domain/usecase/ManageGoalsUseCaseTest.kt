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
    fun `getActiveDailyGoal returns goal when exists`() = runTest {
        val goal = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 60,
            isActive = true
        )
        
        every { goalRepository.getActiveGoalByType(GoalType.DAILY) } returns
            flowOf(Result.Success(goal))
        
        manageGoalsUseCase.getActiveDailyGoal().test {
            val result = awaitItem()
            
            assertNotNull(result)
            assertEquals(GoalType.DAILY, result?.type)
            assertEquals(60, result?.targetMinutes)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActiveWeeklyGoal returns goal when exists`() = runTest {
        val goal = Goal(
            id = 2,
            type = GoalType.WEEKLY,
            targetMinutes = 600,
            isActive = true
        )
        
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(goal))
        
        manageGoalsUseCase.getActiveWeeklyGoal().test {
            val result = awaitItem()
            
            assertNotNull(result)
            assertEquals(GoalType.WEEKLY, result?.type)
            assertEquals(600, result?.targetMinutes)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActiveDailyGoal returns null when no goal exists`() = runTest {
        every { goalRepository.getActiveGoalByType(GoalType.DAILY) } returns
            flowOf(Result.Success(null))
        
        manageGoalsUseCase.getActiveDailyGoal().test {
            val result = awaitItem()
            
            assertNull(result)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActiveWeeklyGoal returns null when no goal exists`() = runTest {
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(null))
        
        manageGoalsUseCase.getActiveWeeklyGoal().test {
            val result = awaitItem()
            
            assertNull(result)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActiveDailyGoal handles repository error gracefully`() = runTest {
        every { goalRepository.getActiveGoalByType(GoalType.DAILY) } returns
            flowOf(Result.Error(Exception("Database error")))
        
        manageGoalsUseCase.getActiveDailyGoal().test {
            val result = awaitItem()
            
            assertNull(result)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `updateDailyGoal creates new goal when none exists`() = runTest {
        val targetMinutes = 120L
        
        every { goalRepository.getActiveGoalByType(GoalType.DAILY) } returns
            flowOf(Result.Success(null))
        coEvery { goalRepository.insertGoal(any()) } returns Result.Success(1L)
        
        val result = manageGoalsUseCase.updateDailyGoal(targetMinutes)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updateDailyGoal updates existing goal`() = runTest {
        val existingGoal = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 60,
            isActive = true
        )
        val newTargetMinutes = 120L
        
        every { goalRepository.getActiveGoalByType(GoalType.DAILY) } returns
            flowOf(Result.Success(existingGoal))
        coEvery { goalRepository.updateGoal(any()) } returns Result.Success(Unit)
        
        val result = manageGoalsUseCase.updateDailyGoal(newTargetMinutes)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updateWeeklyGoal creates new goal when none exists`() = runTest {
        val targetMinutes = 600L
        
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(null))
        coEvery { goalRepository.insertGoal(any()) } returns Result.Success(1L)
        
        val result = manageGoalsUseCase.updateWeeklyGoal(targetMinutes)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updateWeeklyGoal updates existing goal`() = runTest {
        val existingGoal = Goal(
            id = 2,
            type = GoalType.WEEKLY,
            targetMinutes = 300,
            isActive = true
        )
        val newTargetMinutes = 600L
        
        every { goalRepository.getActiveGoalByType(GoalType.WEEKLY) } returns
            flowOf(Result.Success(existingGoal))
        coEvery { goalRepository.updateGoal(any()) } returns Result.Success(Unit)
        
        val result = manageGoalsUseCase.updateWeeklyGoal(newTargetMinutes)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updateDailyGoal returns error when targetMinutes is zero`() = runTest {
        val result = manageGoalsUseCase.updateDailyGoal(0L)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updateDailyGoal returns error when targetMinutes is negative`() = runTest {
        val result = manageGoalsUseCase.updateDailyGoal(-10L)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updateWeeklyGoal returns error when targetMinutes is zero`() = runTest {
        val result = manageGoalsUseCase.updateWeeklyGoal(0L)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `deactivateGoal succeeds when goal exists`() = runTest {
        val goal = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 60,
            isActive = true
        )
        
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
    }
    
    @Test
    fun `deactivateGoal handles repository error`() = runTest {
        coEvery { goalRepository.getGoalById(1L) } returns
            Result.Error(Exception("Database error"))
        
        val result = manageGoalsUseCase.deactivateGoal(1L)
        
        assertTrue(result.isFailure)
    }
}