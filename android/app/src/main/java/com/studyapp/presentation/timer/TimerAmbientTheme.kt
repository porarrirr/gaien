package com.studyapp.presentation.timer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

data class TimerAmbientTheme(
    val accent: Color,
    val accentSoft: Color,
    val ringTrack: Color,
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val foreground: Color,
    val secondaryForeground: Color,
    val panelOverlay: Color,
    val panelStroke: Color,
    val bottomBarBackground: Color
) {
    companion object {
        @Composable
        fun current(): TimerAmbientTheme {
            return if (isSystemInDarkTheme()) dark() else light()
        }

        fun light(): TimerAmbientTheme = TimerAmbientTheme(
            accent = Color(0xFF4CAF50),
            accentSoft = Color(0xFFE7F6ED),
            ringTrack = Color(0xFFD8DEE8),
            backgroundTop = Color.White,
            backgroundBottom = Color.White,
            foreground = Color(0xFF152332),
            secondaryForeground = Color(0xFF5C6976),
            panelOverlay = Color.White.copy(alpha = 0.92f),
            panelStroke = Color(0xFFE5E7EB),
            bottomBarBackground = Color.White.copy(alpha = 0.96f)
        )

        fun dark(): TimerAmbientTheme = TimerAmbientTheme(
            accent = Color(0xFF69E07A),
            accentSoft = Color(0xFF12331E),
            ringTrack = Color.White.copy(alpha = 0.14f),
            backgroundTop = Color(0xFF090B10),
            backgroundBottom = Color.Black,
            foreground = Color.White,
            secondaryForeground = Color.White.copy(alpha = 0.72f),
            panelOverlay = Color(0xFF111827).copy(alpha = 0.72f),
            panelStroke = Color.White.copy(alpha = 0.12f),
            bottomBarBackground = Color.Black.copy(alpha = 0.94f)
        )
    }
}
