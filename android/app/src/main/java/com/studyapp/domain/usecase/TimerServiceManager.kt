package com.studyapp.domain.usecase

import kotlinx.coroutines.flow.Flow

interface TimerServiceManager {
    fun bind()
    fun unbind()
    fun startTimer(subjectId: Long, subjectSyncId: String?, materialId: Long?, materialSyncId: String?)
    fun pauseTimer()
    fun stopTimer(): Pair<Long, Long?>
    val elapsedTime: Flow<Long>
    val isRunning: Flow<Boolean>
    val isBound: Flow<Boolean>
    val currentSubjectId: Flow<Long?>
    val currentSubjectSyncId: Flow<String?>
    val currentMaterialId: Flow<Long?>
    val currentMaterialSyncId: Flow<String?>
}
