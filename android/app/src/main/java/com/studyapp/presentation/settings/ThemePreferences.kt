package com.studyapp.presentation.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
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

enum class ThemeMode {
    LIGHT,
    DARK,
    SYSTEM
}

enum class ColorTheme(val colorValue: Int, val displayName: String) {
    GREEN(0xFF4CAF50.toInt(), "グリーン"),
    BLUE(0xFF2196F3.toInt(), "ブルー"),
    PURPLE(0xFF9C27B0.toInt(), "パープル"),
    ORANGE(0xFFFF9800.toInt(), "オレンジ"),
    RED(0xFFF44336.toInt(), "レッド"),
    TEAL(0xFF009688.toInt(), "ティール")
}

@Singleton
class ThemePreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun getPrimaryColor(): Flow<ColorTheme> {
        return context.themeDataStore.data.map { prefs ->
            val colorValue = prefs[ThemeKeys.PRIMARY_COLOR] ?: ColorTheme.GREEN.colorValue
            ColorTheme.entries.find { it.colorValue == colorValue } ?: ColorTheme.GREEN
        }
    }
    
    fun getThemeMode(): Flow<ThemeMode> {
        return context.themeDataStore.data.map { prefs ->
            val modeValue = prefs[ThemeKeys.THEME_MODE] ?: ThemeMode.SYSTEM.ordinal
            ThemeMode.entries.find { it.ordinal == modeValue } ?: ThemeMode.SYSTEM
        }
    }
    
    suspend fun setPrimaryColor(color: ColorTheme) {
        context.themeDataStore.updateData { prefs ->
            prefs.toMutablePreferences().apply {
                this[ThemeKeys.PRIMARY_COLOR] = color.colorValue
            }
        }
    }
    
    suspend fun setThemeMode(mode: ThemeMode) {
        context.themeDataStore.updateData { prefs ->
            prefs.toMutablePreferences().apply {
                this[ThemeKeys.THEME_MODE] = mode.ordinal
            }
        }
    }
}