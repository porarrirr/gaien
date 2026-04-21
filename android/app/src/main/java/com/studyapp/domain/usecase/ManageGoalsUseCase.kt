package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.util.Result
import java.time.DayOfWeek
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class ManageGoalsUseCase @Inject constructor(
    private val goalRepository: GoalRepository
) {
    fun getDailyGoals(): Flow<Map<DayOfWeek, Goal>> {
        Log.d(TAG, "Getting active daily goals")
        return goalRepository.getActiveGoals()
            .map { result ->
                result.getOrNull()
                    .orEmpty()
                    .filter { it.type == GoalType.DAILY && it.dayOfWeek != null }
                    .associateBy { it.dayOfWeek!! }
            }
    }

    fun getDailyGoal(dayOfWeek: DayOfWeek): Flow<Goal?> {
        Log.d(TAG, "Getting active daily goal for $dayOfWeek")
        return getDailyGoals().map { it[dayOfWeek] }
    }
    
    fun getActiveWeeklyGoal(): Flow<Goal?> {
        Log.d(TAG, "Getting active weekly goal")
        return goalRepository.getActiveGoalByType(GoalType.WEEKLY)
            .map { result -> result.getOrNull() }
    }
    
    suspend fun updateDailyGoal(dayOfWeek: DayOfWeek, targetMinutes: Long): Result<Unit> {
        return updateGoal(GoalType.DAILY, targetMinutes, dayOfWeek)
    }
    
    suspend fun updateWeeklyGoal(targetMinutes: Long): Result<Unit> {
        return updateGoal(GoalType.WEEKLY, targetMinutes)
    }
    
    private suspend fun updateGoal(
        type: GoalType,
        targetMinutes: Long,
        dayOfWeek: DayOfWeek? = null
    ): Result<Unit> {
        Log.d(TAG, "Updating ${type.name} goal to $targetMinutes minutes day=$dayOfWeek")
        
        if (targetMinutes <= 0) {
            Log.w(TAG, "Invalid target minutes: $targetMinutes")
            return Result.Error(
                IllegalArgumentException("Target minutes must be positive"),
                "目標時間は0より大きくしてください"
            )
        }
        
        val currentGoal = when (type) {
            GoalType.DAILY -> {
                when (val activeGoalsResult = goalRepository.getActiveGoals().first()) {
                    is Result.Success -> activeGoalsResult.data
                        .firstOrNull { it.type == GoalType.DAILY && it.dayOfWeek == dayOfWeek }
                    is Result.Error -> return activeGoalsResult
                }
            }
            GoalType.WEEKLY -> {
                when (val currentGoalResult = goalRepository.getActiveGoalByType(type).first()) {
                    is Result.Success -> currentGoalResult.data
                    is Result.Error -> return currentGoalResult
                }
            }
        }
        
        val result = if (currentGoal != null) {
            goalRepository.updateGoal(
                currentGoal.copy(
                    targetMinutes = targetMinutes.toInt(),
                    dayOfWeek = dayOfWeek
                )
            )
                .also { Log.i(TAG, "${type.name} goal updated successfully") }
        } else {
            val newGoal = Goal(
                type = type,
                targetMinutes = targetMinutes.toInt(),
                dayOfWeek = dayOfWeek,
                isActive = true
            )
            goalRepository.insertGoal(newGoal)
                .also { Log.i(TAG, "New ${type.name} goal created successfully") }
                .map { }
        }
        
        return result
    }
    
    suspend fun deactivateGoal(goalId: Long): Result<Unit> {
        Log.d(TAG, "Deactivating goal id=$goalId")
        
        val goalResult = goalRepository.getGoalById(goalId)
        val goal = goalResult.getOrNull()
            ?: return Result.Error(
                NoSuchElementException("Goal not found"),
                "目標が見つかりません"
            )
        
        val result = goalRepository.updateGoal(goal.copy(isActive = false))
        Log.i(TAG, "Goal deactivated successfully")
        return result
    }
    
    companion object {
        private const val TAG = "ManageGoalsUseCase"
    }
}
