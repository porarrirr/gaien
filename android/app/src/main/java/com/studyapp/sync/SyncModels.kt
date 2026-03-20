package com.studyapp.sync

data class AuthSession(
    val localId: String,
    val email: String,
    val idToken: String,
    val refreshToken: String
)

data class SyncStatus(
    val isAuthenticated: Boolean = false,
    val email: String? = null,
    val isSyncing: Boolean = false,
    val lastSyncAt: Long? = null,
    val errorMessage: String? = null
)

