package com.studyapp.widgets

import android.content.Context
import android.util.Log
import com.studyapp.data.service.TimerStateStore
import com.studyapp.sync.SyncChangeNotifier
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

@Singleton
class StudyWidgetRefreshManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val syncChangeNotifier: SyncChangeNotifier,
    private val timerStateStore: TimerStateStore
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    @Volatile
    private var started = false

    fun start() {
        if (started) return
        started = true

        refreshAll("app-start")

        scope.launch {
            syncChangeNotifier.events.collect {
                refreshAll("data-change")
            }
        }

        scope.launch {
            timerStateStore.timerState
                .map { state ->
                    WidgetTimerRefreshKey(
                        isRunning = state.isRunning,
                        subjectId = state.subjectId,
                        subjectSyncId = state.subjectSyncId,
                        materialId = state.materialId,
                        materialSyncId = state.materialSyncId,
                        startTime = state.startTime
                    )
                }
                .distinctUntilChanged()
                .drop(1)
                .collect {
                    refreshAll("timer-change")
                }
        }
    }

    private fun refreshAll(reason: String) {
        scope.launch {
            try {
                StudyWidgets.updateAll(context)
            } catch (exception: Exception) {
                Log.e(TAG, "Failed to refresh widgets for $reason", exception)
            }
        }
    }

    private data class WidgetTimerRefreshKey(
        val isRunning: Boolean,
        val subjectId: Long?,
        val subjectSyncId: String?,
        val materialId: Long?,
        val materialSyncId: String?,
        val startTime: Long
    )

    companion object {
        private const val TAG = "StudyWidgetRefresh"
    }
}
