package com.studyapp.presentation.timer

import android.Manifest
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
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.studyapp.MainActivity
import com.studyapp.R
import com.studyapp.data.service.TimerState
import com.studyapp.data.service.TimerStateStore
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import javax.inject.Inject

@AndroidEntryPoint
class TimerService : Service() {
    
    @Inject
    lateinit var timerStateStore: TimerStateStore
    
    companion object {
        const val CHANNEL_ID = "timer_channel"
        const val NOTIFICATION_ID = 1001
        
        const val ACTION_START = "com.studyapp.action.START_TIMER"
        const val ACTION_PAUSE = "com.studyapp.action.PAUSE_TIMER"
        const val ACTION_STOP = "com.studyapp.action.STOP_TIMER"
    }
    
    private val binder = LocalBinder()
    private var timerJob: Job? = null
    private var startTime: Long = 0L
    private lateinit var notificationManager: NotificationManager
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    
    private val _elapsedTime = MutableStateFlow(0L)
    val elapsedTime: StateFlow<Long> = _elapsedTime.asStateFlow()
    
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()
    
    private val _currentSubjectId = MutableStateFlow<Long?>(null)
    val currentSubjectId: StateFlow<Long?> = _currentSubjectId.asStateFlow()
    
    private val _currentMaterialId = MutableStateFlow<Long?>(null)
    val currentMaterialId: StateFlow<Long?> = _currentMaterialId.asStateFlow()
    
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
            timerStateStore.timerState.first().let { state ->
                if (state.isRunning && state.subjectId != null) {
                    _currentSubjectId.value = state.subjectId
                    _currentMaterialId.value = state.materialId
                    startTime = state.startTime
                    val elapsed = if (state.startTime > 0) {
                        System.currentTimeMillis() - state.startTime
                    } else {
                        state.elapsedTime
                    }
                    _elapsedTime.value = elapsed
                    _isRunning.value = true
                    
                    timerJob?.cancel()
                    timerJob = serviceScope.launch {
                        while (_isRunning.value) {
                            delay(1000)
                            _elapsedTime.value = System.currentTimeMillis() - startTime
                            updateNotification()
                        }
                    }
                    try {
                        ServiceCompat.startForeground(
                            this@TimerService,
                            NOTIFICATION_ID,
                            createNotification(),
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                        )
                    } catch (e: Exception) {
                        _isRunning.value = false
                        timerJob?.cancel()
                    }
                }
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
                startTimer(subjectId, materialId)
            }
            ACTION_PAUSE -> pauseTimer()
            ACTION_STOP -> stopTimer()
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
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val time = _elapsedTime.value
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
                    if (_isRunning.value) {
                        R.string.timer_running
                    } else {
                        R.string.timer_notification_paused
                    }
                )
            )
            .setOngoing(_isRunning.value)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        if (_isRunning.value) {
            builder.addAction(pauseIconResId, getString(R.string.pause), pausePendingIntent)
        }

        builder.addAction(stopIconResId, getString(R.string.timer_stop), stopPendingIntent)
        return builder.build()
    }
    
    fun startTimer(subjectId: Long?, materialId: Long?) {
        if (_isRunning.value) return
        
        _currentSubjectId.value = subjectId
        _currentMaterialId.value = materialId
        startTime = System.currentTimeMillis() - _elapsedTime.value
        _isRunning.value = true
        
        persistTimerState()
        
        timerJob?.cancel()
        timerJob = serviceScope.launch {
            while (_isRunning.value) {
                delay(1000)
                _elapsedTime.value = System.currentTimeMillis() - startTime
                updateNotification()
            }
        }
        
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } catch (e: Exception) {
            _isRunning.value = false
            timerJob?.cancel()
            clearPersistedTimerState()
        }
    }
    
    fun pauseTimer() {
        timerJob?.cancel()
        _isRunning.value = false
        persistTimerState()
        updateNotification()
    }
    
    fun stopTimer(): Pair<Long, Long?> {
        timerJob?.cancel()
        val elapsed = _elapsedTime.value
        val subjectId = _currentSubjectId.value
        val materialId = _currentMaterialId.value
        
        _elapsedTime.value = 0L
        _isRunning.value = false
        _currentSubjectId.value = null
        _currentMaterialId.value = null
        
        clearPersistedTimerState()
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        return Pair(elapsed, materialId)
    }
    
    private fun updateNotification() {
        notificationManager.notify(NOTIFICATION_ID, createNotification())
    }
    
    private fun persistTimerState() {
        serviceScope.launch {
            timerStateStore.updateTimerState(
                TimerState(
                    elapsedTime = _elapsedTime.value,
                    subjectId = _currentSubjectId.value,
                    materialId = _currentMaterialId.value,
                    isRunning = _isRunning.value,
                    startTime = startTime
                )
            )
        }
    }
    
    private fun clearPersistedTimerState() {
        serviceScope.launch {
            timerStateStore.clearTimerState()
        }
    }
    
    fun setElapsedTime(elapsedTime: Long) {
        _elapsedTime.value = elapsedTime
        startTime = System.currentTimeMillis() - elapsedTime
    }
    
    fun getElapsedTime(): Long = _elapsedTime.value
    
    fun isRunning(): Boolean = _isRunning.value
}
