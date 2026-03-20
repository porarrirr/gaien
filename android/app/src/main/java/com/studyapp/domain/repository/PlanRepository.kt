package com.studyapp.domain.repository

import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.WeeklyPlanSummary
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import java.time.DayOfWeek

/**
 * 学習計画のリポジトリインターフェース
 * 
 * 学習計画の作成、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface PlanRepository {
    /**
     * アクティブな学習計画を取得します。
     * 
     * @return アクティブな学習計画（存在しない場合はnull）、またはエラー
     */
    fun getActivePlan(): Flow<Result<StudyPlan?>>

    /**
     * すべての学習計画を取得します。
     * 
     * @return 学習計画リストを含むFlow
     */
    fun getAllPlans(): Flow<Result<List<StudyPlan>>>

    /**
     * 指定計画の計画項目をすべて取得します。
     * 
     * @param planId 計画ID
     * @return 計画項目リストを含むFlow
     */
    fun getPlanItems(planId: Long): Flow<Result<List<PlanItem>>>

    /**
     * 指定計画の特定曜日の計画項目を取得します。
     * 
     * @param planId 計画ID
     * @param dayOfWeek 曜日
     * @return 計画項目リストを含むFlow
     */
    fun getPlanItemsByDay(planId: Long, dayOfWeek: DayOfWeek): Flow<Result<List<PlanItem>>>

    /**
     * 新しい学習計画を作成します。
     * 
     * @param plan 学習計画情報
     * @param items 計画項目リスト
     * @return 作成された計画のID、またはエラー
     */
    suspend fun createPlan(plan: StudyPlan, items: List<PlanItem>): Result<Long>

    /**
     * 学習計画情報を更新します。
     * 
     * @param plan 更新する学習計画情報
     * @return 成功またはエラー
     */
    suspend fun updatePlan(plan: StudyPlan): Result<Unit>

    /**
     * 学習計画を削除します。
     * 
     * @param plan 削除する学習計画情報
     * @return 成功またはエラー
     */
    suspend fun deletePlan(plan: StudyPlan): Result<Unit>

    /**
     * 計画項目を追加します。
     * 
     * @param item 追加する計画項目
     * @return 追加された項目のID、またはエラー
     */
    suspend fun addPlanItem(item: PlanItem): Result<Long>

    /**
     * 計画項目を更新します。
     * 
     * @param item 更新する計画項目
     * @return 成功またはエラー
     */
    suspend fun updatePlanItem(item: PlanItem): Result<Unit>

    /**
     * 計画項目を削除します。
     * 
     * @param item 削除する計画項目
     * @return 成功またはエラー
     */
    suspend fun deletePlanItem(item: PlanItem): Result<Unit>

    /**
     * 指定計画の目標学習時間（分）の合計を取得します。
     * 
     * @param planId 計画ID
     * @return 目標学習時間（分）を含むFlow
     */
    fun getTotalTargetMinutes(planId: Long): Flow<Result<Int>>

    /**
     * 指定計画の実績学習時間（分）の合計を取得します。
     * 
     * @param planId 計画ID
     * @return 実績学習時間（分）を含むFlow
     */
    fun getTotalActualMinutes(planId: Long): Flow<Result<Int>>

    /**
     * 指定計画の週間サマリーを取得します。
     * 
     * @param planId 計画ID
     * @return 週間サマリー（存在しない場合はnull）、またはエラー
     */
    suspend fun getWeeklyPlanSummary(planId: Long): Result<WeeklyPlanSummary?>
}