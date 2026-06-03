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
            GREEN -> 0x2E9D45
            BLUE -> 0x1E88E5
            ORANGE -> 0xF59E0B
        }

    val accentHex: Long
        get() = when (this) {
            GREEN -> 0x1E88E5
            BLUE -> 0x2E9D45
            ORANGE -> 0x1E88E5
        }
}

@Serializable
enum class LandscapeTimerDisplayPreset {
    PROBLEM_PROGRESS,
    CLOCK_ONLY;

    val title: String
        get() = when (this) {
            PROBLEM_PROGRESS -> "問題集つき"
            CLOCK_ONLY -> "時計のみ"
        }

    val settingsDescription: String
        get() = when (this) {
            PROBLEM_PROGRESS -> "横向き時に問題番号タイルと時計を並べて表示します。"
            CLOCK_ONLY -> "横向き時は時計と小さい操作ボタンだけを表示します。"
        }
}

@Serializable
enum class TimerNotificationDisplayPreset {
    STANDARD,
    FOCUS,
    PROGRESS,
    SUBJECT_DETAIL;

    val title: String
        get() = when (this) {
            STANDARD -> "標準"
            FOCUS -> "集中"
            PROGRESS -> "進捗"
            SUBJECT_DETAIL -> "科目詳細"
        }

    val settingsDescription: String
        get() = when (this) {
            STANDARD -> "経過時間を大きく表示し、科目と教材を並べます。"
            FOCUS -> "経過時間を最優先で表示し、補助情報を最小にします。"
            PROGRESS -> "経過時間に加えて今日の記録時間と目標を表示します。"
            SUBJECT_DETAIL -> "科目名を主役にして教材と開始時刻を表示します。"
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
    val timerNotificationRichEnabled: Boolean = true,
    val timerNotificationDisplayPreset: TimerNotificationDisplayPreset = TimerNotificationDisplayPreset.STANDARD,
    val landscapeTimerDisplayPreset: LandscapeTimerDisplayPreset = LandscapeTimerDisplayPreset.PROBLEM_PROGRESS,
    val focusModePromptOnTimerStart: Boolean = false,
    val activeTimer: TimerSnapshot? = null
)
