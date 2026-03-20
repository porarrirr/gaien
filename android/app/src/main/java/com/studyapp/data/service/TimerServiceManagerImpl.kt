package com.studyapp.data.service

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import com.studyapp.domain.usecase.TimerServiceManager
import com.studyapp.presentation.timer.TimerService
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
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
    private val _elapsedTime = MutableStateFlow(0L)
    private val _isRunning = MutableStateFlow(false)
    private val _currentSubjectId = MutableStateFlow<Long?>(null)
    private val _currentMaterialId = MutableStateFlow<Long?>(null)

    init {
        scope.launch {
            timerStateStore.timerState.collect { state ->
                if (timerService == null) {
                    _elapsedTime.value = state.elapsedTime
                    _isRunning.value = state.isRunning
                    _currentSubjectId.value = state.subjectId
                    _currentMaterialId.value = state.materialId
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
    
    override fun startTimer(subjectId: Long, materialId: Long?) {
        val service = timerService
        if (service != null) {
            service.startTimer(subjectId, materialId)
        } else {
            val intent = Intent(context, TimerService::class.java).apply {
                action = TimerService.ACTION_START
                putExtra("subjectId", subjectId)
                putExtra("materialId", materialId ?: -1)
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
    
    override fun stopTimer(): Pair<Long, Long?> {
        val service = timerService
        return if (service != null) {
            service.stopTimer()
        } else {
            val intent = Intent(context, TimerService::class.java).apply {
                action = TimerService.ACTION_STOP
            }
            context.startService(intent)

            val elapsedTime = _elapsedTime.value
            val materialId = _currentMaterialId.value
            _elapsedTime.value = 0L
            _isRunning.value = false
            _currentSubjectId.value = null
            _currentMaterialId.value = null

            Pair(elapsedTime, materialId)
        }
    }
    
    override val elapsedTime: Flow<Long>
        get() = _elapsedTime.asStateFlow()
    
    override val isRunning: Flow<Boolean>
        get() = _isRunning.asStateFlow()
    
    override val isBound: Flow<Boolean>
        get() = _isBound.asStateFlow()

    private fun connectToService(service: TimerService) {
        timerService = service
        serviceStateJob?.cancel()
        serviceStateJob = scope.launch {
            combine(
                service.elapsedTime,
                service.isRunning,
                service.currentSubjectId,
                service.currentMaterialId
            ) { elapsedTime, isRunning, subjectId, materialId ->
                TimerStateSnapshot(elapsedTime, isRunning, subjectId, materialId)
            }.collect { snapshot ->
                _elapsedTime.value = snapshot.elapsedTime
                _isRunning.value = snapshot.isRunning
                _currentSubjectId.value = snapshot.subjectId
                _currentMaterialId.value = snapshot.materialId
            }
        }
    }

    private fun disconnectFromService() {
        serviceStateJob?.cancel()
        serviceStateJob = null
        timerService = null
        _isBound.value = false
    }

    private data class TimerStateSnapshot(
        val elapsedTime: Long,
        val isRunning: Boolean,
        val subjectId: Long?,
        val materialId: Long?
    )
}
