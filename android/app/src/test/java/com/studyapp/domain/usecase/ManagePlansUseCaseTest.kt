package com.studyapp.domain.usecase

import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.util.Result
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class ManagePlansUseCaseTest {
    @Test
    fun `createPlan rejects blank name`() = runTest {
        val repository = mockk<PlanRepository>()
        val result = ManagePlansUseCase(repository).createPlan(
            StudyPlan(name = " ", startDate = 1, endDate = 2),
            listOf(planItem())
        )

        assertTrue(result is Result.Error)
    }

    @Test
    fun `createPlan delegates valid plan`() = runTest {
        val repository = mockk<PlanRepository>()
        val plan = StudyPlan(name = "Plan", startDate = 1, endDate = 2)
        val item = planItem()
        coEvery { repository.createPlan(plan, listOf(item)) } returns Result.Success(10)

        val result = ManagePlansUseCase(repository).createPlan(plan, listOf(item))

        assertTrue(result is Result.Success)
        coVerify { repository.createPlan(plan, listOf(item)) }
    }

    private fun planItem() = PlanItem(
        planId = 1,
        subjectId = 1,
        dayOfWeek = StudyWeekday.MONDAY,
        targetMinutes = 30
    )
}
