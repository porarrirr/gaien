package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.WeeklyPlanSummary
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class ManagePlansUseCase @Inject constructor(
    private val planRepository: PlanRepository
) {
    fun getActivePlan(): Flow<StudyPlan?> {
        Log.d(TAG, "Getting active plan")
        return planRepository.getActivePlan()
            .map { result -> result.getOrNull() }
    }
    
    suspend fun createPlan(plan: StudyPlan, items: List<PlanItem>): Result<Long> {
        Log.d(TAG, "Creating plan: ${plan.name} with ${items.size} items")
        
        if (plan.name.isBlank()) {
            Log.w(TAG, "Plan name is blank")
            return Result.Error(
                IllegalArgumentException("Plan name cannot be blank"),
                "プラン名を入力してください"
            )
        }
        
        if (plan.startDate >= plan.endDate) {
            Log.w(TAG, "Invalid date range: start=${plan.startDate}, end=${plan.endDate}")
            return Result.Error(
                IllegalArgumentException("Invalid date range"),
                "開始日は終了日より前に設定してください"
            )
        }
        
        if (items.isEmpty()) {
            Log.w(TAG, "No plan items provided")
            return Result.Error(
                IllegalArgumentException("Plan must have at least one item"),
                "少なくとも1つの学習項目を追加してください"
            )
        }
        
        val result = planRepository.createPlan(plan, items)
        result.onSuccess { Log.i(TAG, "Plan created successfully with id=$it") }
        return result
    }
    
    suspend fun updatePlan(plan: StudyPlan): Result<Unit> {
        Log.d(TAG, "Updating plan: id=${plan.id}")
        
        if (plan.name.isBlank()) {
            Log.w(TAG, "Plan name is blank")
            return Result.Error(
                IllegalArgumentException("Plan name cannot be blank"),
                "プラン名を入力してください"
            )
        }
        
        if (plan.startDate >= plan.endDate) {
            Log.w(TAG, "Invalid date range: start=${plan.startDate}, end=${plan.endDate}")
            return Result.Error(
                IllegalArgumentException("Invalid date range"),
                "開始日は終了日より前に設定してください"
            )
        }
        
        val result = planRepository.updatePlan(plan)
        result.onSuccess { Log.i(TAG, "Plan updated successfully") }
        return result
    }
    
    suspend fun deletePlan(plan: StudyPlan): Result<Unit> {
        Log.d(TAG, "Deleting plan: id=${plan.id}")
        val result = planRepository.deletePlan(plan)
        result.onSuccess { Log.i(TAG, "Plan deleted successfully") }
        return result
    }
    
    suspend fun getWeeklyPlanSummary(planId: Long): Result<WeeklyPlanSummary> {
        Log.d(TAG, "Getting weekly plan summary for planId=$planId")
        
        val summaryResult = planRepository.getWeeklyPlanSummary(planId)
        val summary = summaryResult.getOrNull()
        
        return if (summary != null) {
            Log.i(TAG, "Weekly plan summary retrieved successfully")
            Result.Success(summary)
        } else {
            Log.w(TAG, "Plan not found: planId=$planId")
            Result.Error(
                NoSuchElementException("Plan not found"),
                "プランが見つかりません"
            )
        }
    }
    
    fun getPlanItems(planId: Long): Flow<List<PlanItem>> {
        Log.d(TAG, "Getting plan items for planId=$planId")
        return planRepository.getPlanItems(planId)
            .map { result -> result.getOrNull() ?: emptyList() }
    }
    
    suspend fun addPlanItem(item: PlanItem): Result<Long> {
        Log.d(TAG, "Adding plan item: subjectId=${item.subjectId}")
        val result = planRepository.addPlanItem(item)
        result.onSuccess { Log.i(TAG, "Plan item added successfully with id=$it") }
        return result
    }
    
    suspend fun updatePlanItem(item: PlanItem): Result<Unit> {
        Log.d(TAG, "Updating plan item: id=${item.id}")
        val result = planRepository.updatePlanItem(item)
        result.onSuccess { Log.i(TAG, "Plan item updated successfully") }
        return result
    }
    
    suspend fun deletePlanItem(item: PlanItem): Result<Unit> {
        Log.d(TAG, "Deleting plan item: id=${item.id}")
        val result = planRepository.deletePlanItem(item)
        result.onSuccess { Log.i(TAG, "Plan item deleted successfully") }
        return result
    }
    
    companion object {
        private const val TAG = "ManagePlansUseCase"
    }
}