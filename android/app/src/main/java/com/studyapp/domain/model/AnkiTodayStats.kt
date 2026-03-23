package com.studyapp.domain.model

enum class AnkiIntegrationStatus {
    AVAILABLE,
    ANKI_NOT_INSTALLED,
    NEEDS_ANKI_PERMISSION,
    NEEDS_USAGE_ACCESS,
    ERROR
}

data class AnkiTodayStats(
    val answeredCards: Int? = null,
    val usageMinutes: Long? = null,
    val lastUpdatedAt: Long? = null,
    val status: AnkiIntegrationStatus = AnkiIntegrationStatus.ANKI_NOT_INSTALLED,
    val requiresAnkiPermission: Boolean = false,
    val requiresUsageAccess: Boolean = false,
    val errorMessage: String? = null
)
