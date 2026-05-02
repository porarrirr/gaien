package com.studyapp.domain.model

import kotlinx.serialization.Serializable

@Serializable
enum class ColorTheme {
    GREEN,
    BLUE,
    ORANGE;

    val title: String
        get() = when (this) {
            GREEN -> "グリーン"
            BLUE -> "ブルー"
            ORANGE -> "オレンジ"
        }

    val hex: Long
        get() = when (this) {
            GREEN -> 0x4CAF50
            BLUE -> 0x2196F3
            ORANGE -> 0xFF9800
        }

    val accentHex: Long
        get() = when (this) {
            GREEN -> 0x2196F3
            BLUE -> 0x4CAF50
            ORANGE -> 0x2196F3
        }
}

@Serializable
enum class ThemeMode {
    LIGHT,
    DARK,
    SYSTEM;

    val title: String
        get() = when (this) {
            LIGHT -> "ライト"
            DARK -> "ダーク"
            SYSTEM -> "システム"
        }
}

@Serializable
data class AppPreferences(
    val onboardingCompleted: Boolean = false,
    val reminderEnabled: Boolean = false,
    val reminderHour: Int = 19,
    val reminderMinute: Int = 0,
    val selectedColorTheme: ColorTheme = ColorTheme.GREEN,
    val selectedThemeMode: ThemeMode = ThemeMode.SYSTEM,
    val activeTimer: TimerSnapshot? = null
)
