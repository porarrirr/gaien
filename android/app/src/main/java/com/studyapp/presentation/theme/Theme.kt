package com.studyapp.presentation.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.studyapp.presentation.settings.ColorTheme
import com.studyapp.presentation.settings.ThemeMode

// ── Typography ──────────────────────────────────────────────────────────────

private val AppTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp
    ),
    displayMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 45.sp,
        lineHeight = 52.sp,
        letterSpacing = 0.sp
    ),
    displaySmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 36.sp,
        lineHeight = 44.sp,
        letterSpacing = 0.sp
    ),
    headlineLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = 0.sp
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 28.sp,
        lineHeight = 36.sp,
        letterSpacing = 0.sp
    ),
    headlineSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp,
        lineHeight = 32.sp,
        letterSpacing = 0.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    titleSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.4.sp
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
)

// ── Shapes ──────────────────────────────────────────────────────────────────

private val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp)
)

// ── Color Schemes per ColorTheme ────────────────────────────────────────────

private fun greenLightScheme() = lightColorScheme(
    primary = Color(0xFF2E7D32),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFB9F6CA),
    onPrimaryContainer = Color(0xFF002204),
    secondary = Color(0xFF4A6350),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFCDE9D0),
    onSecondaryContainer = Color(0xFF072011),
    tertiary = Color(0xFF3D6373),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFC1E8FB),
    onTertiaryContainer = Color(0xFF001F29),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFF8FAF5),
    onBackground = Color(0xFF191C19),
    surface = Color(0xFFFCFDF7),
    onSurface = Color(0xFF191C19),
    surfaceVariant = Color(0xFFDDE5DB),
    onSurfaceVariant = Color(0xFF414941),
    outline = Color(0xFF717970),
    outlineVariant = Color(0xFFC1C9BF),
    inverseSurface = Color(0xFF2E312D),
    inverseOnSurface = Color(0xFFF0F1EC),
    inversePrimary = Color(0xFF6ADE73),
    surfaceTint = Color(0xFF2E7D32)
)

private fun greenDarkScheme() = darkColorScheme(
    primary = Color(0xFF6ADE73),
    onPrimary = Color(0xFF00390A),
    primaryContainer = Color(0xFF1B5E20),
    onPrimaryContainer = Color(0xFFB9F6CA),
    secondary = Color(0xFFB1CDB5),
    onSecondary = Color(0xFF1D3524),
    secondaryContainer = Color(0xFF334B3A),
    onSecondaryContainer = Color(0xFFCDE9D0),
    tertiary = Color(0xFFA5CCDF),
    onTertiary = Color(0xFF073543),
    tertiaryContainer = Color(0xFF244B5A),
    onTertiaryContainer = Color(0xFFC1E8FB),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF111411),
    onBackground = Color(0xFFE1E3DE),
    surface = Color(0xFF111411),
    onSurface = Color(0xFFE1E3DE),
    surfaceVariant = Color(0xFF414941),
    onSurfaceVariant = Color(0xFFC1C9BF),
    outline = Color(0xFF8B938A),
    outlineVariant = Color(0xFF414941),
    inverseSurface = Color(0xFFE1E3DE),
    inverseOnSurface = Color(0xFF2E312D),
    inversePrimary = Color(0xFF2E7D32),
    surfaceTint = Color(0xFF6ADE73)
)

private fun blueLightScheme() = lightColorScheme(
    primary = Color(0xFF1565C0),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD4E3FF),
    onPrimaryContainer = Color(0xFF001C3A),
    secondary = Color(0xFF535F70),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFD7E3F7),
    onSecondaryContainer = Color(0xFF101C2B),
    tertiary = Color(0xFF6B5778),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFF3DAFF),
    onTertiaryContainer = Color(0xFF251431),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFF8F9FF),
    onBackground = Color(0xFF191C20),
    surface = Color(0xFFFCFCFF),
    onSurface = Color(0xFF191C20),
    surfaceVariant = Color(0xFFDFE2EB),
    onSurfaceVariant = Color(0xFF43474E),
    outline = Color(0xFF73777F),
    outlineVariant = Color(0xFFC3C6CF),
    inverseSurface = Color(0xFF2E3135),
    inverseOnSurface = Color(0xFFF0F0F4),
    inversePrimary = Color(0xFFA6C8FF),
    surfaceTint = Color(0xFF1565C0)
)

private fun blueDarkScheme() = darkColorScheme(
    primary = Color(0xFFA6C8FF),
    onPrimary = Color(0xFF00315E),
    primaryContainer = Color(0xFF004A93),
    onPrimaryContainer = Color(0xFFD4E3FF),
    secondary = Color(0xFFBBC7DB),
    onSecondary = Color(0xFF253141),
    secondaryContainer = Color(0xFF3C4858),
    onSecondaryContainer = Color(0xFFD7E3F7),
    tertiary = Color(0xFFD7BEE4),
    onTertiary = Color(0xFF3B2948),
    tertiaryContainer = Color(0xFF533F5F),
    onTertiaryContainer = Color(0xFFF3DAFF),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF111318),
    onBackground = Color(0xFFE1E2E8),
    surface = Color(0xFF111318),
    onSurface = Color(0xFFE1E2E8),
    surfaceVariant = Color(0xFF43474E),
    onSurfaceVariant = Color(0xFFC3C6CF),
    outline = Color(0xFF8D9199),
    outlineVariant = Color(0xFF43474E),
    inverseSurface = Color(0xFFE1E2E8),
    inverseOnSurface = Color(0xFF2E3135),
    inversePrimary = Color(0xFF1565C0),
    surfaceTint = Color(0xFFA6C8FF)
)

private fun purpleLightScheme() = lightColorScheme(
    primary = Color(0xFF7B1FA2),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFF3DAFF),
    onPrimaryContainer = Color(0xFF2D004E),
    secondary = Color(0xFF665A6E),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFEDDDF5),
    onSecondaryContainer = Color(0xFF211829),
    tertiary = Color(0xFF805158),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFD9DD),
    onTertiaryContainer = Color(0xFF321017),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFFFF7FF),
    onBackground = Color(0xFF1E1A20),
    surface = Color(0xFFFFFBFF),
    onSurface = Color(0xFF1E1A20),
    surfaceVariant = Color(0xFFE9DFEA),
    onSurfaceVariant = Color(0xFF4B454D),
    outline = Color(0xFF7C757E),
    outlineVariant = Color(0xFFCDC3CE),
    inverseSurface = Color(0xFF332F35),
    inverseOnSurface = Color(0xFFF6EEF6),
    inversePrimary = Color(0xFFE1B6FF),
    surfaceTint = Color(0xFF7B1FA2)
)

private fun purpleDarkScheme() = darkColorScheme(
    primary = Color(0xFFE1B6FF),
    onPrimary = Color(0xFF49007C),
    primaryContainer = Color(0xFF6200AD),
    onPrimaryContainer = Color(0xFFF3DAFF),
    secondary = Color(0xFFD0C1D9),
    onSecondary = Color(0xFF372C3F),
    secondaryContainer = Color(0xFF4E4256),
    onSecondaryContainer = Color(0xFFEDDDF5),
    tertiary = Color(0xFFF4B7BE),
    onTertiary = Color(0xFF4B252C),
    tertiaryContainer = Color(0xFF653A41),
    onTertiaryContainer = Color(0xFFFFD9DD),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF161217),
    onBackground = Color(0xFFE9E0E8),
    surface = Color(0xFF161217),
    onSurface = Color(0xFFE9E0E8),
    surfaceVariant = Color(0xFF4B454D),
    onSurfaceVariant = Color(0xFFCDC3CE),
    outline = Color(0xFF968E98),
    outlineVariant = Color(0xFF4B454D),
    inverseSurface = Color(0xFFE9E0E8),
    inverseOnSurface = Color(0xFF332F35),
    inversePrimary = Color(0xFF7B1FA2),
    surfaceTint = Color(0xFFE1B6FF)
)

private fun orangeLightScheme() = lightColorScheme(
    primary = Color(0xFFE65100),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFDBC8),
    onPrimaryContainer = Color(0xFF331200),
    secondary = Color(0xFF755845),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFDBC8),
    onSecondaryContainer = Color(0xFF2B1709),
    tertiary = Color(0xFF636032),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFEAE5AB),
    onTertiaryContainer = Color(0xFF1E1D00),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFFFF8F5),
    onBackground = Color(0xFF211A15),
    surface = Color(0xFFFFFCF9),
    onSurface = Color(0xFF211A15),
    surfaceVariant = Color(0xFFF4DED3),
    onSurfaceVariant = Color(0xFF52443B),
    outline = Color(0xFF847469),
    outlineVariant = Color(0xFFD7C2B7),
    inverseSurface = Color(0xFF372F29),
    inverseOnSurface = Color(0xFFFDEEE5),
    inversePrimary = Color(0xFFFFB68B),
    surfaceTint = Color(0xFFE65100)
)

private fun orangeDarkScheme() = darkColorScheme(
    primary = Color(0xFFFFB68B),
    onPrimary = Color(0xFF532200),
    primaryContainer = Color(0xFFBF3E00),
    onPrimaryContainer = Color(0xFFFFDBC8),
    secondary = Color(0xFFE5BFA8),
    onSecondary = Color(0xFF432B1B),
    secondaryContainer = Color(0xFF5C4130),
    onSecondaryContainer = Color(0xFFFFDBC8),
    tertiary = Color(0xFFCDC991),
    onTertiary = Color(0xFF343209),
    tertiaryContainer = Color(0xFF4B491E),
    onTertiaryContainer = Color(0xFFEAE5AB),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF19120C),
    onBackground = Color(0xFFF0DFD5),
    surface = Color(0xFF19120C),
    onSurface = Color(0xFFF0DFD5),
    surfaceVariant = Color(0xFF52443B),
    onSurfaceVariant = Color(0xFFD7C2B7),
    outline = Color(0xFF9F8D83),
    outlineVariant = Color(0xFF52443B),
    inverseSurface = Color(0xFFF0DFD5),
    inverseOnSurface = Color(0xFF372F29),
    inversePrimary = Color(0xFFE65100),
    surfaceTint = Color(0xFFFFB68B)
)

private fun redLightScheme() = lightColorScheme(
    primary = Color(0xFFC62828),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFDAD6),
    onPrimaryContainer = Color(0xFF410002),
    secondary = Color(0xFF775653),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFDAD6),
    onSecondaryContainer = Color(0xFF2C1513),
    tertiary = Color(0xFF755A2F),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFFFDDB1),
    onTertiaryContainer = Color(0xFF291800),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFFFF8F7),
    onBackground = Color(0xFF221B1A),
    surface = Color(0xFFFFFBFF),
    onSurface = Color(0xFF221B1A),
    surfaceVariant = Color(0xFFF5DDDA),
    onSurfaceVariant = Color(0xFF534341),
    outline = Color(0xFF857370),
    outlineVariant = Color(0xFFD8C2BF),
    inverseSurface = Color(0xFF382F2E),
    inverseOnSurface = Color(0xFFFEEDEB),
    inversePrimary = Color(0xFFFFB4AB),
    surfaceTint = Color(0xFFC62828)
)

private fun redDarkScheme() = darkColorScheme(
    primary = Color(0xFFFFB4AB),
    onPrimary = Color(0xFF690005),
    primaryContainer = Color(0xFF9B0D10),
    onPrimaryContainer = Color(0xFFFFDAD6),
    secondary = Color(0xFFE7BDB8),
    onSecondary = Color(0xFF442927),
    secondaryContainer = Color(0xFF5D3F3C),
    onSecondaryContainer = Color(0xFFFFDAD6),
    tertiary = Color(0xFFE5C18D),
    onTertiary = Color(0xFF412D06),
    tertiaryContainer = Color(0xFF5B431A),
    onTertiaryContainer = Color(0xFFFFDDB1),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF1A1110),
    onBackground = Color(0xFFF1DFDC),
    surface = Color(0xFF1A1110),
    onSurface = Color(0xFFF1DFDC),
    surfaceVariant = Color(0xFF534341),
    onSurfaceVariant = Color(0xFFD8C2BF),
    outline = Color(0xFFA08C8A),
    outlineVariant = Color(0xFF534341),
    inverseSurface = Color(0xFFF1DFDC),
    inverseOnSurface = Color(0xFF382F2E),
    inversePrimary = Color(0xFFC62828),
    surfaceTint = Color(0xFFFFB4AB)
)

private fun tealLightScheme() = lightColorScheme(
    primary = Color(0xFF00695C),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFA7F3EB),
    onPrimaryContainer = Color(0xFF00201C),
    secondary = Color(0xFF4A635F),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFCDE8E2),
    onSecondaryContainer = Color(0xFF06201C),
    tertiary = Color(0xFF446179),
    onTertiary = Color.White,
    tertiaryContainer = Color(0xFFC9E6FF),
    onTertiaryContainer = Color(0xFF001E30),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFF4FBF8),
    onBackground = Color(0xFF171D1B),
    surface = Color(0xFFF9FDFB),
    onSurface = Color(0xFF171D1B),
    surfaceVariant = Color(0xFFDAE5E1),
    onSurfaceVariant = Color(0xFF3F4946),
    outline = Color(0xFF6F7976),
    outlineVariant = Color(0xFFBEC9C5),
    inverseSurface = Color(0xFF2C3230),
    inverseOnSurface = Color(0xFFECF2EF),
    inversePrimary = Color(0xFF55DBCb),
    surfaceTint = Color(0xFF00695C)
)

private fun tealDarkScheme() = darkColorScheme(
    primary = Color(0xFF55DBCB),
    onPrimary = Color(0xFF003731),
    primaryContainer = Color(0xFF005048),
    onPrimaryContainer = Color(0xFFA7F3EB),
    secondary = Color(0xFFB1CCC6),
    onSecondary = Color(0xFF1C3531),
    secondaryContainer = Color(0xFF334B47),
    onSecondaryContainer = Color(0xFFCDE8E2),
    tertiary = Color(0xFFABCAE4),
    onTertiary = Color(0xFF123348),
    tertiaryContainer = Color(0xFF2B4960),
    onTertiaryContainer = Color(0xFFC9E6FF),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF0F1513),
    onBackground = Color(0xFFDEE4E1),
    surface = Color(0xFF0F1513),
    onSurface = Color(0xFFDEE4E1),
    surfaceVariant = Color(0xFF3F4946),
    onSurfaceVariant = Color(0xFFBEC9C5),
    outline = Color(0xFF899390),
    outlineVariant = Color(0xFF3F4946),
    inverseSurface = Color(0xFFDEE4E1),
    inverseOnSurface = Color(0xFF2C3230),
    inversePrimary = Color(0xFF00695C),
    surfaceTint = Color(0xFF55DBCB)
)

// ── Theme Composable ────────────────────────────────────────────────────────

@Composable
fun StudyAppTheme(
    colorTheme: ColorTheme = ColorTheme.GREEN,
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    content: @Composable () -> Unit
) {
    val darkTheme = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }

    val colorScheme = if (darkTheme) {
        when (colorTheme) {
            ColorTheme.GREEN -> greenDarkScheme()
            ColorTheme.BLUE -> blueDarkScheme()
            ColorTheme.PURPLE -> purpleDarkScheme()
            ColorTheme.ORANGE -> orangeDarkScheme()
            ColorTheme.RED -> redDarkScheme()
            ColorTheme.TEAL -> tealDarkScheme()
        }
    } else {
        when (colorTheme) {
            ColorTheme.GREEN -> greenLightScheme()
            ColorTheme.BLUE -> blueLightScheme()
            ColorTheme.PURPLE -> purpleLightScheme()
            ColorTheme.ORANGE -> orangeLightScheme()
            ColorTheme.RED -> redLightScheme()
            ColorTheme.TEAL -> tealLightScheme()
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}