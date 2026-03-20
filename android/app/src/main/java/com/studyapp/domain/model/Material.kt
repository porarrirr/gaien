package com.studyapp.domain.model

data class Material(
    val id: Long = 0,
    val name: String,
    val subjectId: Long,
    val totalPages: Int = 0,
    val currentPage: Int = 0,
    val color: Int? = null,
    val note: String? = null
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