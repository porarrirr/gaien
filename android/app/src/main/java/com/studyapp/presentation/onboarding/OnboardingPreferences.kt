package com.studyapp.presentation.onboarding

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

val Context.onboardingDataStore: DataStore<Preferences> by preferencesDataStore(name = "onboarding_prefs")

object OnboardingKeys {
    val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
}

@Singleton
class OnboardingPreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun isOnboardingCompleted(): Flow<Boolean> {
        return context.onboardingDataStore.data.map { prefs ->
            prefs[OnboardingKeys.ONBOARDING_COMPLETED] ?: false
        }
    }
    
    suspend fun setOnboardingCompleted(completed: Boolean) {
        context.onboardingDataStore.updateData { prefs ->
            prefs.toMutablePreferences().apply {
                this[OnboardingKeys.ONBOARDING_COMPLETED] = completed
            }
        }
    }
}