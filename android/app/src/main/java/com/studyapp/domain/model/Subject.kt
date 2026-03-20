package com.studyapp.domain.model

import java.util.UUID

enum class SubjectIcon {
    BOOK,
    CALCULATOR,
    FLASK,
    GLOBE,
    PALETTE,
    MUSIC,
    CODE,
    ATOM,
    DNA,
    BRAIN,
    LANGUAGE,
    HISTORY,
    OTHER;

    companion object {
        fun fromName(name: String?): SubjectIcon? {
            return name?.let { 
                entries.find { it.name.equals(name, ignoreCase = true) }
            }
        }
    }
}

data class Subject(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString(),
    val name: String,
    val color: Int,
    val icon: SubjectIcon? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
