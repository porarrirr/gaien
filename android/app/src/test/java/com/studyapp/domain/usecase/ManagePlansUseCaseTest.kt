package com.studyapp.domain.usecase

import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.util.Result
import com.studyapp.testutil.LogMockRule
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ManagePlansUseCaseTest {
    @get:Rule
    val logMock = LogMockRule()

    private val repository = mockk<PlanRepository>()
    private val useCase = ManagePlansUseCase(repository)

    @Test
    fun `createPlan rejects blank name with user message and does not call repository`() = runTest {
        val result = useCase.createPlan(
            StudyPlan(name = " ", startDate = 1, endDate = 2),
            listOf(planItem())
        )

        assertTrue(result is Result.Error)
        assertEquals("プラン名を入力してください", result.getErrorMessage())
        coVerify(exactly = 0) { repository.createPlan(any(), any()) }
    }

    @Test
    fun `createPlan rejects same day or inverted date range`() = runTest {
        val result = useCase.createPlan(
            StudyPlan(name = "Plan", startDate = 2, endDate = 2),
            listOf(planItem())
        )

        assertTrue(result is Result.Error)
        assertEquals("開始日は終了日より前に設定してください", result.getErrorMessage())
        coVerify(exactly = 0) { repository.createPlan(any(), any()) }
    }

    @Test
    fun `createPlan rejects plan without items`() = runTest {
        val result = useCase.createPlan(
            StudyPlan(name = "Plan", startDate = 1, endDate = 2),
            emptyList()
        )

        assertTrue(result is Result.Error)
        assertEquals("少なくとも1つの学習項目を追加してください", result.getErrorMessage())
        coVerify(exactly = 0) { repository.createPlan(any(), any()) }
    }

    @Test
    fun `createPlan delegates valid plan and returns created id`() = runTest {
        val plan = StudyPlan(name = "Plan", startDate = 1, endDate = 2)
        val item = planItem()
        coEvery { repository.createPlan(plan, listOf(item)) } returns Result.Success(10L)

        val result = useCase.createPlan(plan, listOf(item))

        assertTrue(result is Result.Success)
        assertEquals(10L, result.getOrNull())
        coVerify(exactly = 1) { repository.createPlan(plan, listOf(item)) }
    }

    @Test
    fun `updatePlan rejects blank name before repository call`() = runTest {
        val result = useCase.updatePlan(StudyPlan(id = 3, name = "", startDate = 1, endDate = 2))

        assertTrue(result is Result.Error)
        assertEquals("プラン名を入力してください", result.getErrorMessage())
        coVerify(exactly = 0) { repository.updatePlan(any()) }
    }

    private fun planItem() = PlanItem(
        planId = 1,
        subjectId = 1,
        dayOfWeek = StudyWeekday.MONDAY,
        targetMinutes = 30
    )
}
