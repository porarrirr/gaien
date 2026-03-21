package com.studyapp.domain.repository

import com.studyapp.domain.model.Subject
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

/**
 * 科目のリポジトリインターフェース
 * 
 * 科目の追加、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface SubjectRepository {
    /**
     * すべての科目を取得します。
     * 
     * @return 科目リストを含むFlow
     */
    fun getAllSubjects(): Flow<Result<List<Subject>>>

    /**
     * 指定IDの科目を取得します。
     * 
     * @param id 科目ID
     * @return 科目情報（存在しない場合はnull）、またはエラー
    */
    suspend fun getSubjectById(id: Long): Result<Subject?>

    /**
     * 指定syncIdの科目を取得します。
     *
     * @param syncId 科目syncId
     * @return 科目情報（存在しない場合はnull）、またはエラー
     */
    suspend fun getSubjectBySyncId(syncId: String): Result<Subject?>

    /**
     * 科目を追加します。
     * 
     * @param subject 追加する科目情報
     * @return 追加された科目のID、またはエラー
     */
    suspend fun insertSubject(subject: Subject): Result<Long>

    /**
     * 科目情報を更新します。
     * 
     * @param subject 更新する科目情報
     * @return 成功またはエラー
     */
    suspend fun updateSubject(subject: Subject): Result<Unit>

    /**
     * 科目を削除します。
     * 
     * @param subject 削除する科目情報
     * @return 成功またはエラー
     */
    suspend fun deleteSubject(subject: Subject): Result<Unit>
}
