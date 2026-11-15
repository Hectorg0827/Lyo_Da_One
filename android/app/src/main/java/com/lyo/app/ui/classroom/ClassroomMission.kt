package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlin.math.roundToInt

/**
 * Small, genuinely interactive practice while the server builds its first
 * teaching scene. No network, fake AI assessment, local mastery score, or
 * learner-record mutation. The real lesson replaces this automatically.
 */
@Composable
internal fun ClassroomMission(
    topic: String,
    modifier: Modifier = Modifier,
    onInteraction: () -> Unit = {},
    liveLessonReady: Boolean = false,
    onEnterLive: () -> Unit = {},
) {
    when (starterMissionFor(topic)) {
        StarterMissionKind.FAIR_TEST -> FairTestMission(topic, modifier, onInteraction, liveLessonReady, onEnterLive)
        StarterMissionKind.FRACTIONS -> FractionBarMission(topic, modifier, onInteraction, liveLessonReady, onEnterLive)
        StarterMissionKind.GENERAL -> ClassroomWarmup(
            topic, modifier, onInteraction, liveLessonReady, onEnterLive,
        )
    }
}

@Composable
private fun MissionFrame(
    title: String,
    instruction: String,
    modifier: Modifier,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .background(Surface, RoundedCornerShape(20.dp))
            .border(1.dp, LyoVioletLight.copy(alpha = 0.30f), RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("TRY IT WHILE YOUR TEACHER GETS READY", color = LyoVioletLight,
            style = MaterialTheme.typography.labelSmall)
        Text(title, color = TextPrimary, style = MaterialTheme.typography.titleMedium)
        Text(instruction, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
        content()
        if (liveLessonReady) {
            Button(
                onClick = onEnterLive,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Enter live lesson")
            }
        } else {
            Text("Practice only, not graded. Your lesson is preparing.",
                color = TextSecondary, style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun FairTestMission(
    topic: String,
    modifier: Modifier,
    onInteraction: () -> Unit,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
) {
    var waterB by remember(topic) { mutableIntStateOf(1) }
    var sunlightB by remember(topic) { mutableIntStateOf(6) }
    val experiment = FairExperiment(waterB = waterB, sunlightB = sunlightB)
    val check = checkFairExperiment(experiment)
    MissionFrame(
        title = "Design a fair experiment",
        instruction = "Can you test water's effect on a plant? Move the controls until only water is different.",
        modifier = modifier,
        liveLessonReady = liveLessonReady,
        onEnterLive = onEnterLive,
    ) {
        Text("🌱 Plant A (reference): 1 cup water · 6 hours sunlight",
            color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
        Text("🌿 Plant B: ${waterB} ${if (waterB == 1) "cup" else "cups"} water · ${sunlightB} hours sunlight",
            color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
        Text("Plant B · Water (${waterB} ${if (waterB == 1) "cup" else "cups"})",
            color = TextPrimary)
        Slider(
            value = waterB.toFloat(),
            onValueChange = {
                waterB = it.roundToInt().coerceIn(1, 3)
                onInteraction()
            },
            valueRange = 1f..3f,
            steps = 1,
            modifier = Modifier.semantics { contentDescription = "Water for Plant B in cups" },
        )
        Text("Plant B · Sunlight ($sunlightB hours)", color = TextPrimary)
        Slider(
            value = sunlightB.toFloat(),
            onValueChange = {
                sunlightB = it.roundToInt().coerceIn(4, 8)
                onInteraction()
            },
            valueRange = 4f..8f,
            steps = 3,
            modifier = Modifier.semantics { contentDescription = "Sunlight for Plant B in hours" },
        )
        Text(
            text = if (check.ready) "✓ ${check.guidance}" else check.guidance,
            color = if (check.ready) LyoVioletLight else TextSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun FractionBarMission(
    topic: String,
    modifier: Modifier,
    onInteraction: () -> Unit,
    liveLessonReady: Boolean,
    onEnterLive: () -> Unit,
) {
    var numerator by remember(topic) { mutableIntStateOf(1) }
    MissionFrame(
        title = "Build three quarters",
        instruction = "Drag the slider to shade exactly 3 out of 4 equal parts. Watch the fraction change.",
        modifier = modifier,
        liveLessonReady = liveLessonReady,
        onEnterLive = onEnterLive,
    ) {
        Text("${numerator}/4 of a whole", color = TextPrimary,
            style = MaterialTheme.typography.titleMedium)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            repeat(4) { index ->
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier.weight(1f)
                        .background(
                            if (index < numerator) LyoVioletLight else TextSecondary.copy(alpha = 0.15f),
                            RoundedCornerShape(5.dp),
                        )
                        .border(1.dp, LyoVioletLight.copy(alpha = 0.45f), RoundedCornerShape(5.dp))
                        .padding(vertical = 16.dp),
                )
            }
        }
        Text("Shaded parts: $numerator", color = TextPrimary)
        Slider(
            value = numerator.toFloat(),
            onValueChange = {
                numerator = it.roundToInt().coerceIn(0, 4)
                onInteraction()
            },
            valueRange = 0f..4f,
            steps = 3,
            modifier = Modifier.semantics { contentDescription = "Number of shaded quarters" },
        )
        Text(
            text = if (fractionGoalReached(numerator)) {
                "✓ You built 3/4. Each of the four parts has the same size."
            } else {
                "Try shading exactly three parts, then explain what the bottom number means."
            },
            color = if (fractionGoalReached(numerator)) LyoVioletLight else TextSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
