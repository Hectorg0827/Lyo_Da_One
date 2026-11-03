package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

private val DeepBlue = Color(0xFF0A102C)
private val SurfaceBlue = Color(0xFF131D42)
private val Neon = Color(0xFFAB77FF)
private val Lilac = Color(0xFFD7B8FF)
private val Muted = Color(0xFFB8BBDC)
private val Border = Color(0xFF52528E)
private val ButtonGradient = Brush.horizontalGradient(
    listOf(Color(0xFF655BFA), Color(0xFFAA50F5)),
)

/** Mode selection matches the approved visual: an entry screen, not a stock AlertDialog. */
@Composable
fun ClassroomModePicker(
    current: ClassroomDisplayMode?,
    canDismiss: Boolean,
    suggested: ClassroomDisplayMode,
    rememberChoice: Boolean,
    onRememberChoiceChange: (Boolean) -> Unit,
    onChoose: (ClassroomDisplayMode) -> Unit,
    onDismiss: () -> Unit,
) {
    var selected by remember(current, suggested) { mutableStateOf(current ?: suggested) }
    val fullScreen = !canDismiss
    Dialog(
        onDismissRequest = { if (canDismiss) onDismiss() },
        properties = DialogProperties(
            dismissOnBackPress = canDismiss,
            dismissOnClickOutside = canDismiss,
            usePlatformDefaultWidth = false,
        ),
    ) {
        Column(
            modifier = (if (fullScreen) Modifier.fillMaxSize()
                else Modifier.fillMaxWidth(.94f))
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF101638), DeepBlue, Color(0xFF17103C)),
                    ),
                    RoundedCornerShape(if (fullScreen) 0.dp else 26.dp),
                )
                .border(
                    1.dp,
                    Neon.copy(alpha = .58f),
                    RoundedCornerShape(if (fullScreen) 0.dp else 26.dp),
                )
                .padding(horizontal = 22.dp, vertical = if (fullScreen) 28.dp else 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (canDismiss) {
                    Text(
                        "‹",
                        color = Color.White,
                        style = MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.clickable(onClick = onDismiss).padding(end = 12.dp),
                    )
                }
                Text(
                    "✦  Lyo Classroom",
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
            }
            if (fullScreen) Spacer(Modifier.height(12.dp))
            Text(
                "Choose your\nclassroom mode",
                color = Color.White,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                "Pick the learning experience that works best for you.",
                color = Muted,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.fillMaxWidth(),
            )
            if (fullScreen) Spacer(Modifier.height(10.dp))
            ClassroomDisplayMode.entries.forEach { mode ->
                val active = mode == selected
                val shape = RoundedCornerShape(18.dp)
                val gradient = if (active)
                    Brush.horizontalGradient(listOf(Color(0xFF2A2261), Color(0xFF262054)))
                    else Brush.horizontalGradient(listOf(SurfaceBlue, Color(0xFF101632)))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(gradient, shape)
                        .border(1.5.dp, if (active) Neon else Border.copy(alpha = .7f), shape)
                        .clickable { selected = mode }
                        .padding(horizontal = 13.dp, vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(modifier = Modifier.size(54.dp), contentAlignment = Alignment.Center) {
                        when (mode) {
                            ClassroomDisplayMode.SOLO -> TransparentClassroomPortrait(
                                ClassroomCast.companion.portrait,
                                "Lyo focus mode",
                                Modifier.size(48.dp),
                            )
                            ClassroomDisplayMode.CLASSROOM -> Row(
                                horizontalArrangement = Arrangement.spacedBy((-8).dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                ClassroomCast.classmates.take(3).forEach { peer ->
                                    TransparentClassroomPortrait(
                                        peer.portrait,
                                        peer.name,
                                        Modifier.size(25.dp),
                                    )
                                }
                            }
                            ClassroomDisplayMode.REVIEW -> Text(
                                "↻", color = Neon, style = MaterialTheme.typography.displaySmall,
                            )
                        }
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            when (mode) {
                                ClassroomDisplayMode.SOLO -> "Focus Mode"
                                ClassroomDisplayMode.CLASSROOM -> "Live Class"
                                ClassroomDisplayMode.REVIEW -> "Review & Resume"
                            },
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            when (mode) {
                                ClassroomDisplayMode.SOLO -> "Practice on your own with step-by-step support."
                                ClassroomDisplayMode.CLASSROOM -> "Learn with a teacher and classmates."
                                ClassroomDisplayMode.REVIEW -> "Review past steps, catch up, or continue a paused lesson."
                            },
                            color = Muted,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    Box(
                        modifier = Modifier.size(23.dp)
                            .border(1.dp, if (active) Neon else Muted.copy(alpha = .5f), CircleShape)
                            .background(if (active) Neon else Color.Transparent, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (active) Text("✓", color = Color.White, style = MaterialTheme.typography.labelMedium)
                    }
                }
            }
            if (fullScreen) Spacer(modifier = Modifier.weight(1f))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(
                    checked = rememberChoice,
                    onCheckedChange = onRememberChoiceChange,
                    colors = CheckboxDefaults.colors(
                        checkedColor = Color(0xFF8F5CF8),
                        uncheckedColor = Muted,
                    ),
                )
                Text("Remember my choice", color = Color.White,
                    style = MaterialTheme.typography.bodyMedium)
            }
            Box(
                modifier = Modifier.fillMaxWidth()
                    .background(ButtonGradient, RoundedCornerShape(17.dp))
                    .border(1.dp, Lilac.copy(alpha = .55f), RoundedCornerShape(17.dp))
                    .clickable { onChoose(selected) }
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (canDismiss) "Switch mode  →" else "Start lesson  →",
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
            if (!fullScreen) {
                Text(
                    "Your live progress and answers stay intact.",
                    color = Muted,
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

/** Compact, always available back-and-forward review without repeating server actions. */
@Composable
fun ClassroomStepNavigation(engine: ClassroomEngine) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 5.dp)
            .background(Color(0xFF121B3D), RoundedCornerShape(20.dp))
            .border(1.dp, Neon.copy(alpha = .36f), RoundedCornerShape(20.dp))
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        StepButton("←  Previous", engine.viewedStepIndex > 0, engine::previousStep, Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(.9f)) {
            Text(
                "${engine.viewedStepIndex + 1} of ${engine.stepCount}",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelMedium,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                repeat(engine.stepCount.coerceAtMost(6)) { index ->
                    Box(
                        modifier = Modifier.size(width = 10.dp, height = 4.dp)
                            .background(
                                if (index <= engine.viewedStepIndex) Neon else Color(0xFF343A68),
                                RoundedCornerShape(3.dp),
                            ),
                    )
                }
            }
        }
        StepButton(
            "Next  →",
            engine.isReviewingPastStep || engine.mayAdvanceLiveStep,
            engine::nextLessonStep,
            Modifier.weight(1f),
            filled = true,
        )
    }
    if (engine.isReviewingPastStep) {
        TextButton(
            onClick = engine::returnToLiveStep,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Review only  ·  Return to live lesson", color = Lilac)
        }
    }
}

@Composable
private fun StepButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    filled: Boolean = false,
) {
    val shape = RoundedCornerShape(22.dp)
    Box(
        modifier = modifier
            .background(
                if (filled && enabled) ButtonGradient
                else Brush.horizontalGradient(listOf(Color(0xFF242452), Color(0xFF151C3F))),
                shape,
            )
            .border(1.dp, if (enabled) Neon.copy(alpha = .8f) else Border.copy(alpha = .35f), shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = if (enabled) Color.White else Muted.copy(alpha = .48f),
            maxLines = 1,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
