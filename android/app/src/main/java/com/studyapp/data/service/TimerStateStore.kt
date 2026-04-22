package com.studyapp.data.service

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.datastore.preferences.core.stringPreferencesKey
import com.studyapp.domain.model.StudySessionInterval
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import org.json.JSONObject

private val Context.timerDataStore: DataStore<Preferences> by preferencesDataStore(name = "timer_state")

data class TimerState(
    val elapsedTime: Long = 0L,
    val subjectId: Long? = null,
    val subjectSyncId: String? = null,
    val materialId: Long? = null,
    val materialSyncId: String? = null,
    val completedIntervals: List<StudySessionInterval> = emptyList(),
    val isRunning: Boolean = false,
    val startTime: Long = 0L
)

class TimerStateStore(private val context: Context) {
    
    companion object {
        private val ELAPSED_TIME_KEY = longPreferencesKey("elapsed_time")
        private val SUBJECT_ID_KEY = longPreferencesKey("subject_id")
        private val SUBJECT_SYNC_ID_KEY = stringPreferencesKey("subject_sync_id")
        private val MATERIAL_ID_KEY = longPreferencesKey("material_id")
        private val MATERIAL_SYNC_ID_KEY = stringPreferencesKey("material_sync_id")
        private val COMPLETED_INTERVALS_KEY = stringPreferencesKey("completed_intervals")
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
            subjectSyncId = prefs[SUBJECT_SYNC_ID_KEY]?.takeIf { it.isNotBlank() },
            materialId = prefs[MATERIAL_ID_KEY]?.takeIf { it > 0 },
            materialSyncId = prefs[MATERIAL_SYNC_ID_KEY]?.takeIf { it.isNotBlank() },
            completedIntervals = prefs[COMPLETED_INTERVALS_KEY].toIntervals(),
            isRunning = isRunning,
            startTime = startTime
        )
    }
    
    suspend fun updateTimerState(state: TimerState) {
        context.timerDataStore.edit { prefs ->
            prefs[ELAPSED_TIME_KEY] = state.elapsedTime
            prefs[SUBJECT_ID_KEY] = state.subjectId ?: -1
            if (state.subjectSyncId.isNullOrBlank()) {
                prefs.remove(SUBJECT_SYNC_ID_KEY)
            } else {
                prefs[SUBJECT_SYNC_ID_KEY] = state.subjectSyncId
            }
            prefs[MATERIAL_ID_KEY] = state.materialId ?: -1
            if (state.materialSyncId.isNullOrBlank()) {
                prefs.remove(MATERIAL_SYNC_ID_KEY)
            } else {
                prefs[MATERIAL_SYNC_ID_KEY] = state.materialSyncId
            }
            state.completedIntervals.toJson()?.let { prefs[COMPLETED_INTERVALS_KEY] = it }
                ?: prefs.remove(COMPLETED_INTERVALS_KEY)
            prefs[IS_RUNNING_KEY] = if (state.isRunning) 1L else 0L
            prefs[START_TIME_KEY] = state.startTime
        }
    }
    
    suspend fun clearTimerState() {
        context.timerDataStore.edit { prefs ->
            prefs.remove(ELAPSED_TIME_KEY)
            prefs.remove(SUBJECT_ID_KEY)
            prefs.remove(SUBJECT_SYNC_ID_KEY)
            prefs.remove(MATERIAL_ID_KEY)
            prefs.remove(MATERIAL_SYNC_ID_KEY)
            prefs.remove(COMPLETED_INTERVALS_KEY)
            prefs.remove(IS_RUNNING_KEY)
            prefs.remove(START_TIME_KEY)
        }
    }

    private fun String?.toIntervals(): List<StudySessionInterval> {
        if (this.isNullOrBlank()) {
            return emptyList()
        }
        val jsonArray = JSONArray(this)
        return buildList(jsonArray.length()) {
            for (index in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(index) ?: continue
                add(
                    StudySessionInterval(
                        startTime = item.optLong("startTime"),
                        endTime = item.optLong("endTime")
                    )
                )
            }
        }
    }

    private fun List<StudySessionInterval>.toJson(): String? {
        if (isEmpty()) {
            return null
        }
        return JSONArray(
            map { interval ->
                JSONObject().apply {
                    put("startTime", interval.startTime)
                    put("endTime", interval.endTime)
                }
            }
        ).toString()
    }
}
