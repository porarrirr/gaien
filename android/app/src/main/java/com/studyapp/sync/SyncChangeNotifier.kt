package com.studyapp.sync

import java.util.concurrent.atomic.AtomicLong
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

    @Volatile
    var localChangeGeneration: Long = 0L
        private set

    private var lastSyncedGeneration: Long? = null

    fun notifyLocalDataChanged() {
        localChangeGeneration += 1
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

    fun recordManualSyncApplied() {
        lastSyncedGeneration = localChangeGeneration
        syncPreferences.setAutoSyncBlockedUntilLocalChange(false)
        syncPreferences.setLastLifecycleAutoSyncAt(System.currentTimeMillis())
    }

    fun shouldSkipAutoSyncForUnchangedData(reason: String): Boolean {
        if (isLifecycleSyncReason(reason)) return false
        val lastSynced = lastSyncedGeneration ?: return false
        return lastSynced == localChangeGeneration
    }

    fun shouldThrottleLifecycleSync(now: Long, lastSyncAt: Long?): Boolean {
        if (lastSyncAt == null) return false
        if (now - lastSyncAt >= LIFECYCLE_SYNC_MINIMUM_INTERVAL_MS) return false
        val lastLifecycleSyncAt = syncPreferences.getLastLifecycleAutoSyncAt()
        if (lastLifecycleSyncAt <= 0L) return false
        return now - lastLifecycleSyncAt < LIFECYCLE_SYNC_MINIMUM_INTERVAL_MS
    }

    private fun isLifecycleSyncReason(reason: String): Boolean {
        return reason == "scene-active" || reason == "app-load" || reason == "app-start"
    }

    private companion object {
        private const val LIFECYCLE_SYNC_MINIMUM_INTERVAL_MS = 5L * 60L * 1000L
    }
}
