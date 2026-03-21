package com.studyapp.presentation.timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.studyapp.MainActivity
import com.studyapp.R
import com.studyapp.data.service.TimerState
import com.studyapp.data.service.TimerStateStore
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.util.Result
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import javax.inject.Inject

@AndroidEntryPoint
class TimerService : Service() {
    
    @Inject
    lateinit var timerStateStore: TimerStateStore

    @Inject
    lateinit var saveStudySessionUseCase: SaveStudySessionUseCase
    
    companion object {
        const val CHANNEL_ID = "timer_channel"
        const val NOTIFICATION_ID = 1001
        
        const val ACTION_START = "com.studyapp.action.START_TIMER"
        const val ACTION_PAUSE = "com.studyapp.action.PAUSE_TIMER"
        const val ACTION_STOP = "com.studyapp.action.STOP_TIMER"
        const val ACTION_STOP_AND_SAVE = "com.studyapp.action.STOP_TIMER_AND_SAVE"

        private const val TAG = "TimerService"
    }
    
    private val binder = LocalBinder()
    private var timerJob: Job? = null
    private lateinit var notificationManager: NotificationManager
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _timerState = MutableStateFlow(TimerState())
    val timerState: StateFlow<TimerState> = _timerState.asStateFlow()
    
    private var notificationIconResId: Int = android.R.drawable.ic_menu_recent_history
    
    inner class LocalBinder : Binder() {
        fun getService(): TimerService = this@TimerService
    }
    
    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        resolveNotificationIcon()
        restoreTimerState()
    }
    
    private fun restoreTimerState() {
        serviceScope.launch {
            val persistedState = timerStateStore.timerState.first()
            if (persistedState.subjectId == null && persistedState.elapsedTime <= 0L) {
                return@launch
            }

            val restoredState = persistedState.copy(
                elapsedTime = currentElapsedTime(persistedState)
            )
            _timerState.value = restoredState

            if (restoredState.isRunning && restoredState.subjectId != null) {
                startTicker()
                tryStartForeground(restoredState)
            }
        }
    }
    
    private fun resolveNotificationIcon() {
        notificationIconResId = try {
            val resId = R.drawable.ic_timer
            if (resId != 0) resId else android.R.drawable.ic_menu_recent_history
        } catch (e: Exception) {
            android.R.drawable.ic_menu_recent_history
        }
    }
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val subjectId = intent.getLongExtra("subjectId", -1).takeIf { it > 0 }
                val materialId = intent.getLongExtra("materialId", -1).takeIf { it > 0 }
                if (subjectId != null) {
                    startTimer(subjectId, materialId)
                }
            }
            ACTION_PAUSE -> pauseTimer()
            ACTION_STOP -> stopTimer()
            ACTION_STOP_AND_SAVE -> serviceScope.launch { stopTimerAndPersist() }
        }
        return START_NOT_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        timerJob?.cancel()
        serviceScope.cancel()
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val pauseIntent = Intent(this, TimerService::class.java).apply {
            action = ACTION_PAUSE
        }
        val pausePendingIntent = PendingIntent.getService(
            this, 1, pauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val stopIntent = Intent(this, TimerService::class.java).apply {
            action = ACTION_STOP_AND_SAVE
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val state = _timerState.value
        val time = state.elapsedTime
        val hours = time / 3600000
        val minutes = (time % 3600000) / 60000
        val seconds = (time % 60000) / 1000
        val timeText = if (hours > 0) {
            String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
        
        val pauseIconResId = try {
            val resId = R.drawable.ic_pause
            if (resId != 0) resId else android.R.drawable.ic_media_pause
        } catch (e: Exception) {
            android.R.drawable.ic_media_pause
        }
        
        val stopIconResId = try {
            val resId = R.drawable.ic_stop
            if (resId != 0) resId else android.R.drawable.ic_media_pause
        } catch (e: Exception) {
            android.R.drawable.ic_media_pause
        }
        
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.timer_running))
            .setContentText(timeText)
            .setSmallIcon(notificationIconResId)
            .setContentIntent(pendingIntent)
            .setContentTitle(
                getString(
                    if (state.isRunning) {
                        R.string.timer_running
                    } else {
                        R.string.timer_notification_paused
                    }
                )
            )
            .setOngoing(state.isRunning)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        if (state.isRunning) {
            builder.addAction(pauseIconResId, getString(R.string.pause), pausePendingIntent)
        }

        builder.addAction(stopIconResId, getString(R.string.timer_stop), stopPendingIntent)
        return builder.build()
    }
    
    fun startTimer(subjectId: Long, materialId: Long?) {
        val currentState = _timerState.value
        if (currentState.isRunning) return

        val updatedState = currentState.copy(
            subjectId = subjectId,
            materialId = materialId,
            isRunning = true,
            startTime = System.currentTimeMillis() - currentState.elapsedTime
        )
        _timerState.value = updatedState
        persistTimerState(updatedState)

        startTicker()
        tryStartForeground(updatedState)
    }
    
    fun pauseTimer() {
        timerJob?.cancel()
        val pausedState = _timerState.value.pause()
        _timerState.value = pausedState
        persistTimerState(pausedState)
        updateNotification()
    }
    
    fun stopTimer(): Pair<Long, Long?> {
        val stoppedTimer = clearTimerState()
        return Pair(stoppedTimer.elapsed, stoppedTimer.materialId)
    }

    private suspend fun stopTimerAndPersist() {
        val stoppedTimer = clearTimerState()
        val subjectId = stoppedTimer.subjectId ?: return
        if (stoppedTimer.elapsed <= 0L) {
            return
        }

        when (val result = saveStudySessionUseCase(subjectId, stoppedTimer.materialId, stoppedTimer.elapsed)) {
            is Result.Error -> {
                Log.e(TAG, "Failed to save session from timer notification", result.exception)
            }
            is Result.Success -> Unit
        }
    }

    private fun clearTimerState(): StoppedTimer {
        timerJob?.cancel()
        val currentState = _timerState.value
        val stoppedTimer = StoppedTimer(
            subjectId = currentState.subjectId,
            materialId = currentState.materialId,
            elapsed = currentElapsedTime(currentState)
        )
        _timerState.value = TimerState()
        
        clearPersistedTimerState()
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        return stoppedTimer
    }
    
    private fun updateNotification() {
        notificationManager.notify(NOTIFICATION_ID, createNotification())
    }
    
    private fun persistTimerState(state: TimerState = _timerState.value) {
        serviceScope.launch {
            timerStateStore.updateTimerState(state)
        }
    }
    
    private fun clearPersistedTimerState() {
        serviceScope.launch {
            timerStateStore.clearTimerState()
        }
    }
    
    fun setElapsedTime(elapsedTime: Long) {
        _timerState.update { state ->
            state.copy(
                elapsedTime = elapsedTime,
                startTime = if (state.isRunning) {
                    System.currentTimeMillis() - elapsedTime
                } else {
                    0L
                }
            )
        }
    }
    
    fun getElapsedTime(): Long = currentElapsedTime(_timerState.value)
    
    fun isRunning(): Boolean = _timerState.value.isRunning

    private fun startTicker() {
        timerJob?.cancel()
        timerJob = serviceScope.launch {
            while (_timerState.value.isRunning) {
                delay(1000)
                _timerState.update { state ->
                    if (!state.isRunning) {
                        state
                    } else {
                        state.copy(elapsedTime = currentElapsedTime(state))
                    }
                }
                updateNotification()
            }
        }
    }

    private fun tryStartForeground(state: TimerState) {
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } catch (e: Exception) {
            timerJob?.cancel()
            val pausedState = state.pause()
            _timerState.value = pausedState
            persistTimerState(pausedState)
        }
    }

    private fun currentElapsedTime(state: TimerState): Long {
        return if (state.isRunning && state.startTime > 0L) {
            System.currentTimeMillis() - state.startTime
        } else {
            state.elapsedTime
        }
    }

    private fun TimerState.pause(): TimerState {
        return copy(
            elapsedTime = currentElapsedTime(this),
            isRunning = false,
            startTime = 0L
        )
    }

    private data class StoppedTimer(
        val subjectId: Long?,
        val materialId: Long?,
        val elapsed: Long
    )
}
