package com.studyapp.domain.usecase

import app.cash.turbine.test
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.WeeklyPlanSummary
import com.studyapp.domain.repository.PlanRepository
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
import java.time.DayOfWeek

class ManagePlansUseCaseTest {
    
    private lateinit var planRepository: PlanRepository
    private lateinit var managePlansUseCase: ManagePlansUseCase
    
    @Before
    fun setup() {
        LogMock.setup()
        planRepository = mockk()
        managePlansUseCase = ManagePlansUseCase(planRepository)
    }
    
    @After
    fun teardown() {
        LogMock.teardown()
    }
    
    private fun createPlan(
        id: Long = 1L,
        name: String = "Test Plan",
        startDate: Long = System.currentTimeMillis(),
        endDate: Long = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L
    ): StudyPlan {
        return StudyPlan(
            id = id,
            name = name,
            startDate = startDate,
            endDate = endDate,
            isActive = true,
            createdAt = System.currentTimeMillis()
        )
    }
    
    private fun createPlanItem(
        id: Long = 1L,
        planId: Long = 1L,
        subjectId: Long = 1L,
        dayOfWeek: DayOfWeek = DayOfWeek.MONDAY,
        targetMinutes: Int = 60
    ): PlanItem {
        return PlanItem(
            id = id,
            planId = planId,
            subjectId = subjectId,
            dayOfWeek = dayOfWeek,
            targetMinutes = targetMinutes
        )
    }
    
    @Test
    fun `getActivePlan returns plan when exists`() = runTest {
        val plan = createPlan()
        
        every { planRepository.getActivePlan() } returns flowOf(Result.Success(plan))
        
        managePlansUseCase.getActivePlan().test {
            val result = awaitItem()
            
            assertNotNull(result)
            assertEquals("Test Plan", result?.name)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActivePlan returns null when no active plan`() = runTest {
        every { planRepository.getActivePlan() } returns flowOf(Result.Success(null))
        
        managePlansUseCase.getActivePlan().test {
            val result = awaitItem()
            
            assertNull(result)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getActivePlan handles repository error gracefully`() = runTest {
        every { planRepository.getActivePlan() } returns
            flowOf(Result.Error(Exception("Database error")))
        
        managePlansUseCase.getActivePlan().test {
            val result = awaitItem()
            
            assertNull(result)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `createPlan succeeds with valid data`() = runTest {
        val plan = createPlan()
        val items = listOf(createPlanItem())
        
        coEvery { planRepository.createPlan(plan, items) } returns Result.Success(1L)
        
        val result = managePlansUseCase.createPlan(plan, items)
        
        assertTrue(result.isSuccess)
        assertEquals(1L, result.getOrNull())
    }
    
    @Test
    fun `createPlan returns error when name is blank`() = runTest {
        val plan = createPlan(name = "")
        val items = listOf(createPlanItem())
        
        val result = managePlansUseCase.createPlan(plan, items)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `createPlan returns error when start date is after end date`() = runTest {
        val plan = createPlan(
            startDate = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L,
            endDate = System.currentTimeMillis()
        )
        val items = listOf(createPlanItem())
        
        val result = managePlansUseCase.createPlan(plan, items)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `createPlan returns error when items list is empty`() = runTest {
        val plan = createPlan()
        val items = emptyList<PlanItem>()
        
        val result = managePlansUseCase.createPlan(plan, items)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `createPlan handles repository error`() = runTest {
        val plan = createPlan()
        val items = listOf(createPlanItem())
        
        coEvery { planRepository.createPlan(plan, items) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.createPlan(plan, items)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updatePlan succeeds with valid data`() = runTest {
        val plan = createPlan()
        
        coEvery { planRepository.updatePlan(plan) } returns Result.Success(Unit)
        
        val result = managePlansUseCase.updatePlan(plan)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updatePlan returns error when name is blank`() = runTest {
        val plan = createPlan(name = "")
        
        val result = managePlansUseCase.updatePlan(plan)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updatePlan returns error when start date equals end date`() = runTest {
        val now = System.currentTimeMillis()
        val plan = createPlan(startDate = now, endDate = now)
        
        val result = managePlansUseCase.updatePlan(plan)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updatePlan handles repository error`() = runTest {
        val plan = createPlan()
        
        coEvery { planRepository.updatePlan(plan) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.updatePlan(plan)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `deletePlan succeeds`() = runTest {
        val plan = createPlan()
        
        coEvery { planRepository.deletePlan(plan) } returns Result.Success(Unit)
        
        val result = managePlansUseCase.deletePlan(plan)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `deletePlan handles repository error`() = runTest {
        val plan = createPlan()
        
        coEvery { planRepository.deletePlan(plan) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.deletePlan(plan)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `getWeeklyPlanSummary returns summary when plan exists`() = runTest {
        val summary = WeeklyPlanSummary(
            weekStart = System.currentTimeMillis(),
            weekEnd = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L,
            totalTargetMinutes = 600,
            totalActualMinutes = 300,
            dailyBreakdown = emptyMap()
        )
        
        coEvery { planRepository.getWeeklyPlanSummary(1L) } returns Result.Success(summary)
        
        val result = managePlansUseCase.getWeeklyPlanSummary(1L)
        
        assertTrue(result.isSuccess)
        assertNotNull(result.getOrNull())
    }
    
    @Test
    fun `getWeeklyPlanSummary returns error when plan not found`() = runTest {
        coEvery { planRepository.getWeeklyPlanSummary(999L) } returns Result.Success(null)
        
        val result = managePlansUseCase.getWeeklyPlanSummary(999L)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `getWeeklyPlanSummary handles repository error`() = runTest {
        coEvery { planRepository.getWeeklyPlanSummary(1L) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.getWeeklyPlanSummary(1L)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `getPlanItems returns items when plan exists`() = runTest {
        val items = listOf(
            createPlanItem(id = 1, dayOfWeek = DayOfWeek.MONDAY),
            createPlanItem(id = 2, dayOfWeek = DayOfWeek.TUESDAY)
        )
        
        every { planRepository.getPlanItems(1L) } returns flowOf(Result.Success(items))
        
        managePlansUseCase.getPlanItems(1L).test {
            val result = awaitItem()
            
            assertEquals(2, result.size)
            assertEquals(DayOfWeek.MONDAY, result[0].dayOfWeek)
            assertEquals(DayOfWeek.TUESDAY, result[1].dayOfWeek)
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getPlanItems returns empty list when no items`() = runTest {
        every { planRepository.getPlanItems(1L) } returns flowOf(Result.Success(emptyList()))
        
        managePlansUseCase.getPlanItems(1L).test {
            val result = awaitItem()
            
            assertTrue(result.isEmpty())
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `getPlanItems handles repository error gracefully`() = runTest {
        every { planRepository.getPlanItems(1L) } returns
            flowOf(Result.Error(Exception("Database error")))
        
        managePlansUseCase.getPlanItems(1L).test {
            val result = awaitItem()
            
            assertTrue(result.isEmpty())
            
            cancelAndIgnoreRemainingEvents()
        }
    }
    
    @Test
    fun `addPlanItem succeeds`() = runTest {
        val item = createPlanItem()
        
        coEvery { planRepository.addPlanItem(item) } returns Result.Success(1L)
        
        val result = managePlansUseCase.addPlanItem(item)
        
        assertTrue(result.isSuccess)
        assertEquals(1L, result.getOrNull())
    }
    
    @Test
    fun `addPlanItem handles repository error`() = runTest {
        val item = createPlanItem()
        
        coEvery { planRepository.addPlanItem(item) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.addPlanItem(item)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `updatePlanItem succeeds`() = runTest {
        val item = createPlanItem(targetMinutes = 120)
        
        coEvery { planRepository.updatePlanItem(item) } returns Result.Success(Unit)
        
        val result = managePlansUseCase.updatePlanItem(item)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `updatePlanItem handles repository error`() = runTest {
        val item = createPlanItem()
        
        coEvery { planRepository.updatePlanItem(item) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.updatePlanItem(item)
        
        assertTrue(result.isFailure)
    }
    
    @Test
    fun `deletePlanItem succeeds`() = runTest {
        val item = createPlanItem()
        
        coEvery { planRepository.deletePlanItem(item) } returns Result.Success(Unit)
        
        val result = managePlansUseCase.deletePlanItem(item)
        
        assertTrue(result.isSuccess)
    }
    
    @Test
    fun `deletePlanItem handles repository error`() = runTest {
        val item = createPlanItem()
        
        coEvery { planRepository.deletePlanItem(item) } returns
            Result.Error(Exception("Database error"))
        
        val result = managePlansUseCase.deletePlanItem(item)
        
        assertTrue(result.isFailure)
    }
}