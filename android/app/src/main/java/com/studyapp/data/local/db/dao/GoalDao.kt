package com.studyapp.data.local.db.dao

import androidx.room.*
import com.studyapp.data.local.db.entity.GoalEntity
import com.studyapp.domain.model.GoalType
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalDao {
    @Query("SELECT * FROM goals WHERE isActive = 1 ORDER BY type ASC")
    fun getActiveGoals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals WHERE type = :type AND isActive = 1 LIMIT 1")
    fun getActiveGoalByType(type: GoalType): Flow<GoalEntity?>

    @Query("SELECT COUNT(*) FROM goals WHERE type = :type AND isActive = 1")
    suspend fun countActiveGoalsByType(type: GoalType): Int

    @Query("SELECT * FROM goals ORDER BY type ASC")
    fun getAllGoals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals WHERE id = :id")
    suspend fun getGoalById(id: Long): GoalEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGoal(goal: GoalEntity): Long

    @Query("UPDATE goals SET isActive = 0 WHERE type = :type AND isActive = 1")
    suspend fun deactivateGoalsByType(type: GoalType)

    @Transaction
    suspend fun insertGoalAndDeactivateOthers(goal: GoalEntity): Long {
        deactivateGoalsByType(goal.type)
        return insertGoal(goal)
    }

    @Update
    suspend fun updateGoal(goal: GoalEntity)

    @Delete
    suspend fun deleteGoal(goal: GoalEntity)

    @Query("DELETE FROM goals WHERE id = :id")
    suspend fun deleteGoalById(id: Long)
}