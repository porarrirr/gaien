package com.studyapp.domain.repository

import com.studyapp.domain.model.Exam
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

/**
 * 試験情報のリポジトリインターフェース
 * 
 * 試験の追加、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface ExamRepository {
    /**
     * すべての試験を取得します。
     * 
     * @return 試験リストを含むFlow
     */
    fun getAllExams(): Flow<Result<List<Exam>>>

    /**
     * 今後の試験を取得します。
     * 
     * 現在時刻以降に予定されている試験を日付順で返します。
     * 時刻の判定はリポジトリ実装内で行います。
     * 
     * @return 今後の試験リストを含むFlow
     */
    fun getUpcomingExams(): Flow<Result<List<Exam>>>

    /**
     * 指定IDの試験を取得します。
     * 
     * @param id 試験ID
     * @return 試験情報（存在しない場合はnull）、またはエラー
     */
    suspend fun getExamById(id: Long): Result<Exam?>

    /**
     * 試験を追加します。
     * 
     * @param exam 追加する試験情報
     * @return 追加された試験のID、またはエラー
     */
    suspend fun insertExam(exam: Exam): Result<Long>

    /**
     * 試験情報を更新します。
     * 
     * @param exam 更新する試験情報
     * @return 成功またはエラー
     */
    suspend fun updateExam(exam: Exam): Result<Unit>

    /**
     * 試験を削除します。
     * 
     * @param exam 削除する試験情報
     * @return 成功またはエラー
     */
    suspend fun deleteExam(exam: Exam): Result<Unit>
}