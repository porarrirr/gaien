package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.PlanDao
import com.studyapp.data.local.db.entity.PlanEntity
import com.studyapp.data.local.db.entity.PlanItemEntity
import com.studyapp.data.local.db.entity.WeeklyPlanSummary as DaoWeeklyPlanSummary
import com.studyapp.domain.model.DailyPlanSummary
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.WeeklyPlanSummary
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.first
import java.time.DayOfWeek
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlanRepositoryImpl @Inject constructor(
    private val planDao: PlanDao,
    private val clock: Clock
) : PlanRepository {

    companion object {
        private const val TAG = "PlanRepository"
    }

    override fun getActivePlan(): Flow<Result<StudyPlan?>> {
        return planDao.getActivePlan().map { entity ->
            Result.Success(entity?.toDomain())
        }
    }

    override fun getAllPlans(): Flow<Result<List<StudyPlan>>> {
        return planDao.getAllPlans().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override fun getPlanItems(planId: Long): Flow<Result<List<PlanItem>>> {
        return planDao.getPlanItems(planId).map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override fun getPlanItemsByDay(planId: Long, dayOfWeek: DayOfWeek): Flow<Result<List<PlanItem>>> {
        return planDao.getPlanItemsByDay(planId, dayOfWeek.value).map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun createPlan(plan: StudyPlan, items: List<PlanItem>): Result<Long> {
        return try {
            val entity = PlanEntity(
                name = plan.name,
                startDate = plan.startDate,
                endDate = plan.endDate,
                isActive = plan.isActive,
                createdAt = plan.createdAt
            )

            val itemEntities = items.map { item ->
                PlanItemEntity(
                    planId = 0,
                    subjectId = item.subjectId,
                    dayOfWeek = item.dayOfWeek.value,
                    targetMinutes = item.targetMinutes,
                    actualMinutes = item.actualMinutes,
                    timeSlot = item.timeSlot
                )
            }

            val id = planDao.createPlanWithItems(entity, itemEntities)
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create plan: ${plan.name}", e)
            Result.Error(e, "Failed to create plan")
        }
    }

    override suspend fun updatePlan(plan: StudyPlan): Result<Unit> {
        return try {
            planDao.updatePlan(
                PlanEntity(
                    id = plan.id,
                    name = plan.name,
                    startDate = plan.startDate,
                    endDate = plan.endDate,
                    isActive = plan.isActive,
                    createdAt = plan.createdAt
                )
            )
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update plan: ${plan.id}", e)
            Result.Error(e, "Failed to update plan")
        }
    }

    override suspend fun deletePlan(plan: StudyPlan): Result<Unit> {
        return try {
            planDao.deletePlan(
                PlanEntity(
                    id = plan.id,
                    name = plan.name,
                    startDate = plan.startDate,
                    endDate = plan.endDate,
                    isActive = plan.isActive,
                    createdAt = plan.createdAt
                )
            )
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete plan: ${plan.id}", e)
            Result.Error(e, "Failed to delete plan")
        }
    }

    override suspend fun addPlanItem(item: PlanItem): Result<Long> {
        return try {
            val id = planDao.insertPlanItem(
                PlanItemEntity(
                    planId = item.planId,
                    subjectId = item.subjectId,
                    dayOfWeek = item.dayOfWeek.value,
                    targetMinutes = item.targetMinutes,
                    actualMinutes = item.actualMinutes,
                    timeSlot = item.timeSlot
                )
            )
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add plan item", e)
            Result.Error(e, "Failed to add plan item")
        }
    }

    override suspend fun updatePlanItem(item: PlanItem): Result<Unit> {
        return try {
            planDao.updatePlanItem(
                PlanItemEntity(
                    id = item.id,
                    planId = item.planId,
                    subjectId = item.subjectId,
                    dayOfWeek = item.dayOfWeek.value,
                    targetMinutes = item.targetMinutes,
                    actualMinutes = item.actualMinutes,
                    timeSlot = item.timeSlot
                )
            )
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update plan item: ${item.id}", e)
            Result.Error(e, "Failed to update plan item")
        }
    }

    override suspend fun deletePlanItem(item: PlanItem): Result<Unit> {
        return try {
            planDao.deletePlanItem(
                PlanItemEntity(
                    id = item.id,
                    planId = item.planId,
                    subjectId = item.subjectId,
                    dayOfWeek = item.dayOfWeek.value,
                    targetMinutes = item.targetMinutes,
                    actualMinutes = item.actualMinutes,
                    timeSlot = item.timeSlot
                )
            )
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete plan item: ${item.id}", e)
            Result.Error(e, "Failed to delete plan item")
        }
    }

    override fun getTotalTargetMinutes(planId: Long): Flow<Result<Int>> {
        return planDao.getTotalTargetMinutes(planId).map { minutes ->
            Result.Success(minutes ?: 0)
        }
    }

    override fun getTotalActualMinutes(planId: Long): Flow<Result<Int>> {
        return planDao.getTotalActualMinutes(planId).map { minutes ->
            Result.Success(minutes ?: 0)
        }
    }

    override suspend fun getWeeklyPlanSummary(planId: Long): Result<WeeklyPlanSummary?> {
        return try {
            val summaries = planDao.getWeeklyPlanSummary(planId).first()
            
            if (summaries.isEmpty()) {
                return Result.Success(null)
            }

            val totalTargetMinutes = summaries.sumOf { it.totalTargetMinutes }
            val totalActualMinutes = summaries.sumOf { it.totalActualMinutes }
            
            val dailyBreakdown = summaries.associate { summary ->
                val dayOfWeek = DayOfWeek.of(summary.dayOfWeek)
                val completionRate = if (summary.totalTargetMinutes > 0) {
                    summary.totalActualMinutes.toFloat() / summary.totalTargetMinutes.toFloat()
                } else {
                    0f
                }
                dayOfWeek to DailyPlanSummary(
                    dayOfWeek = dayOfWeek,
                    targetMinutes = summary.totalTargetMinutes,
                    actualMinutes = summary.totalActualMinutes,
                    completionRate = completionRate
                )
            }

            val weekStart = clock.startOfWeek()
            val weekEnd = weekStart + (7 * 24 * 60 * 60 * 1000L)

            Result.Success(
                WeeklyPlanSummary(
                    weekStart = weekStart,
                    weekEnd = weekEnd,
                    totalTargetMinutes = totalTargetMinutes,
                    totalActualMinutes = totalActualMinutes,
                    dailyBreakdown = dailyBreakdown
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get weekly plan summary for plan: $planId", e)
            Result.Error(e, "Failed to get weekly plan summary")
        }
    }

    private fun PlanEntity.toDomain() = StudyPlan(
        id = id,
        name = name,
        startDate = startDate,
        endDate = endDate,
        isActive = isActive,
        createdAt = createdAt
    )

    private fun PlanItemEntity.toDomain() = PlanItem(
        id = id,
        planId = planId,
        subjectId = subjectId,
        dayOfWeek = DayOfWeek.of(dayOfWeek),
        targetMinutes = targetMinutes,
        actualMinutes = actualMinutes,
        timeSlot = timeSlot
    )
}
