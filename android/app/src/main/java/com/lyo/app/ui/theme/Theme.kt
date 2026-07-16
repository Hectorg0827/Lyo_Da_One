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

// LYO palette — generated from /design-tokens.json (source of truth: iOS Sources/Core/DesignTokens.swift).
// Do not hand-edit hex values here; update design-tokens.json and mirror the change.
val LyoPurple = Color(0xFF6366F1) // brand.primary
val LyoViolet = Color(0xFF8B5CF6) // brand.secondary
val LyoVioletLight = Color(0xFFA78BFA) // brand.secondaryLight
val LyoMagenta = Color(0xFFD946EF) // brand.accentMagenta
val LyoGold = Color(0xFFD9B24C) // brand.accentGold
val LyoPink = Color(0xFFEC4899)
val LyoAmber = Color(0xFFF59E0B) // semantic.warning
val LyoGreen = Color(0xFF10B981) // semantic.success
val LyoBlue = Color(0xFF3B82F6) // semantic.info
val LyoRed = Color(0xFFEF4444) // semantic.danger

val Background = Color(0xFF0B1230) // surface.background
val Surface = Color(0xFF0E173D) // surface.surface
val SurfaceElevated = Color(0xFF2A2D3A) // surface.surfaceElevated
val SurfaceHighlight = Color(0xFF343847) // surface.surfaceHighlight
val TextPrimary = Color(0xFFFFFFFF) // text.primary
val TextSecondary = Color(0xFFC9D1F2) // text.secondary
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
    displayLarge = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold),
    displayMedium = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
    displaySmall = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.SemiBold),
    headlineLarge = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
    headlineMedium = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold),
    headlineSmall = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold),
    titleLarge = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal),
    bodySmall = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Normal),
    labelLarge = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium),
    labelMedium = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium),
    labelSmall = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium),
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
