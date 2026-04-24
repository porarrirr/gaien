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
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.usecase.SaveStudySessionUseCase
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.domain.usecase.TimerStopResult
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
            if (
                persistedState.subjectId == null &&
                persistedState.subjectSyncId == null &&
                persistedState.elapsedTime <= 0L
            ) {
                return@launch
            }

            val restoredState = persistedState.copy(
                elapsedTime = currentElapsedTime(persistedState)
            )
            _timerState.value = restoredState

            if (restoredState.isRunning && (restoredState.subjectId != null || restoredState.subjectSyncId != null)) {
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
                val subjectSyncId = intent.getStringExtra("subjectSyncId")
                val materialId = intent.getLongExtra("materialId", -1).takeIf { it > 0 }
                val materialSyncId = intent.getStringExtra("materialSyncId")
                val mode = intent.getStringExtra("mode")?.let(TimerMode::valueOf) ?: TimerMode.STOPWATCH
                val targetDurationMillis = intent.getLongExtra("targetDurationMillis", -1L).takeIf { it > 0L }
                if (subjectId != null) {
                    startTimer(subjectId, subjectSyncId, materialId, materialSyncId, mode, targetDurationMillis)
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
        val time = if (state.mode == TimerMode.TIMER) currentRemainingTime(state) else state.elapsedTime
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
            .setContentTitle(
                getString(
                    if (state.mode == TimerMode.TIMER) {
                        R.string.timer_screen_title
                    } else {
                        R.string.timer_running
                    }
                )
            )
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
    
    fun startTimer(
        subjectId: Long,
        subjectSyncId: String?,
        materialId: Long?,
        materialSyncId: String?,
        mode: TimerMode,
        targetDurationMillis: Long?
    ) {
        val currentState = _timerState.value
        if (currentState.isRunning) return
        val now = System.currentTimeMillis()
        val completedIntervals = if (
            currentState.elapsedTime > 0L &&
            currentState.completedIntervals.isEmpty()
        ) {
            listOf(
                StudySessionInterval(
                    startTime = now - currentState.elapsedTime,
                    endTime = now
                )
            )
        } else {
            currentState.completedIntervals
        }

        val updatedState = currentState.copy(
            subjectId = subjectId,
            subjectSyncId = subjectSyncId,
            materialId = materialId,
            materialSyncId = materialSyncId,
            elapsedTime = completedIntervals.sumOf { it.duration },
            completedIntervals = completedIntervals,
            mode = mode,
            targetDurationMillis = targetDurationMillis,
            isRunning = true,
            startTime = now
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
    
    fun stopTimer(): TimerStopResult {
        val stoppedTimer = runBlocking { clearTimerStateAndStopService() }
        return TimerStopResult(
            elapsed = stoppedTimer.elapsed,
            materialId = stoppedTimer.materialId,
            intervals = stoppedTimer.intervals,
            sessionType = stoppedTimer.sessionType
        )
    }

    private suspend fun stopTimerAndPersist() {
        val stoppedTimer = clearTimerStateAndStopService()
        if (stoppedTimer.subjectId == null && stoppedTimer.subjectSyncId.isNullOrBlank()) {
            return
        }
        if (stoppedTimer.elapsed <= 0L) {
            return
        }

        when (
            val result = saveStudySessionUseCase(
                subjectId = stoppedTimer.subjectId,
                subjectSyncId = stoppedTimer.subjectSyncId,
                materialId = stoppedTimer.materialId,
                materialSyncId = stoppedTimer.materialSyncId,
                duration = stoppedTimer.elapsed,
                intervals = stoppedTimer.intervals,
                sessionType = stoppedTimer.sessionType
            )
        ) {
            is Result.Error -> {
                Log.e(TAG, "Failed to save session from timer notification", result.exception)
            }
            is Result.Success -> Unit
        }
    }

    private suspend fun clearTimerStateAndStopService(): StoppedTimer {
        timerJob?.cancel()
        val currentState = _timerState.value
        val completedIntervals = completeIntervals(currentState)
        val stoppedTimer = StoppedTimer(
            subjectId = currentState.subjectId,
            subjectSyncId = currentState.subjectSyncId,
            materialId = currentState.materialId,
            materialSyncId = currentState.materialSyncId,
            elapsed = completedIntervals.sumOf { it.duration },
            intervals = completedIntervals,
            sessionType = currentState.sessionType()
        )
        _timerState.value = TimerState()
        
        timerStateStore.clearTimerState()
        
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
    
    fun setElapsedTime(elapsedTime: Long) {
        _timerState.update { state ->
            state.copy(
                elapsedTime = elapsedTime,
                startTime = if (state.isRunning) {
                    System.currentTimeMillis()
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
                if (_timerState.value.mode == TimerMode.TIMER && currentRemainingTime(_timerState.value) <= 0L) {
                    stopTimerAndPersist()
                    break
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
            state.completedIntervals.sumOf { it.duration } + (System.currentTimeMillis() - state.startTime)
        } else {
            state.elapsedTime
        }
    }

    private fun currentRemainingTime(state: TimerState): Long {
        if (state.mode != TimerMode.TIMER) return 0L
        val target = state.targetDurationMillis ?: 0L
        return (target - currentElapsedTime(state)).coerceAtLeast(0L)
    }

    private fun TimerState.pause(): TimerState {
        val updatedIntervals = completeIntervals(this)
        return copy(
            elapsedTime = updatedIntervals.sumOf { it.duration },
            completedIntervals = updatedIntervals,
            isRunning = false,
            startTime = 0L
        )
    }

    private fun completeIntervals(state: TimerState): List<StudySessionInterval> {
        if (!state.isRunning || state.startTime <= 0L) {
            return if (state.completedIntervals.isNotEmpty() || state.elapsedTime <= 0L) {
                state.completedIntervals
            } else {
                listOf(
                    StudySessionInterval(
                        startTime = System.currentTimeMillis() - state.elapsedTime,
                        endTime = System.currentTimeMillis()
                    )
                )
            }
        }
        return state.completedIntervals + StudySessionInterval(
            startTime = state.startTime,
            endTime = System.currentTimeMillis()
        )
    }

    private data class StoppedTimer(
        val subjectId: Long?,
        val subjectSyncId: String?,
        val materialId: Long?,
        val materialSyncId: String?,
        val elapsed: Long,
        val intervals: List<StudySessionInterval>,
        val sessionType: StudySessionType
    )

    private fun TimerState.sessionType(): StudySessionType {
        return when (mode) {
            TimerMode.STOPWATCH -> StudySessionType.STOPWATCH
            TimerMode.TIMER -> StudySessionType.TIMER
        }
    }
}
