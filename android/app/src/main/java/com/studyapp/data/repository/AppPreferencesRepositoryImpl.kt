package com.studyapp.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.studyapp.domain.model.AppPreferences
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.ThemeMode
import com.studyapp.domain.model.TimerSnapshot
import com.studyapp.domain.repository.AppPreferencesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val Context.appPreferencesDataStore: DataStore<Preferences> by preferencesDataStore(name = "app_preferences")

@Singleton
class AppPreferencesRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context
) : AppPreferencesRepository {

    private object Keys {
        val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
        val REMINDER_ENABLED = booleanPreferencesKey("reminder_enabled")
        val REMINDER_HOUR = intPreferencesKey("reminder_hour")
        val REMINDER_MINUTE = intPreferencesKey("reminder_minute")
        val COLOR_THEME = intPreferencesKey("color_theme")
        val THEME_MODE = intPreferencesKey("theme_mode")
        val ACTIVE_TIMER = stringPreferencesKey("active_timer")
    }

    private val json = Json { ignoreUnknownKeys = true }

    override fun observePreferences(): Flow<AppPreferences> {
        return context.appPreferencesDataStore.data.map { prefs ->
            prefs.toDomain()
        }
    }

    override fun loadPreferences(): AppPreferences {
        val prefs = kotlinx.coroutines.runBlocking {
            context.appPreferencesDataStore.data.first()
        }
        return prefs.toDomain()
    }

    override suspend fun savePreferences(preferences: AppPreferences) {
        context.appPreferencesDataStore.edit { prefs ->
            prefs[Keys.ONBOARDING_COMPLETED] = preferences.onboardingCompleted
            prefs[Keys.REMINDER_ENABLED] = preferences.reminderEnabled
            prefs[Keys.REMINDER_HOUR] = preferences.reminderHour
            prefs[Keys.REMINDER_MINUTE] = preferences.reminderMinute
            prefs[Keys.COLOR_THEME] = preferences.selectedColorTheme.ordinal
            prefs[Keys.THEME_MODE] = preferences.selectedThemeMode.ordinal
            if (preferences.activeTimer != null) {
                prefs[Keys.ACTIVE_TIMER] = json.encodeToString(preferences.activeTimer)
            } else {
                prefs.remove(Keys.ACTIVE_TIMER)
            }
        }
    }

    private fun Preferences.toDomain(): AppPreferences {
        val colorThemeOrdinal = this[Keys.COLOR_THEME] ?: ColorTheme.GREEN.ordinal
        val themeModeOrdinal = this[Keys.THEME_MODE] ?: ThemeMode.SYSTEM.ordinal
        val activeTimerJson = this[Keys.ACTIVE_TIMER]

        return AppPreferences(
            onboardingCompleted = this[Keys.ONBOARDING_COMPLETED] ?: false,
            reminderEnabled = this[Keys.REMINDER_ENABLED] ?: false,
            reminderHour = this[Keys.REMINDER_HOUR] ?: 19,
            reminderMinute = this[Keys.REMINDER_MINUTE] ?: 0,
            selectedColorTheme = ColorTheme.entries.getOrNull(colorThemeOrdinal) ?: ColorTheme.GREEN,
            selectedThemeMode = ThemeMode.entries.getOrNull(themeModeOrdinal) ?: ThemeMode.SYSTEM,
            activeTimer = activeTimerJson?.let {
                try { json.decodeFromString<TimerSnapshot>(it) } catch (_: Exception) { null }
            }
        )
    }
}
