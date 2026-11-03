package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.google.gson.JsonElement
import com.lyo.app.ui.classroom.catalog.cleanClassroomText

private val Indigo = Color(0xFF141B43)
private val Night = Color(0xFF0C1230)
private val Violet = Color(0xFFB282FF)
private val IceBlue = Color(0xFF83BBFF)
private val Mint = Color(0xFF56F0CB)
private val Amber = Color(0xFFFFC15B)
private val White = Color(0xFFF5F4FF)
private val SoftText = Color(0xFFC4C3E2)

private fun colorFor(mode: ClassroomDisplayMode): Color = when (mode) {
    ClassroomDisplayMode.SOLO -> Violet
    ClassroomDisplayMode.CLASSROOM -> IceBlue
    ClassroomDisplayMode.REVIEW -> Violet
}

/** Image-led hero that stays smaller than the actual interactive blackboard. */
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
    val teacher = ClassroomCast.teachers.firstOrNull { it.id == speaker || it.name == speaker }
        ?: ClassroomCast.teacherFor(topic)
    val prompt = phrase?.let(::cleanClassroomText)?.replace("$", "")?.takeIf { it.isNotBlank() }
        ?: when (mode) {
            ClassroomDisplayMode.SOLO -> "Let's solve it together!"
            ClassroomDisplayMode.CLASSROOM -> "Who wants to explain this?"
            ClassroomDisplayMode.REVIEW -> "Let's continue when you're ready."
        }
    val avatarSize = when (mode) {
        ClassroomDisplayMode.SOLO -> 58.dp
        ClassroomDisplayMode.CLASSROOM -> 92.dp
        ClassroomDisplayMode.REVIEW -> 64.dp
    }
    val accent = colorFor(mode)
    val recovery = mode == ClassroomDisplayMode.REVIEW
    val cardShape = RoundedCornerShape(22.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 13.dp, vertical = 4.dp)
            .then(
                if (recovery) Modifier
                    .background(
                        Brush.horizontalGradient(listOf(Indigo, Color(0xFF221C4F))),
                        cardShape,
                    )
                    .border(1.dp, accent.copy(alpha = .55f), cardShape)
                    .padding(horizontal = 9.dp, vertical = 7.dp)
                else Modifier
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Box(
            modifier = Modifier.size(avatarSize),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier.size(avatarSize * .88f)
                    .background(
                        Brush.radialGradient(
                            listOf(
                                accent.copy(alpha = .50f),
                                accent.copy(alpha = .18f),
                                Color.Transparent,
                            ),
                        ),
                        RoundedCornerShape(99.dp),
                    ),
            )
            TransparentClassroomPortrait(
                drawableRes = teacher.portrait,
                contentDescription = "${teacher.displayName} speaking",
                modifier = Modifier.size(avatarSize),
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(
                if (mode == ClassroomDisplayMode.SOLO) teacher.displayName else if (recovery)
                    teacher.displayName else "${teacher.displayName} · Leading the lesson",
                color = accent,
                style = MaterialTheme.typography.labelMedium,
                maxLines = 1,
            )
            if (!recovery && mode != ClassroomDisplayMode.SOLO) {
                Text("▂  ▄  ▆  ▃  ▇  ▄  ▂", color = accent, style = MaterialTheme.typography.labelMedium)
            }
            Box(
                modifier = Modifier.fillMaxWidth()
                    .background(
                        Brush.horizontalGradient(
                            listOf(Color(0xFF2A255E), Color(0xFF19254C)),
                        ),
                        RoundedCornerShape(17.dp),
                    )
                    .border(1.dp, accent.copy(alpha = .48f), RoundedCornerShape(17.dp))
                    .padding(horizontal = 11.dp, vertical = if (mode == ClassroomDisplayMode.SOLO) 6.dp else 10.dp),
            ) {
                Text(
                    prompt,
                    color = White,
                    style = if (recovery) MaterialTheme.typography.bodyMedium else MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Real cast assets; no invented class participation when no one has spoken yet. */
@Composable
fun ClassroomModeCompanion(
    mode: ClassroomDisplayMode,
    transcript: List<TranscriptLine>,
    isReviewingPastStep: Boolean,
    isGroupSession: Boolean,
    lastLyoText: String? = null,
) {
    val accent = colorFor(mode)
    val recentPeerLines = transcript.filter { line ->
        ClassroomCast.classmates.any { it.name == line.speaker || it.id == line.speaker }
    }
    val recentPeer = recentPeerLines.lastOrNull()
    val realPeers = ClassroomCast.classmates.filter { peer ->
        recentPeerLines.any { it.speaker == peer.id || it.speaker == peer.name }
    }
    Column(
        modifier = Modifier.fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 3.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        if (mode == ClassroomDisplayMode.CLASSROOM) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.horizontalGradient(listOf(Indigo, Night)),
                        RoundedCornerShape(17.dp),
                    )
                    .border(1.dp, accent.copy(alpha = .32f), RoundedCornerShape(17.dp))
                    .padding(9.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "♟  Classmates",
                        color = White,
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.weight(1f),
                    )
                    val avatars = if (isGroupSession) ClassroomCast.classmates.take(3) else realPeers.take(3)
                    avatars.forEach { peer ->
                        TransparentClassroomPortrait(peer.portrait, peer.name, Modifier.size(28.dp))
                    }
                }
                Text(
                    recentPeer?.let { "${it.speaker}: ${it.text}" }
                        ?: if (isGroupSession) "Classmates join the conversation as they speak."
                           else "Switching the layout does not create new participants.",
                    color = SoftText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth()
                .background(
                    Brush.horizontalGradient(listOf(Color(0xFF131B40), Color(0xFF1A1C4A))),
                    RoundedCornerShape(17.dp),
                )
                .border(1.dp, accent.copy(alpha = .30f), RoundedCornerShape(17.dp))
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            TransparentClassroomPortrait(
                ClassroomCast.companion.portrait,
                "Lyo, your study companion",
                Modifier.size(41.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text("Lyo · Your companion", color = accent,
                    style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                Text(
                    when (mode) {
                        ClassroomDisplayMode.SOLO ->
                            lastLyoText?.let(::cleanClassroomText)?.take(160)
                                ?.takeIf(String::isNotBlank)
                                ?: "Take your time. You've got this. ✨"
                        ClassroomDisplayMode.CLASSROOM -> "Great ideas. Keep going! ✨"
                        ClassroomDisplayMode.REVIEW ->
                            if (isReviewingPastStep) "Your earlier work is saved."
                            else "No worries. We'll pick up where we left off."
                    },
                    color = SoftText, style = MaterialTheme.typography.bodySmall,
                    maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
            }
            Text("✦", color = accent, style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
fun ClassroomBoardHeading(mode: ClassroomDisplayMode, paused: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth()
            .padding(start = 15.dp, end = 14.dp, top = 15.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("▣", color = colorFor(mode), style = MaterialTheme.typography.titleMedium)
        Text(
            when {
                paused -> "A quick pause"
                mode == ClassroomDisplayMode.SOLO -> "Interactive Blackboard"
                mode == ClassroomDisplayMode.CLASSROOM -> "Today's challenge"
                else -> "What we learned"
            },
            color = colorFor(mode),
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f),
        )
        if (paused) Text("●  Paused", color = Amber, style = MaterialTheme.typography.labelSmall)
    }
}
