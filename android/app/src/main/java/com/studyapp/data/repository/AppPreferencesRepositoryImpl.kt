package com.studyapp.data.repository

import android.content.Context
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.studyapp.domain.model.AppPreferences
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.LandscapeTimerDisplayPreset
import com.studyapp.domain.model.ThemeMode
import com.studyapp.domain.model.TimerNotificationDisplayPreset
import com.studyapp.domain.model.TimerSnapshot
import com.studyapp.domain.repository.AppPreferencesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val Context.appPreferencesDataStore: DataStore<Preferences> by preferencesDataStore(name = "app_preferences")

@Singleton
class AppPreferencesRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context
) : AppPreferencesRepository {
    private companion object {
        const val TAG = "AppPreferencesRepo"
    }

    private object Keys {
        val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
        val REMINDER_ENABLED = booleanPreferencesKey("reminder_enabled")
        val REMINDER_HOUR = intPreferencesKey("reminder_hour")
        val REMINDER_MINUTE = intPreferencesKey("reminder_minute")
        val COLOR_THEME = intPreferencesKey("color_theme")
        val THEME_MODE = intPreferencesKey("theme_mode")
        val ACTIVE_TIMER = stringPreferencesKey("active_timer")
        val TIMER_NOTIFICATION_RICH_ENABLED = booleanPreferencesKey("timer_notification_rich_enabled")
        val TIMER_NOTIFICATION_DISPLAY_PRESET = intPreferencesKey("timer_notification_display_preset")
        val LANDSCAPE_TIMER_DISPLAY_PRESET = intPreferencesKey("landscape_timer_display_preset")
        val FOCUS_MODE_ENABLED = booleanPreferencesKey("focus_mode_enabled")
        val FOCUS_MODE_PROMPT_ON_TIMER_START = booleanPreferencesKey("focus_mode_prompt_on_timer_start")
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
            prefs[Keys.TIMER_NOTIFICATION_RICH_ENABLED] = preferences.timerNotificationRichEnabled
            prefs[Keys.TIMER_NOTIFICATION_DISPLAY_PRESET] = preferences.timerNotificationDisplayPreset.ordinal
            prefs[Keys.LANDSCAPE_TIMER_DISPLAY_PRESET] = preferences.landscapeTimerDisplayPreset.ordinal
            prefs[Keys.FOCUS_MODE_ENABLED] = preferences.focusModeEnabled
            prefs[Keys.FOCUS_MODE_PROMPT_ON_TIMER_START] = preferences.focusModePromptOnTimerStart
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

        val notificationPresetOrdinal = this[Keys.TIMER_NOTIFICATION_DISPLAY_PRESET]
            ?: TimerNotificationDisplayPreset.STANDARD.ordinal
        val landscapePresetOrdinal = this[Keys.LANDSCAPE_TIMER_DISPLAY_PRESET]
            ?: LandscapeTimerDisplayPreset.PROBLEM_PROGRESS.ordinal

        return AppPreferences(
            onboardingCompleted = this[Keys.ONBOARDING_COMPLETED] ?: false,
            reminderEnabled = this[Keys.REMINDER_ENABLED] ?: false,
            reminderHour = this[Keys.REMINDER_HOUR] ?: 19,
            reminderMinute = this[Keys.REMINDER_MINUTE] ?: 0,
            selectedColorTheme = ColorTheme.entries.getOrNull(colorThemeOrdinal) ?: ColorTheme.GREEN,
            selectedThemeMode = ThemeMode.entries.getOrNull(themeModeOrdinal) ?: ThemeMode.SYSTEM,
            timerNotificationRichEnabled = this[Keys.TIMER_NOTIFICATION_RICH_ENABLED] ?: true,
            timerNotificationDisplayPreset = TimerNotificationDisplayPreset.entries
                .getOrNull(notificationPresetOrdinal) ?: TimerNotificationDisplayPreset.STANDARD,
            landscapeTimerDisplayPreset = LandscapeTimerDisplayPreset.entries
                .getOrNull(landscapePresetOrdinal) ?: LandscapeTimerDisplayPreset.PROBLEM_PROGRESS,
            focusModeEnabled = this[Keys.FOCUS_MODE_ENABLED]
                ?: (this[Keys.FOCUS_MODE_PROMPT_ON_TIMER_START] ?: false),
            focusModePromptOnTimerStart = this[Keys.FOCUS_MODE_PROMPT_ON_TIMER_START] ?: false,
            activeTimer = decodeActiveTimer(activeTimerJson)
        )
    }

    private fun decodeActiveTimer(rawValue: String?): TimerSnapshot? {
        if (rawValue == null) return null
        return try {
            json.decodeFromString<TimerSnapshot>(rawValue)
        } catch (exception: SerializationException) {
            Log.e(TAG, "Failed to decode active timer preferences", exception)
            null
        } catch (exception: IllegalArgumentException) {
            Log.e(TAG, "Invalid active timer preferences", exception)
            null
        }
    }
}
