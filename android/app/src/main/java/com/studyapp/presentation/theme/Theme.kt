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
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.ThemeMode

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
    primary = Color(0xFF2E9D45),
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
    background = Color(0xFFF2F2F7),
    onBackground = Color(0xFF191C19),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF191C19),
    surfaceVariant = Color(0xFFE7E9EE),
    onSurfaceVariant = Color(0xFF414941),
    outline = Color(0xFF717970),
    outlineVariant = Color(0xFFDADDE3),
    inverseSurface = Color(0xFF2E312D),
    inverseOnSurface = Color(0xFFF0F1EC),
    inversePrimary = Color(0xFF6ADE73),
    surfaceTint = Color(0xFF2E9D45)
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
    inversePrimary = Color(0xFF2E9D45),
    surfaceTint = Color(0xFF6ADE73)
)

private fun blueLightScheme() = lightColorScheme(
    primary = Color(0xFF1E88E5),
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
    surfaceTint = Color(0xFF1E88E5)
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
    inversePrimary = Color(0xFF1E88E5),
    surfaceTint = Color(0xFFA6C8FF)
)

private fun orangeLightScheme() = lightColorScheme(
    primary = Color(0xFFF59E0B),
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
    surfaceTint = Color(0xFFF59E0B)
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
    inversePrimary = Color(0xFFF59E0B),
    surfaceTint = Color(0xFFFFB68B)
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
            ColorTheme.ORANGE -> orangeDarkScheme()
        }
    } else {
        when (colorTheme) {
            ColorTheme.GREEN -> greenLightScheme()
            ColorTheme.BLUE -> blueLightScheme()
            ColorTheme.ORANGE -> orangeLightScheme()
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
