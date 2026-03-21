package com.studyapp.sync

import android.util.Log
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

@Singleton
class AutoSyncManager @Inject constructor(
    private val authRepository: AuthRepository,
    private val syncRepository: SyncRepository,
    private val syncChangeNotifier: SyncChangeNotifier
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var localChangeDebounceJob: Job? = null
    private var autoSyncJob: Job? = null

    @Volatile
    private var started = false

    @Volatile
    private var localChangePending = false

    fun start() {
        if (started) return
        started = true

        requestSync(reason = "app-start")

        scope.launch {
            authRepository.session
                .map { it?.localId }
                .distinctUntilChanged()
                .drop(1)
                .collect { userId ->
                    if (!userId.isNullOrEmpty()) {
                        requestSync(reason = "auth-session")
                    }
                }
        }

        scope.launch {
            syncChangeNotifier.events.collect {
                localChangePending = true
                localChangeDebounceJob?.cancel()
                localChangeDebounceJob = scope.launch {
                    delay(AUTO_SYNC_DEBOUNCE_MS)
                    requestSync(reason = "local-change")
                }
            }
        }
    }

    private fun requestSync(reason: String) {
        if (autoSyncJob?.isActive == true) return

        autoSyncJob = scope.launch {
            do {
                val syncReason = if (localChangePending) {
                    localChangePending = false
                    "local-change"
                } else {
                    reason
                }
                syncIfPossible(reason = syncReason)
            } while (localChangePending)
        }
    }

    private suspend fun syncIfPossible(reason: String) {
        if (authRepository.session.value == null) return
        if (syncChangeNotifier.isAutoSyncBlockedUntilLocalChange()) {
            Log.i(TAG, "Auto sync skipped because it is blocked until the next local change: reason=$reason")
            return
        }
        if (syncRepository.status.value.isSyncing) return

        runCatching {
            syncRepository.syncNow()
        }.onFailure { error ->
            Log.w(TAG, "Auto sync skipped or failed: reason=$reason", error)
        }
    }

    private companion object {
        private const val TAG = "AutoSyncManager"
        private const val AUTO_SYNC_DEBOUNCE_MS = 2_000L
    }
}
