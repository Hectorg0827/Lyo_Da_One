package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.TextPrimary

/**
 * A `Celebration` component — fires on lesson-mastery and course-complete
 * scenes (LyoBackendJune's `_create_celebration_components`). This type
 * wasn't in the wire contract as originally reconstructed from the web
 * client; added after reading the real backend source directly, which
 * confirmed it's actively emitted on a common path, not a rare/legacy one.
 *
 * `particle_effect` (a confetti/sparkle animation cue) isn't rendered —
 * v1 shows the message/points/badge only, no particle system. Deferred as
 * a cosmetic-only gap, not a functional one.
 */
@Composable
fun A2uiRenderScope.CelebrationCardRenderer() {
    val message = resolveString("message") ?: return
    val pointsEarned = resolve("pointsEarned")?.takeIf { it.isJsonPrimitive }?.asInt
    val achievementType = resolveString("achievementType")

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .background(LyoGreen.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
            .padding(20.dp),
    ) {
        Text(
            text = "🎉 $message",
            style = MaterialTheme.typography.titleMedium,
            color = LyoGreen,
            textAlign = TextAlign.Center,
        )
        if (pointsEarned != null) {
            Text(
                text = "+$pointsEarned points",
                color = ClassroomTokens.Gold,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
        if (achievementType != null) {
            Text(
                text = achievementType,
                color = TextPrimary,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}
