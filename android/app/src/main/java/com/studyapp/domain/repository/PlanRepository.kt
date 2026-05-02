package com.studyapp.domain.repository

import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.WeeklyPlanSummary
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

interface PlanRepository {
    fun getActivePlan(): Flow<Result<StudyPlan?>>
    fun getAllPlans(): Flow<Result<List<StudyPlan>>>
    fun getPlanItems(planId: Long): Flow<Result<List<PlanItem>>>
    fun getPlanItemsByDay(planId: Long, dayOfWeek: StudyWeekday): Flow<Result<List<PlanItem>>>
    suspend fun createPlan(plan: StudyPlan, items: List<PlanItem>): Result<Long>
    suspend fun updatePlan(plan: StudyPlan): Result<Unit>
    suspend fun deletePlan(plan: StudyPlan): Result<Unit>
    suspend fun addPlanItem(item: PlanItem): Result<Long>
    suspend fun updatePlanItem(item: PlanItem): Result<Unit>
    suspend fun deletePlanItem(item: PlanItem): Result<Unit>
    fun getTotalTargetMinutes(planId: Long): Flow<Result<Int>>
    fun getTotalActualMinutes(planId: Long): Flow<Result<Int>>
    suspend fun getWeeklyPlanSummary(planId: Long): Result<WeeklyPlanSummary?>
}
