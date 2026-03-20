package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class GetRecentMaterialsUseCase @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val materialRepository: MaterialRepository,
    private val subjectRepository: SubjectRepository
) {
    operator fun invoke(limit: Int = DEFAULT_LIMIT): Flow<List<Pair<Material, Subject>>> {
        Log.d(TAG, "Getting recent materials with limit=$limit")
        
        return studySessionRepository.getAllSessions().map { result ->
            val sessions = result.getOrNull() ?: emptyList()
            
            val recentMaterialIds = sessions
                .filter { it.materialId != null }
                .sortedByDescending { it.startTime }
                .distinctBy { it.materialId }
                .take(limit)
                .mapNotNull { it.materialId }
            
            Log.d(TAG, "Found ${recentMaterialIds.size} recent material ids")
            
            val result_1 = mutableListOf<Pair<Material, Subject>>()
            
            for (materialId in recentMaterialIds) {
                val material = (materialRepository.getMaterialById(materialId) as? Result.Success)?.data ?: continue
                val subject = (subjectRepository.getSubjectById(material.subjectId) as? Result.Success)?.data ?: continue
                result_1.add(material to subject)
            }
            
            Log.i(TAG, "Returning ${result_1.size} recent materials")
            result_1
        }
    }
    
    companion object {
        private const val TAG = "GetRecentMaterials"
        private const val DEFAULT_LIMIT = 5
    }
}