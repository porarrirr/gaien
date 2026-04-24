package com.studyapp.domain.repository

import com.studyapp.domain.model.Material
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

/**
 * 教材のリポジトリインターフェース
 * 
 * 教材の追加、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface MaterialRepository {
    /**
     * すべての教材を取得します。
     * 
     * @return 教材リストを含むFlow
     */
    fun getAllMaterials(): Flow<Result<List<Material>>>

    /**
     * 指定科目に紐づく教材を取得します。
     * 
     * @param subjectId 科目ID
     * @return 教材リストを含むFlow
     */
    fun getMaterialsBySubject(subjectId: Long): Flow<Result<List<Material>>>

    /**
     * 指定IDの教材を取得します。
     * 
     * @param id 教材ID
     * @return 教材情報（存在しない場合はnull）、またはエラー
    */
    suspend fun getMaterialById(id: Long): Result<Material?>

    /**
     * 指定syncIdの教材を取得します。
     *
     * @param syncId 教材syncId
     * @return 教材情報（存在しない場合はnull）、またはエラー
     */
    suspend fun getMaterialBySyncId(syncId: String): Result<Material?>

    /**
     * 教材を追加します。
     * 
     * @param material 追加する教材情報
     * @return 追加された教材のID、またはエラー
     */
    suspend fun insertMaterial(material: Material): Result<Long>

    /**
     * 教材情報を更新します。
     * 
     * @param material 更新する教材情報
     * @return 成功またはエラー
     */
    suspend fun updateMaterial(material: Material): Result<Unit>

    /**
     * 教材を削除します。
     * 
     * @param material 削除する教材情報
     * @return 成功またはエラー
     */
    suspend fun deleteMaterial(material: Material): Result<Unit>

    /**
     * 教材の進捗を更新します。
     * 
     * @param id 教材ID
     * @param page 現在のページ番号
     * @return 成功またはエラー
     */
    suspend fun updateProgress(id: Long, page: Int): Result<Unit>

    suspend fun updateOrder(materialIdsInOrder: List<Long>): Result<Unit>
}
