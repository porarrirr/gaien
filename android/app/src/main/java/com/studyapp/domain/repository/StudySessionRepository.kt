package com.studyapp.domain.repository

import com.studyapp.domain.model.StudySession
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow

/**
 * 学習セッションのリポジトリインターフェース
 * 
 * 学習セッションの追加、更新、削除、取得を行うためのデータアクセスを提供します。
 */
interface StudySessionRepository {
    /**
     * すべての学習セッションを取得します。
     * 
     * @return 学習セッションリストを含むFlow
     */
    fun getAllSessions(): Flow<Result<List<StudySession>>>

    /**
     * 指定日の学習セッションを取得します。
     * 
     * @param date 日付（エポックミリ秒）
     * @return 学習セッションリストを含むFlow
     */
    fun getSessionsByDate(date: Long): Flow<Result<List<StudySession>>>

    /**
     * 指定期間の学習セッションを取得します。
     * 
     * @param startDate 開始日（エポックミリ秒）
     * @param endDate 終了日（エポックミリ秒）
     * @return 学習セッションリストを含むFlow
     */
    fun getSessionsBetweenDates(startDate: Long, endDate: Long): Flow<Result<List<StudySession>>>

    /**
     * 指定科目の学習セッションを取得します。
     * 
     * @param subjectId 科目ID
     * @return 学習セッションリストを含むFlow
     */
    fun getSessionsBySubject(subjectId: Long): Flow<Result<List<StudySession>>>

    /**
     * 指定教材の学習セッションを取得します。
     * 
     * @param materialId 教材ID
     * @return 学習セッションリストを含むFlow
     */
    fun getSessionsByMaterial(materialId: Long): Flow<Result<List<StudySession>>>

    /**
     * 指定日の総学習時間を取得します。
     * 
     * @param date 日付（エポックミリ秒）
     * @return 総学習時間（ミリ秒）、またはエラー
     */
    suspend fun getTotalDurationByDate(date: Long): Result<Long>

    /**
     * 指定期間の総学習時間を取得します。
     * 
     * @param startDate 開始日（エポックミリ秒）
     * @param endDate 終了日（エポックミリ秒）
     * @return 総学習時間（ミリ秒）、またはエラー
     */
    suspend fun getTotalDurationBetweenDates(startDate: Long, endDate: Long): Result<Long>

    /**
     * 指定期間における指定科目の総学習時間を取得します。
     * 
     * @param subjectId 科目ID
     * @param startDate 開始日（エポックミリ秒）
     * @param endDate 終了日（エポックミリ秒）
     * @return 総学習時間（ミリ秒）、またはエラー
     */
    suspend fun getTotalDurationBySubjectBetweenDates(
        subjectId: Long,
        startDate: Long,
        endDate: Long
    ): Result<Long>

    /**
     * 指定IDの学習セッションを取得します。
     * 
     * @param id セッションID
     * @return 学習セッション（存在しない場合はnull）、またはエラー
     */
    suspend fun getSessionById(id: Long): Result<StudySession?>

    /**
     * 学習セッションを追加します。
     * 
     * @param session 追加する学習セッション情報
     * @return 追加されたセッションのID、またはエラー
     */
    suspend fun insertSession(session: StudySession): Result<Long>

    /**
     * 学習セッション情報を更新します。
     * 
     * @param session 更新する学習セッション情報
     * @return 成功またはエラー
     */
    suspend fun updateSession(session: StudySession): Result<Unit>

    /**
     * 学習セッションを削除します。
     * 
     * @param session 削除する学習セッション情報
     * @return 成功またはエラー
     */
    suspend fun deleteSession(session: StudySession): Result<Unit>
}