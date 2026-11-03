package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.google.gson.JsonElement
import com.lyo.app.ui.classroom.catalog.cleanClassroomText
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

private val DeepIndigo = Color(0xFF121B42)
private val Night = Color(0xFF0D1230)
private val Violet = Color(0xFF8F60FF)
private val Blue = Color(0xFF4D62E9)
private val Mint = Color(0xFF44E8C1)
private val Amber = Color(0xFFFFC15B)

private fun modeAccent(mode: ClassroomDisplayMode): Color = when (mode) {
    ClassroomDisplayMode.SOLO -> Violet
    ClassroomDisplayMode.CLASSROOM -> Blue
    ClassroomDisplayMode.REVIEW -> Amber
}

@Composable
fun ClassroomModeHero(
    mode: ClassroomDisplayMode,
    topic: String,
    caption: JsonElement?,
    isPaused: Boolean,
    onTranscript: () -> Unit,
) {
    val speaker = caption?.takeIf { it.isJsonObject }?.asJsonObject
        ?.get("speaker")?.takeIf { it.isJsonPrimitive }?.asString
    val phrase = caption?.takeIf { it.isJsonObject }?.asJsonObject
        ?.get("text")?.takeIf { it.isJsonPrimitive }?.asString
    val teacher = ClassroomCast.teachers.firstOrNull { it.name == speaker || it.id == speaker }
        ?: ClassroomCast.teacherFor(topic)
    val accent = modeAccent(mode)
    val label = when (mode) {
        ClassroomDisplayMode.SOLO -> "YOUR TEACHER"
        ClassroomDisplayMode.CLASSROOM -> "LIVE CLASSROOM"
        ClassroomDisplayMode.REVIEW -> if (isPaused) "LESSON PAUSED" else "REVIEW YOUR LEARNING"
    }
    val prompt = phrase?.let(::cleanClassroomText)
        ?.replace("$", "")?.takeIf { it.isNotBlank() }
        ?: when (mode) {
            ClassroomDisplayMode.SOLO -> "We'll learn this one step at a time."
            ClassroomDisplayMode.CLASSROOM -> "Let's explore this together."
            ClassroomDisplayMode.REVIEW -> "Revisit a step, then return to your class."
        }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(
                Brush.horizontalGradient(listOf(DeepIndigo, Night, accent.copy(alpha = 0.27f))),
                RoundedCornerShape(22.dp),
            )
            .border(1.dp, accent.copy(alpha = 0.50f), RoundedCornerShape(22.dp))
            .padding(horizontal = 12.dp, vertical = if (mode == ClassroomDisplayMode.SOLO) 6.dp else 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TransparentClassroomPortrait(
            drawableRes = teacher.portrait,
            contentDescription = teacher.name + ", AI teacher",
            modifier = Modifier.size(if (mode == ClassroomDisplayMode.SOLO) 48.dp else if (mode == ClassroomDisplayMode.CLASSROOM) 65.dp else 58.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(label, color = accent, style = MaterialTheme.typography.labelSmall)
            Text(teacher.displayName, color = TextPrimary,
                style = MaterialTheme.typography.labelLarge)
            Text(prompt, color = TextSecondary, style = MaterialTheme.typography.bodySmall,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        TextButton(onClick = onTranscript) {
            Text("Notes", color = accent, style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
fun ClassroomModeCompanion(
    mode: ClassroomDisplayMode,
    transcript: List<TranscriptLine>,
    isReviewingPastStep: Boolean,
    isGroupSession: Boolean,
) {
    val accent = modeAccent(mode)
    val names = transcript.map { it.speaker }.toSet()
    val speakingPeers = ClassroomCast.classmates.filter { it.name in names || it.id in names }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(
                Brush.horizontalGradient(listOf(Night, DeepIndigo, accent.copy(alpha = 0.18f))),
                RoundedCornerShape(19.dp),
            )
            .border(1.dp, accent.copy(alpha = 0.26f), RoundedCornerShape(19.dp))
            .padding(horizontal = 10.dp, vertical = 9.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (mode == ClassroomDisplayMode.CLASSROOM) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Text("Classmates", color = TextPrimary, style = MaterialTheme.typography.labelLarge)
                speakingPeers.take(3).forEach { peer ->
                    TransparentClassroomPortrait(
                        drawableRes = peer.portrait,
                        contentDescription = peer.name,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
            Text(
                when {
                    speakingPeers.isNotEmpty() -> "Voices participating: " + speakingPeers.joinToString { it.name }
                    isGroupSession -> "Your classmates will appear as they participate."
                    else -> "This lesson started solo; classmates join when you start a Live Class."
                },
                color = TextSecondary, style = MaterialTheme.typography.labelSmall,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TransparentClassroomPortrait(
                drawableRes = ClassroomCast.companion.portrait,
                contentDescription = "Lyo, your study companion",
                modifier = Modifier.size(36.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text("Lyo · Your companion", color = accent, style = MaterialTheme.typography.labelSmall)
                Text(
                    when (mode) {
                        ClassroomDisplayMode.SOLO -> "Take your time. You've got this."
                        ClassroomDisplayMode.CLASSROOM -> "Great ideas. Keep going!"
                        ClassroomDisplayMode.REVIEW -> if (isReviewingPastStep)
                            "This is a saved step. Your live class is unchanged."
                        else "Ready whenever you want to continue."
                    },
                    color = TextSecondary, style = MaterialTheme.typography.bodySmall,
                    maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
fun ClassroomBoardHeading(mode: ClassroomDisplayMode, paused: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 15.dp, end = 12.dp, top = 13.dp, bottom = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Text("✧", color = modeAccent(mode), style = MaterialTheme.typography.titleLarge)
        Text(
            when {
                paused -> "Your saved lesson"
                mode == ClassroomDisplayMode.SOLO -> "Interactive Blackboard"
                mode == ClassroomDisplayMode.CLASSROOM -> "Today's challenge"
                else -> "Review & Resume"
            },
            color = modeAccent(mode),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f),
        )
        Text(if (paused) "Paused" else "●", color = if (paused) Amber else Mint,
            style = MaterialTheme.typography.labelSmall)
    }
}
