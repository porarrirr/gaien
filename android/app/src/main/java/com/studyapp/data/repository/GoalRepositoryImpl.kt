package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.GoalDao
import com.studyapp.data.local.db.entity.GoalEntity
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.DayOfWeek
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GoalRepositoryImpl @Inject constructor(
    private val goalDao: GoalDao,
    private val clock: Clock
) : GoalRepository {

    companion object {
        private const val TAG = "GoalRepository"
    }

    override fun getActiveGoals(): Flow<Result<List<Goal>>> {
        return goalDao.getActiveGoals().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override fun getActiveGoalByType(type: GoalType): Flow<Result<Goal?>> {
        return goalDao.getActiveGoalByType(type).map { entity ->
            Result.Success(entity?.toDomain())
        }
    }

    override fun getAllGoals(): Flow<Result<List<Goal>>> {
        return goalDao.getAllGoals().map { entities ->
            Result.Success(entities.map { it.toDomain() })
        }
    }

    override suspend fun getGoalById(id: Long): Result<Goal?> {
        return try {
            val goal = goalDao.getGoalById(id)?.toDomain()
            Result.Success(goal)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get goal by id: $id", e)
            Result.Error(e, "Failed to get goal")
        }
    }

    override suspend fun insertGoal(goal: Goal): Result<Long> {
        return try {
            val id = goalDao.insertGoal(goal.toEntity())
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert goal: ${goal.type}", e)
            Result.Error(e, "Failed to insert goal")
        }
    }

    override suspend fun updateGoal(goal: Goal): Result<Unit> {
        return try {
            goalDao.updateGoal(goal.toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update goal: ${goal.id}", e)
            Result.Error(e, "Failed to update goal")
        }
    }

    override suspend fun deleteGoal(goal: Goal): Result<Unit> {
        return try {
            goalDao.deleteGoal(goal.toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete goal: ${goal.id}", e)
            Result.Error(e, "Failed to delete goal")
        }
    }

    private fun GoalEntity.toDomain(): Goal {
        return Goal(
            id = id,
            type = type,
            targetMinutes = targetMinutes,
            weekStartDay = DayOfWeek.of(weekStartDay),
            isActive = isActive
        )
    }

    private fun Goal.toEntity(): GoalEntity {
        return GoalEntity(
            id = id,
            type = type,
            targetMinutes = targetMinutes,
            weekStartDay = weekStartDay.value,
            isActive = isActive
        )
    }
}