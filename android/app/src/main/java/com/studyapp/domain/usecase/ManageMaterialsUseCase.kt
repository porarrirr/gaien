package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Material
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.util.Clock
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class ManageMaterialsUseCase @Inject constructor(
    private val materialRepository: MaterialRepository,
    private val clock: Clock
) {
    fun getAllMaterials(): Flow<List<Material>> {
        Log.d(TAG, "Getting all materials")
        return materialRepository.getAllMaterials()
            .map { result -> result.getOrNull() ?: emptyList() }
    }
    
    fun getMaterialsBySubject(subjectId: Long): Flow<List<Material>> {
        Log.d(TAG, "Getting materials for subjectId=$subjectId")
        return materialRepository.getMaterialsBySubject(subjectId)
            .map { result -> result.getOrNull() ?: emptyList() }
    }
    
    suspend fun getMaterialById(id: Long): Material? {
        Log.d(TAG, "Getting material by id=$id")
        return materialRepository.getMaterialById(id).getOrNull()
    }
    
    suspend fun addMaterial(material: Material): Result<Long> {
        Log.d(TAG, "Adding material: ${material.name}")
        
        if (material.name.isBlank()) {
            Log.w(TAG, "Material name is blank")
            return Result.Error(
                IllegalArgumentException("Material name cannot be blank"),
                "教材名を入力してください"
            )
        }
        
        if (material.subjectId <= 0) {
            Log.w(TAG, "Invalid subjectId: ${material.subjectId}")
            return Result.Error(
                IllegalArgumentException("Subject ID must be positive"),
                "科目を選択してください"
            )
        }
        
        if (material.totalPages < 0) {
            Log.w(TAG, "Invalid totalPages: ${material.totalPages}")
            return Result.Error(
                IllegalArgumentException("Total pages cannot be negative"),
                "ページ数は0以上で入力してください"
            )
        }
        
        val result = materialRepository.insertMaterial(material)
        result.onSuccess { Log.i(TAG, "Material added successfully with id=$it") }
        return result
    }
    
    suspend fun updateMaterial(material: Material): Result<Unit> {
        Log.d(TAG, "Updating material: id=${material.id}")
        
        if (material.name.isBlank()) {
            Log.w(TAG, "Material name is blank")
            return Result.Error(
                IllegalArgumentException("Material name cannot be blank"),
                "教材名を入力してください"
            )
        }
        
        if (material.subjectId <= 0) {
            Log.w(TAG, "Invalid subjectId: ${material.subjectId}")
            return Result.Error(
                IllegalArgumentException("Subject ID must be positive"),
                "科目を選択してください"
            )
        }
        
        if (material.totalPages < 0) {
            Log.w(TAG, "Invalid totalPages: ${material.totalPages}")
            return Result.Error(
                IllegalArgumentException("Total pages cannot be negative"),
                "ページ数は0以上で入力してください"
            )
        }
        
        if (material.currentPage > material.totalPages) {
            Log.w(TAG, "Current page exceeds total pages: ${material.currentPage} > ${material.totalPages}")
            return Result.Error(
                IllegalArgumentException("Current page cannot exceed total pages"),
                "現在のページは総ページ数以下にしてください"
            )
        }
        
        val result = materialRepository.updateMaterial(material)
        result.onSuccess { Log.i(TAG, "Material updated successfully") }
        return result
    }
    
    suspend fun deleteMaterial(material: Material): Result<Unit> {
        Log.d(TAG, "Deleting material: id=${material.id}")
        val result = materialRepository.deleteMaterial(material)
        result.onSuccess { Log.i(TAG, "Material deleted successfully") }
        return result
    }
    
    suspend fun updateProgress(materialId: Long, currentPage: Int): Result<Unit> {
        Log.d(TAG, "Updating progress: materialId=$materialId, currentPage=$currentPage")
        
        if (currentPage < 0) {
            Log.w(TAG, "Invalid currentPage: $currentPage")
            return Result.Error(
                IllegalArgumentException("Current page cannot be negative"),
                "ページ数は0以上で入力してください"
            )
        }
        
        val material = materialRepository.getMaterialById(materialId).getOrNull()
            ?: return Result.Error(
                NoSuchElementException("Material not found"),
                "教材が見つかりません"
            )
        
        if (currentPage > material.totalPages) {
            Log.w(TAG, "Current page exceeds total pages: $currentPage > ${material.totalPages}")
            return Result.Error(
                IllegalArgumentException("Current page cannot exceed total pages"),
                "現在のページは総ページ数以下にしてください"
            )
        }
        
        val result = materialRepository.updateProgress(materialId, currentPage)
        result.onSuccess { Log.i(TAG, "Progress updated successfully") }
        return result
    }

    suspend fun updateOrder(materialIdsInOrder: List<Long>): Result<Unit> {
        Log.d(TAG, "Updating material order: count=${materialIdsInOrder.size}")
        return materialRepository.updateOrder(materialIdsInOrder)
    }
    
    companion object {
        private const val TAG = "ManageMaterialsUseCase"
    }
}
