package com.studyapp.data.local.db.dao

import androidx.room.*
import com.studyapp.data.local.db.entity.MaterialEntity
import com.studyapp.data.local.db.entity.MaterialWithSubject
import kotlinx.coroutines.flow.Flow

@Dao
interface MaterialDao {
    @Transaction
    @Query("SELECT * FROM materials WHERE deletedAt IS NULL ORDER BY updatedAt DESC")
    fun getAllMaterialsWithSubject(): Flow<List<MaterialWithSubject>>

    @Query("SELECT * FROM materials WHERE deletedAt IS NULL ORDER BY updatedAt DESC")
    fun getAllMaterials(): Flow<List<MaterialEntity>>

    @Query("SELECT * FROM materials ORDER BY updatedAt DESC")
    suspend fun getAllMaterialsForSync(): List<MaterialEntity>

    @Transaction
    @Query("SELECT * FROM materials WHERE subjectId = :subjectId AND deletedAt IS NULL ORDER BY name ASC")
    fun getMaterialsBySubjectWithDetails(subjectId: Long): Flow<List<MaterialWithSubject>>

    @Query("SELECT * FROM materials WHERE subjectId = :subjectId AND deletedAt IS NULL ORDER BY name ASC")
    fun getMaterialsBySubject(subjectId: Long): Flow<List<MaterialEntity>>

    @Query("SELECT * FROM materials WHERE id = :id")
    suspend fun getMaterialById(id: Long): MaterialEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMaterial(material: MaterialEntity): Long

    @Update
    suspend fun updateMaterial(material: MaterialEntity)

    @Delete
    suspend fun deleteMaterial(material: MaterialEntity)

    @Query("DELETE FROM materials WHERE id = :id")
    suspend fun deleteMaterialById(id: Long)

    @Query("UPDATE materials SET currentPage = :currentPage, updatedAt = :updatedAt WHERE id = :materialId")
    suspend fun updateProgress(materialId: Long, currentPage: Int, updatedAt: Long)
}
