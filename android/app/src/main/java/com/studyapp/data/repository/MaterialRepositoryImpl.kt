package com.studyapp.data.repository

import android.util.Log
import androidx.room.withTransaction
import com.studyapp.data.local.db.StudyDatabase
import com.studyapp.data.local.db.dao.MaterialDao
import com.studyapp.data.local.db.entity.MaterialEntity
import com.studyapp.data.local.db.entity.MaterialWithSubject
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemChapter
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.util.Result
import com.studyapp.sync.AppDataWriteLock
import com.studyapp.sync.SyncChangeNotifier
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MaterialRepositoryImpl @Inject constructor(
    private val materialDao: MaterialDao,
    private val studyDatabase: StudyDatabase,
    private val writeLock: AppDataWriteLock,
    private val syncChangeNotifier: SyncChangeNotifier
) : MaterialRepository {

    companion object {
        private const val TAG = "MaterialRepository"
    }

    override fun getAllMaterials(): Flow<Result<List<Material>>> {
        return materialDao.getAllMaterialsWithSubject().map { details ->
            Result.Success(details.map { it.toDomain() })
        }
    }

    override fun getMaterialsBySubject(subjectId: Long): Flow<Result<List<Material>>> {
        return materialDao.getMaterialsBySubjectWithDetails(subjectId).map { details ->
            Result.Success(details.map { it.toDomain() })
        }
    }

    override suspend fun getMaterialById(id: Long): Result<Material?> {
        return try {
            val material = materialDao.getMaterialById(id)?.toDomainSimple()
            Result.Success(material)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get material by id: $id", e)
            Result.Error(e, "Failed to get material")
        }
    }

    override suspend fun getMaterialBySyncId(syncId: String): Result<Material?> {
        return try {
            val material = materialDao.getMaterialBySyncId(syncId)?.toDomainSimple()
            Result.Success(material)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get material by syncId: $syncId", e)
            Result.Error(e, "Failed to get material")
        }
    }

    override suspend fun insertMaterial(material: Material): Result<Long> {
        return try {
            val id = writeLock.withLock {
                materialDao.insertMaterial(material.toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert material: ${material.name}", e)
            Result.Error(e, "Failed to insert material")
        }
    }

    override suspend fun updateMaterial(material: Material): Result<Unit> {
        return try {
            writeLock.withLock {
                materialDao.updateMaterial(material.copy(updatedAt = System.currentTimeMillis()).toEntity())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update material: ${material.id}", e)
            Result.Error(e, "Failed to update material")
        }
    }

    override suspend fun deleteMaterial(material: Material): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                studyDatabase.withTransaction {
                    materialDao.updateMaterial(material.copy(deletedAt = now, updatedAt = now).toEntity())
                    studyDatabase.studySessionDao().softDeleteActiveByMaterial(material.id, now, now)
                    studyDatabase.problemReviewRecordDao().softDeleteActiveByMaterial(material.id, now, now)
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete material: ${material.id}", e)
            Result.Error(e, "Failed to delete material")
        }
    }

    override suspend fun updateProgress(id: Long, page: Int): Result<Unit> {
        return try {
            writeLock.withLock {
                materialDao.updateProgress(id, page, System.currentTimeMillis())
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update progress for material: $id", e)
            Result.Error(e, "Failed to update progress")
        }
    }

    override suspend fun updateOrder(materialIdsInOrder: List<Long>): Result<Unit> {
        return try {
            val now = System.currentTimeMillis()
            writeLock.withLock {
                materialIdsInOrder.forEachIndexed { index, materialId ->
                    materialDao.updateSortOrder(materialId, index.toLong(), now)
                }
            }
            syncChangeNotifier.notifyLocalDataChanged()
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update material order", e)
            Result.Error(e, "Failed to update material order")
        }
    }

    private fun MaterialWithSubject.toDomain(): Material {
        return Material(
            id = material.id,
            syncId = material.syncId,
            name = material.name,
            subjectId = material.subjectId,
            subjectSyncId = material.subjectSyncId,
            sortOrder = material.sortOrder,
            totalPages = material.totalPages,
            currentPage = material.currentPage,
            totalProblems = material.totalProblems,
            problemChapters = material.problemChaptersJson.toProblemChapters(),
            problemRecords = material.problemRecordsJson.toProblemRecords(),
            color = material.color,
            note = material.note,
            createdAt = material.createdAt,
            updatedAt = material.updatedAt,
            deletedAt = material.deletedAt,
            lastSyncedAt = material.lastSyncedAt
        )
    }

    private fun MaterialEntity.toDomainSimple(): Material {
        return Material(
            id = id,
            syncId = syncId,
            name = name,
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            sortOrder = sortOrder,
            totalPages = totalPages,
            currentPage = currentPage,
            totalProblems = totalProblems,
            problemChapters = problemChaptersJson.toProblemChapters(),
            problemRecords = problemRecordsJson.toProblemRecords(),
            color = color,
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun Material.toEntity(): MaterialEntity {
        return MaterialEntity(
            id = id,
            syncId = syncId,
            name = name,
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            sortOrder = sortOrder,
            totalPages = totalPages,
            currentPage = currentPage,
            totalProblems = totalProblems,
            problemChaptersJson = problemChapters.chaptersToJson(),
            problemRecordsJson = problemRecords.recordsToJson(),
            color = color,
            note = note,
            createdAt = createdAt,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            lastSyncedAt = lastSyncedAt
        )
    }

    private fun String?.toProblemChapters(): List<ProblemChapter> {
        if (this.isNullOrBlank()) return emptyList()
        return try {
            val jsonArray = JSONArray(this)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    add(
                        ProblemChapter(
                            id = item.optString("id", ""),
                            title = item.optString("title", "章"),
                            problemCount = item.optInt("problemCount", 0)
                        )
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun List<ProblemChapter>.chaptersToJson(): String? {
        if (isEmpty()) return null
        return JSONArray(
            map { chapter ->
                JSONObject().apply {
                    put("id", chapter.id)
                    put("title", chapter.title)
                    put("problemCount", chapter.problemCount)
                }
            }
        ).toString()
    }

    private fun String?.toProblemRecords(): List<ProblemSessionRecord> {
        if (this.isNullOrBlank()) return emptyList()
        return try {
            val jsonArray = JSONArray(this)
            buildList(jsonArray.length()) {
                for (index in 0 until jsonArray.length()) {
                    val item = jsonArray.optJSONObject(index) ?: continue
                    val resultStr = item.optString("result", "CORRECT")
                    val result = when (resultStr) {
                        "CORRECT", "correct" -> ProblemResult.CORRECT
                        "WRONG", "wrong" -> ProblemResult.WRONG
                        "REVIEW_CORRECT", "reviewCorrect" -> ProblemResult.REVIEW_CORRECT
                        else -> if (item.optBoolean("isWrong", false)) ProblemResult.WRONG else ProblemResult.CORRECT
                    }
                    add(
                        ProblemSessionRecord(
                            number = item.optInt("number"),
                            result = result,
                            detail = item.optString("detail").takeIf { it.isNotEmpty() },
                            subNumber = item.optString("subNumber").takeIf { it.isNotEmpty() }
                        )
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun List<ProblemSessionRecord>.recordsToJson(): String? {
        if (isEmpty()) return null
        return JSONArray(
            map { record ->
                JSONObject().apply {
                    put("number", record.number)
                    put("result", record.result.name)
                    put("isWrong", record.isWrong)
                    record.detail?.let { put("detail", it) }
                    record.normalizedSubNumber?.let { put("subNumber", it) }
                }
            }
        ).toString()
    }
}
