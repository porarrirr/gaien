package com.studyapp.domain.repository

import com.studyapp.domain.model.AppPreferences
import kotlinx.coroutines.flow.Flow

interface AppPreferencesRepository {
    fun observePreferences(): Flow<AppPreferences>
    fun loadPreferences(): AppPreferences
    suspend fun savePreferences(preferences: AppPreferences)
}
