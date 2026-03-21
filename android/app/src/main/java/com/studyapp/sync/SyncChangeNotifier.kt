package com.studyapp.sync

import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

@Singleton
class SyncChangeNotifier @Inject constructor(
    private val syncPreferences: SyncPreferences
) {
    private val _events = MutableSharedFlow<Unit>(
        replay = 0,
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )

    val events: SharedFlow<Unit> = _events.asSharedFlow()

    fun notifyLocalDataChanged() {
        syncPreferences.setAutoSyncBlockedUntilLocalChange(false)
        _events.tryEmit(Unit)
    }

    fun pauseAutoSyncUntilLocalChange() {
        syncPreferences.setAutoSyncBlockedUntilLocalChange(true)
    }

    fun resumeAutoSync() {
        syncPreferences.setAutoSyncBlockedUntilLocalChange(false)
    }

    fun isAutoSyncBlockedUntilLocalChange(): Boolean {
        return syncPreferences.isAutoSyncBlockedUntilLocalChange()
    }
}
