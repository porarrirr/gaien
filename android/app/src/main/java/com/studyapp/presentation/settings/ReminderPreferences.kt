package com.studyapp.presentation.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.reminderDataStore: DataStore<Preferences> by preferencesDataStore(name = "reminder_prefs")

object ReminderKeys {
    val ENABLED = booleanPreferencesKey("reminder_enabled")
    val HOUR = intPreferencesKey("reminder_hour")
    val MINUTE = intPreferencesKey("reminder_minute")
}

@Singleton
class ReminderPreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun isReminderEnabled(): Flow<Boolean> {
        return context.reminderDataStore.data.map { prefs ->
            prefs[ReminderKeys.ENABLED] ?: false
        }
    }

    fun getReminderTime(): Flow<String> {
        return context.reminderDataStore.data.map { prefs ->
            val hour = prefs[ReminderKeys.HOUR] ?: DEFAULT_HOUR
            val minute = prefs[ReminderKeys.MINUTE] ?: DEFAULT_MINUTE
            String.format(Locale.ROOT, "%02d:%02d", hour, minute)
        }
    }

    suspend fun setReminderEnabled(enabled: Boolean) {
        context.reminderDataStore.edit { prefs ->
            prefs[ReminderKeys.ENABLED] = enabled
        }
    }

    suspend fun setReminderTime(hour: Int, minute: Int) {
        context.reminderDataStore.edit { prefs ->
            prefs[ReminderKeys.HOUR] = hour
            prefs[ReminderKeys.MINUTE] = minute
        }
    }

    companion object {
        private const val DEFAULT_HOUR = 19
        private const val DEFAULT_MINUTE = 0
    }
}
