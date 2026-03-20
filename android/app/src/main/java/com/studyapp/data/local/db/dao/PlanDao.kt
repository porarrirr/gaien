package com.studyapp.data.local.db.dao

import androidx.room.*
import com.studyapp.data.local.db.entity.PlanEntity
import com.studyapp.data.local.db.entity.PlanItemEntity
import com.studyapp.data.local.db.entity.WeeklyPlanSummary
import kotlinx.coroutines.flow.Flow

@Dao
interface PlanDao {
    
    @Query("SELECT * FROM study_plans WHERE isActive = 1 AND deletedAt IS NULL ORDER BY createdAt DESC LIMIT 1")
    fun getActivePlan(): Flow<PlanEntity?>
    
    @Query("SELECT * FROM study_plans WHERE deletedAt IS NULL ORDER BY createdAt DESC")
    fun getAllPlans(): Flow<List<PlanEntity>>
    
    @Query("SELECT * FROM study_plans WHERE id = :planId")
    suspend fun getPlanById(planId: Long): PlanEntity?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlan(plan: PlanEntity): Long
    
    @Update
    suspend fun updatePlan(plan: PlanEntity)
    
    @Delete
    suspend fun deletePlan(plan: PlanEntity)
    
    @Query("UPDATE study_plans SET isActive = 0 WHERE deletedAt IS NULL")
    suspend fun deactivateAllPlans()
    
    @Query("SELECT * FROM plan_items WHERE planId = :planId AND deletedAt IS NULL")
    fun getPlanItems(planId: Long): Flow<List<PlanItemEntity>>
    
    @Query("SELECT * FROM plan_items WHERE planId = :planId AND dayOfWeek = :dayOfWeek AND deletedAt IS NULL")
    fun getPlanItemsByDay(planId: Long, dayOfWeek: Int): Flow<List<PlanItemEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlanItem(item: PlanItemEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlanItems(items: List<PlanItemEntity>)
    
    @Update
    suspend fun updatePlanItem(item: PlanItemEntity)
    
    @Delete
    suspend fun deletePlanItem(item: PlanItemEntity)
    
    @Query("DELETE FROM plan_items WHERE planId = :planId")
    suspend fun deletePlanItems(planId: Long)
    
    @Transaction
    suspend fun createPlanWithItems(plan: PlanEntity, items: List<PlanItemEntity>): Long {
        deactivateAllPlans()
        val planId = insertPlan(plan)
        val itemsWithPlanId = items.map { it.copy(planId = planId) }
        insertPlanItems(itemsWithPlanId)
        return planId
    }
    
    @Query("""
        SELECT SUM(targetMinutes) FROM plan_items 
        WHERE planId = :planId AND deletedAt IS NULL
    """)
    fun getTotalTargetMinutes(planId: Long): Flow<Int?>
    
    @Query("""
        SELECT SUM(actualMinutes) FROM plan_items 
        WHERE planId = :planId AND deletedAt IS NULL
    """)
    fun getTotalActualMinutes(planId: Long): Flow<Int?>

    @Query("""
        SELECT dayOfWeek, SUM(targetMinutes) as totalTargetMinutes, SUM(actualMinutes) as totalActualMinutes
        FROM plan_items
        WHERE planId = :planId AND deletedAt IS NULL
        GROUP BY dayOfWeek
        ORDER BY dayOfWeek ASC
    """)
    fun getWeeklyPlanSummary(planId: Long): Flow<List<WeeklyPlanSummary>>
}
