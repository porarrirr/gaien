package com.studyapp.domain.model

import java.util.UUID

data class Material(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val name: String,
    val subjectId: Long,
    val subjectSyncId: String? = null,
    val sortOrder: Long = System.currentTimeMillis(),
    val totalPages: Int = 0,
    val currentPage: Int = 0,
    val totalProblems: Int = 0,
    val problemChapters: List<ProblemChapter> = emptyList(),
    val problemRecords: List<ProblemSessionRecord> = emptyList(),
    val color: Int? = null,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val progress: Double
        get() = if (totalPages > 0) (currentPage.toDouble() / totalPages.toDouble()).coerceIn(0.0, 1.0) else 0.0

    val progressPercent: Int
        get() = (progress * 100).toInt()

    val effectiveTotalProblems: Int
        get() {
            val chapterTotal = problemChapters.totalProblemCount()
            return if (chapterTotal > 0) chapterTotal else totalProblems
        }

    fun problemLabel(forNumber: Int): String =
        problemChapters.labelFor(forNumber)
}

data class MaterialWithSubject(
    val material: Material,
    val subjectName: String
)
