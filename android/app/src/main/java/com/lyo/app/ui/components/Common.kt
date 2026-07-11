package com.lyo.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoViolet
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextSecondary

/** Rotating gradient palette used for cards/avatars without images. */
val CardGradients: List<Brush> = listOf(
    Brush.linearGradient(listOf(Color(0xFF2563EB), Color(0xFF06B6D4))),
    Brush.linearGradient(listOf(Color(0xFFDB2777), Color(0xFFF43F5E))),
    Brush.linearGradient(listOf(Color(0xFF9333EA), Color(0xFF6366F1))),
    Brush.linearGradient(listOf(Color(0xFFF59E0B), Color(0xFFFB923C))),
    Brush.linearGradient(listOf(Color(0xFF16A34A), Color(0xFF14B8A6))),
    Brush.linearGradient(listOf(Color(0xFF7C3AED), Color(0xFFA855F7))),
)

val AvatarColors: List<Color> =
    listOf(LyoPurple, LyoGreen, LyoPink, LyoAmber, LyoBlue, LyoViolet)

val LyoBrandGradient: Brush =
    Brush.linearGradient(listOf(LyoPurple, LyoViolet))

fun avatarColorFor(id: String): Color =
    AvatarColors[(id.lastOrNull()?.code ?: 0) % AvatarColors.size]

fun initialsOf(name: String): String =
    name.trim().split(Regex("\\s+")).take(2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }
        .joinToString("")
        .ifBlank { "?" }

/** Glass card: translucent surface + hairline border, the app's core container. */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Surface.copy(alpha = 0.75f))
            .border(1.dp, BorderColor, RoundedCornerShape(20.dp)),
        content = content,
    )
}

/** Circular avatar: image when available, colored initials otherwise. */
@Composable
fun LyoAvatar(
    name: String,
    avatarUrl: String?,
    size: Int = 40,
    modifier: Modifier = Modifier,
) {
    if (!avatarUrl.isNullOrBlank()) {
        AsyncImage(
            model = avatarUrl,
            contentDescription = name,
            contentScale = ContentScale.Crop,
            modifier = modifier
                .size(size.dp)
                .clip(CircleShape),
        )
    } else {
        Box(
            contentAlignment = Alignment.Center,
            modifier = modifier
                .size(size.dp)
                .clip(CircleShape)
                .background(avatarColorFor(name)),
        ) {
            Text(
                text = initialsOf(name),
                color = Color.White,
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title,
        style = MaterialTheme.typography.headlineSmall,
        modifier = modifier.padding(vertical = 8.dp),
    )
}

@Composable
fun LoadingBox(modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .fillMaxSize()
            .padding(32.dp),
    ) {
        CircularProgressIndicator(color = LyoPurple)
    }
}

@Composable
fun EmptyState(
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 48.dp, horizontal = 24.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleLarge)
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}

@Composable
fun ErrorBox(message: String, modifier: Modifier = Modifier) {
    EmptyState(
        title = "Something went wrong",
        subtitle = message,
        modifier = modifier,
    )
}

/** Relative "time ago" for ISO-8601 timestamps (best-effort). */
fun formatTimeAgo(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    return try {
        val instant = java.time.OffsetDateTime.parse(
            if (iso.endsWith("Z") || iso.contains("+")) iso else iso + "Z"
        ).toInstant()
        val seconds = java.time.Duration.between(instant, java.time.Instant.now()).seconds
        when {
            seconds < 60 -> "now"
            seconds < 3600 -> "${seconds / 60}m"
            seconds < 86_400 -> "${seconds / 3600}h"
            seconds < 604_800 -> "${seconds / 86_400}d"
            else -> "${seconds / 604_800}w"
        }
    } catch (e: Exception) {
        ""
    }
}
