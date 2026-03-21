package com.studyapp.sync

import kotlinx.coroutines.flow.StateFlow

interface SyncRepository {
    val status: StateFlow<SyncStatus>

    suspend fun syncNow()

    suspend fun importLocalDataToCloud()

    suspend fun clearLocalSyncState()
}
