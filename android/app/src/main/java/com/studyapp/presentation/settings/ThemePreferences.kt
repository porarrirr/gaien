package com.studyapp.presentation.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

val Context.themeDataStore: DataStore<Preferences> by preferencesDataStore(name = "theme_prefs")

object ThemeKeys {
    val PRIMARY_COLOR = intPreferencesKey("primary_color")
    val THEME_MODE = intPreferencesKey("theme_mode")
}

@Singleton
class ThemePreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun getPrimaryColor(): Flow<ColorTheme> {
        return context.themeDataStore.data.map { prefs ->
            val ordinal = prefs[ThemeKeys.PRIMARY_COLOR] ?: ColorTheme.GREEN.ordinal
            ColorTheme.entries.getOrNull(ordinal) ?: ColorTheme.GREEN
        }
    }

    fun getThemeMode(): Flow<ThemeMode> {
        return context.themeDataStore.data.map { prefs ->
            val modeValue = prefs[ThemeKeys.THEME_MODE] ?: ThemeMode.SYSTEM.ordinal
            ThemeMode.entries.getOrNull(modeValue) ?: ThemeMode.SYSTEM
        }
    }

    suspend fun setPrimaryColor(color: ColorTheme) {
        context.themeDataStore.edit { prefs ->
            prefs[ThemeKeys.PRIMARY_COLOR] = color.ordinal
        }
    }

    suspend fun setThemeMode(mode: ThemeMode) {
        context.themeDataStore.edit { prefs ->
            prefs[ThemeKeys.THEME_MODE] = mode.ordinal
        }
    }
}
