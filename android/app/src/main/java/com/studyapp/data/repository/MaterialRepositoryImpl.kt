package com.studyapp.data.repository

import android.util.Log
import com.studyapp.data.local.db.dao.MaterialDao
import com.studyapp.data.local.db.entity.MaterialEntity
import com.studyapp.data.local.db.entity.MaterialWithSubject
import com.studyapp.domain.model.Material
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MaterialRepositoryImpl @Inject constructor(
    private val materialDao: MaterialDao
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

    override suspend fun insertMaterial(material: Material): Result<Long> {
        return try {
            val id = materialDao.insertMaterial(material.toEntity())
            Result.Success(id)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to insert material: ${material.name}", e)
            Result.Error(e, "Failed to insert material")
        }
    }

    override suspend fun updateMaterial(material: Material): Result<Unit> {
        return try {
            materialDao.updateMaterial(material.toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update material: ${material.id}", e)
            Result.Error(e, "Failed to update material")
        }
    }

    override suspend fun deleteMaterial(material: Material): Result<Unit> {
        return try {
            materialDao.deleteMaterial(material.toEntity())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete material: ${material.id}", e)
            Result.Error(e, "Failed to delete material")
        }
    }

    override suspend fun updateProgress(id: Long, page: Int): Result<Unit> {
        return try {
            materialDao.updateProgress(id, page, System.currentTimeMillis())
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update progress for material: $id", e)
            Result.Error(e, "Failed to update progress")
        }
    }

    private fun MaterialWithSubject.toDomain(): Material {
        return Material(
            id = material.id,
            name = material.name,
            subjectId = material.subjectId,
            totalPages = material.totalPages,
            currentPage = material.currentPage,
            color = material.color,
            note = material.note
        )
    }

    private fun MaterialEntity.toDomainSimple(): Material {
        return Material(
            id = id,
            name = name,
            subjectId = subjectId,
            totalPages = totalPages,
            currentPage = currentPage,
            color = color,
            note = note
        )
    }

    private fun Material.toEntity(): MaterialEntity {
        return MaterialEntity(
            id = id,
            name = name,
            subjectId = subjectId,
            totalPages = totalPages,
            currentPage = currentPage,
            color = color,
            note = note
        )
    }
}