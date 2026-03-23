package com.studyapp.domain.repository

import com.studyapp.domain.model.AnkiTodayStats
import kotlinx.coroutines.flow.Flow

interface AnkiRepository {
    fun observeTodayStats(): Flow<AnkiTodayStats>

    suspend fun refreshTodayStats()
}
