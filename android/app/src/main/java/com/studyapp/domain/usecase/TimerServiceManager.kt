package com.studyapp.domain.usecase

import kotlinx.coroutines.flow.Flow

interface TimerServiceManager {
    fun bind()
    fun unbind()
    fun startTimer(subjectId: Long, materialId: Long?)
    fun pauseTimer()
    fun stopTimer(): Pair<Long, Long?>
    val elapsedTime: Flow<Long>
    val isRunning: Flow<Boolean>
    val isBound: Flow<Boolean>
    val currentSubjectId: Flow<Long?>
    val currentMaterialId: Flow<Long?>
}
