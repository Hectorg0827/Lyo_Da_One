package com.lyo.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// LYO palette — matches the web app (globals.css) and iOS look
val LyoPurple = Color(0xFF6C63FF)
val LyoViolet = Color(0xFF8B5CF6)
val LyoPink = Color(0xFFEC4899)
val LyoAmber = Color(0xFFF59E0B)
val LyoGreen = Color(0xFF22C55E)
val LyoBlue = Color(0xFF3B82F6)
val LyoRed = Color(0xFFEF4444)

val Background = Color(0xFF0A0A0F)
val Surface = Color(0xFF111118)
val SurfaceElevated = Color(0xFF16161F)
val TextPrimary = Color(0xFFF5F5F7)
val TextSecondary = Color(0xFF8888AA)
val BorderColor = Color(0x14FFFFFF) // white @ 8%

private val LyoColorScheme = darkColorScheme(
    primary = LyoPurple,
    onPrimary = Color.White,
    secondary = LyoViolet,
    onSecondary = Color.White,
    tertiary = LyoPink,
    background = Background,
    onBackground = TextPrimary,
    surface = Surface,
    onSurface = TextPrimary,
    surfaceVariant = SurfaceElevated,
    onSurfaceVariant = TextSecondary,
    error = LyoRed,
    outline = BorderColor,
)

private val LyoTypography = Typography(
    headlineLarge = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Black),
    headlineMedium = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold),
    headlineSmall = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
    titleLarge = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Bold),
    titleMedium = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal),
    bodySmall = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Normal),
    labelLarge = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold),
    labelMedium = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.SemiBold),
    labelSmall = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium),
)

@Composable
fun LyoTheme(content: @Composable () -> Unit) {
    // LYO is a dark-first product on every platform
    MaterialTheme(
        colorScheme = LyoColorScheme,
        typography = LyoTypography,
        content = content,
    )
}
