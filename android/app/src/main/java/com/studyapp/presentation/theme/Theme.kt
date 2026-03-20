package com.studyapp.presentation.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val Primary = Color(0xFF4CAF50)
private val PrimaryDark = Color(0xFF388E3C)
private val Secondary = Color(0xFF2196F3)
private val SecondaryDark = Color(0xFF1976D2)
private val Accent = Color(0xFFFF9800)
private val Background = Color(0xFFFAFAFA)
private val Surface = Color(0xFFFFFFFF)
private val Error = Color(0xFFF44336)
private val OnPrimary = Color(0xFFFFFFFF)
private val OnSecondary = Color(0xFFFFFFFF)
private val OnBackground = Color(0xFF1C1B1F)
private val OnSurface = Color(0xFF1C1B1F)
private val OnError = Color(0xFFFFFFFF)

private val DarkPrimary = Color(0xFF66BB6A)
private val DarkPrimaryDark = Color(0xFF4CAF50)
private val DarkSecondary = Color(0xFF42A5F5)
private val DarkBackground = Color(0xFF121212)
private val DarkSurface = Color(0xFF1E1E1E)
private val DarkOnBackground = Color(0xFFE1E1E1)
private val DarkOnSurface = Color(0xFFE1E1E1)

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = Color(0xFFC8E6C9),
    onPrimaryContainer = Color(0xFF1B5E20),
    secondary = Secondary,
    onSecondary = OnSecondary,
    secondaryContainer = Color(0xFFBBDEFB),
    onSecondaryContainer = Color(0xFF0D47A1),
    tertiary = Accent,
    onTertiary = OnPrimary,
    background = Background,
    onBackground = OnBackground,
    surface = Surface,
    onSurface = OnSurface,
    error = Error,
    onError = OnError
)

private val DarkColorScheme = darkColorScheme(
    primary = DarkPrimary,
    onPrimary = OnPrimary,
    primaryContainer = DarkPrimaryDark,
    onPrimaryContainer = Color(0xFFC8E6C9),
    secondary = DarkSecondary,
    onSecondary = OnSecondary,
    secondaryContainer = Color(0xFF1565C0),
    onSecondaryContainer = Color(0xFFBBDEFB),
    tertiary = Accent,
    onTertiary = OnPrimary,
    background = DarkBackground,
    onBackground = DarkOnBackground,
    surface = DarkSurface,
    onSurface = DarkOnSurface,
    error = Error,
    onError = OnError
)

@Composable
fun StudyAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.surface.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }
    
    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}