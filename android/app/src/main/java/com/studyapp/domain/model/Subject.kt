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

    val systemImage: String
        get() = when (this) {
            BOOK -> "book.closed.fill"
            CALCULATOR -> "function"
            FLASK -> "testtube.2"
            GLOBE -> "globe.asia.australia.fill"
            PALETTE -> "paintpalette.fill"
            MUSIC -> "music.note"
            CODE -> "chevron.left.forwardslash.chevron.right"
            ATOM -> "atom"
            DNA -> "cross.case.fill"
            BRAIN -> "brain.head.profile"
            LANGUAGE -> "character.book.closed.fill"
            HISTORY -> "clock.arrow.circlepath"
            OTHER -> "square.grid.2x2.fill"
        }

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
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val name: String,
    val color: Int,
    val icon: SubjectIcon? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
)
