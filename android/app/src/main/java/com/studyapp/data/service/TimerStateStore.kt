package com.studyapp.data.service

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.timerDataStore: DataStore<Preferences> by preferencesDataStore(name = "timer_state")

data class TimerState(
    val elapsedTime: Long = 0L,
    val subjectId: Long? = null,
    val materialId: Long? = null,
    val isRunning: Boolean = false,
    val startTime: Long = 0L
)

class TimerStateStore(private val context: Context) {
    
    companion object {
        private val ELAPSED_TIME_KEY = longPreferencesKey("elapsed_time")
        private val SUBJECT_ID_KEY = longPreferencesKey("subject_id")
        private val MATERIAL_ID_KEY = longPreferencesKey("material_id")
        private val IS_RUNNING_KEY = longPreferencesKey("is_running")
        private val START_TIME_KEY = longPreferencesKey("start_time")
    }
    
    val timerState: Flow<TimerState> = context.timerDataStore.data.map { prefs ->
        val startTime = prefs[START_TIME_KEY] ?: 0L
        val isRunning = prefs[IS_RUNNING_KEY] == 1L
        val elapsedTime = if (isRunning && startTime > 0) {
            System.currentTimeMillis() - startTime
        } else {
            prefs[ELAPSED_TIME_KEY] ?: 0L
        }
        TimerState(
            elapsedTime = elapsedTime,
            subjectId = prefs[SUBJECT_ID_KEY]?.takeIf { it > 0 },
            materialId = prefs[MATERIAL_ID_KEY]?.takeIf { it > 0 },
            isRunning = isRunning,
            startTime = startTime
        )
    }
    
    suspend fun updateTimerState(state: TimerState) {
        context.timerDataStore.edit { prefs ->
            prefs[ELAPSED_TIME_KEY] = state.elapsedTime
            prefs[SUBJECT_ID_KEY] = state.subjectId ?: -1
            prefs[MATERIAL_ID_KEY] = state.materialId ?: -1
            prefs[IS_RUNNING_KEY] = if (state.isRunning) 1L else 0L
            prefs[START_TIME_KEY] = state.startTime
        }
    }
    
    suspend fun clearTimerState() {
        context.timerDataStore.edit { prefs ->
            prefs.remove(ELAPSED_TIME_KEY)
            prefs.remove(SUBJECT_ID_KEY)
            prefs.remove(MATERIAL_ID_KEY)
            prefs.remove(IS_RUNNING_KEY)
            prefs.remove(START_TIME_KEY)
        }
    }
}