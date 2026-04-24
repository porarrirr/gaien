package com.studyapp.domain.model

import java.util.UUID

data class Material(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString(),
    val name: String,
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val sortOrder: Long = System.currentTimeMillis(),
    val totalPages: Int = 0,
    val currentPage: Int = 0,
    val color: Int? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val progress: Float
        get() = if (totalPages > 0) currentPage.toFloat() / totalPages.toFloat() else 0f
    
    val progressPercent: Int
        get() = (progress * 100).toInt()
}

data class MaterialWithSubject(
    val material: Material,
    val subjectName: String
)
