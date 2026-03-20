package com.studyapp.domain.repository

import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

/**
 * 目標のリポジトリインターフェース
 * 
 * 学習目標の追加、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface GoalRepository {
    /**
     * アクティブな目標をすべて取得します。
     * 
     * @return アクティブな目標リストを含むFlow
     */
    fun getActiveGoals(): Flow<Result<List<Goal>>>

    /**
     * 指定タイプのアクティブな目標を取得します。
     * 
     * @param type 目標タイプ
     * @return 該当する目標（存在しない場合はnull）、またはエラー
     */
    fun getActiveGoalByType(type: GoalType): Flow<Result<Goal?>>

    /**
     * すべての目標を取得します。
     * 
     * @return 目標リストを含むFlow
     */
    fun getAllGoals(): Flow<Result<List<Goal>>>

    /**
     * 指定IDの目標を取得します。
     * 
     * @param id 目標ID
     * @return 目標情報（存在しない場合はnull）、またはエラー
     */
    suspend fun getGoalById(id: Long): Result<Goal?>

    /**
     * 目標を追加します。
     * 
     * @param goal 追加する目標情報
     * @return 追加された目標のID、またはエラー
     */
    suspend fun insertGoal(goal: Goal): Result<Long>

    /**
     * 目標情報を更新します。
     * 
     * @param goal 更新する目標情報
     * @return 成功またはエラー
     */
    suspend fun updateGoal(goal: Goal): Result<Unit>

    /**
     * 目標を削除します。
     * 
     * @param goal 削除する目標情報
     * @return 成功またはエラー
     */
    suspend fun deleteGoal(goal: Goal): Result<Unit>
}