package com.studyapp.domain.model

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
    val name: String,
    val color: Int,
    val icon: SubjectIcon? = null
)