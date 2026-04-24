package com.studyapp.data.service

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import com.studyapp.domain.usecase.TimerServiceManager
import com.studyapp.domain.usecase.TimerStopResult
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.presentation.timer.TimerService
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TimerServiceManagerImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val timerStateStore: TimerStateStore
) : TimerServiceManager {
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var timerService: TimerService? = null
    private var serviceStateJob: Job? = null
    private var hasActiveBinding = false
    private val _isBound = MutableStateFlow(false)
    private val _timerState = MutableStateFlow(TimerState())

    init {
        scope.launch {
            timerStateStore.timerState.collect { state ->
                if (timerService == null) {
                    _timerState.value = state
                }
            }
        }
    }
    
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as? TimerService.LocalBinder ?: return
            connectToService(binder.getService())
            _isBound.value = true
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            disconnectFromService()
        }
    }
    
    override fun bind() {
        if (hasActiveBinding) {
            return
        }
        val intent = Intent(context, TimerService::class.java)
        hasActiveBinding = context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }
    
    override fun unbind() {
        if (!hasActiveBinding) {
            return
        }
        try {
            context.unbindService(serviceConnection)
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            hasActiveBinding = false
            disconnectFromService()
        }
    }
    
    override fun startTimer(
        subjectId: Long,
        subjectSyncId: String?,
        materialId: Long?,
        materialSyncId: String?,
        mode: TimerMode,
        targetDurationMillis: Long?
    ) {
        val service = timerService
        if (service != null) {
            service.startTimer(subjectId, subjectSyncId, materialId, materialSyncId, mode, targetDurationMillis)
        } else {
            val intent = Intent(context, TimerService::class.java).apply {
                action = TimerService.ACTION_START
                putExtra("subjectId", subjectId)
                putExtra("subjectSyncId", subjectSyncId)
                putExtra("materialId", materialId ?: -1)
                putExtra("materialSyncId", materialSyncId)
                putExtra("mode", mode.name)
                putExtra("targetDurationMillis", targetDurationMillis ?: -1L)
            }
            context.startForegroundService(intent)
        }
    }
    
    override fun pauseTimer() {
        val service = timerService
        if (service != null) {
            service.pauseTimer()
        } else {
            val intent = Intent(context, TimerService::class.java).apply {
                action = TimerService.ACTION_PAUSE
            }
            context.startService(intent)
        }
    }
    
    override fun stopTimer(): TimerStopResult {
        val service = timerService
        return if (service != null) {
            service.stopTimer()
        } else {
            val intent = Intent(context, TimerService::class.java).apply {
                action = TimerService.ACTION_STOP
            }
            context.startService(intent)

            val currentState = _timerState.value
            val intervals = completeIntervals(currentState)
            _timerState.value = TimerState()

            TimerStopResult(
                elapsed = intervals.sumOf { it.duration },
                materialId = currentState.materialId,
                intervals = intervals,
                sessionType = currentState.run {
                    when (mode) {
                        TimerMode.STOPWATCH -> com.studyapp.domain.model.StudySessionType.STOPWATCH
                        TimerMode.TIMER -> com.studyapp.domain.model.StudySessionType.TIMER
                    }
                }
            )
        }
    }
    
    override val elapsedTime: Flow<Long>
        get() = _timerState.asStateFlow().map { it.elapsedTime }.distinctUntilChanged()

    override val remainingTime: Flow<Long>
        get() = _timerState.asStateFlow().map { state ->
            if (state.mode != TimerMode.TIMER) {
                0L
            } else {
                ((state.targetDurationMillis ?: 0L) - state.elapsedTime).coerceAtLeast(0L)
            }
        }.distinctUntilChanged()
    
    override val isRunning: Flow<Boolean>
        get() = _timerState.asStateFlow().map { it.isRunning }.distinctUntilChanged()
    
    override val isBound: Flow<Boolean>
        get() = _isBound.asStateFlow()

    override val currentSubjectId: Flow<Long?>
        get() = _timerState.asStateFlow().map { it.subjectId }.distinctUntilChanged()

    override val currentSubjectSyncId: Flow<String?>
        get() = _timerState.asStateFlow().map { it.subjectSyncId }.distinctUntilChanged()

    override val currentMaterialId: Flow<Long?>
        get() = _timerState.asStateFlow().map { it.materialId }.distinctUntilChanged()

    override val currentMaterialSyncId: Flow<String?>
        get() = _timerState.asStateFlow().map { it.materialSyncId }.distinctUntilChanged()

    override val currentMode: Flow<TimerMode>
        get() = _timerState.asStateFlow().map { it.mode }.distinctUntilChanged()

    override val currentTargetDurationMillis: Flow<Long?>
        get() = _timerState.asStateFlow().map { it.targetDurationMillis }.distinctUntilChanged()

    private fun connectToService(service: TimerService) {
        timerService = service
        serviceStateJob?.cancel()
        serviceStateJob = scope.launch {
            service.timerState.collect { state ->
                _timerState.value = state
            }
        }
    }

    private fun disconnectFromService() {
        serviceStateJob?.cancel()
        serviceStateJob = null
        timerService = null
        _isBound.value = false
    }

    private fun completeIntervals(state: TimerState) =
        if (state.isRunning && state.startTime > 0L) {
            state.completedIntervals + com.studyapp.domain.model.StudySessionInterval(
                startTime = state.startTime,
                endTime = System.currentTimeMillis()
            )
        } else if (state.completedIntervals.isNotEmpty() || state.elapsedTime <= 0L) {
            state.completedIntervals
        } else {
            listOf(
                com.studyapp.domain.model.StudySessionInterval(
                    startTime = System.currentTimeMillis() - state.elapsedTime,
                    endTime = System.currentTimeMillis()
                )
            )
        }
}
