package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.classroom.catalog.cleanClassroomText
import com.lyo.app.ui.theme.ClassroomTokens

private val FocusPurple = Color(0xFF9562FA)
private val FocusSurface = Color(0xFF111A3F)
private val FocusMuted = Color(0xFFBEC1E6)

/**
 * Focus combines Previous + step progress + backend-safe Next/Resume in ONE row.
 * Reviewing older scenes never resubmits answers.
 */
@Composable
fun FocusStepNavigation(engine: ClassroomEngine) {
    val reviewing = engine.isReviewingPastStep
    val paused = engine.isPaused && !reviewing
    val enabled = reviewing || paused || engine.mayAdvanceLiveStep
    val nextLabel = when {
        reviewing -> "Next ›"
        paused -> "Resume ▶"
        engine.canContinue -> "Next step ›"
        else -> "Next ›"
    }
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 3.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(FocusSurface, RoundedCornerShape(18.dp))
                .border(1.dp, FocusPurple.copy(alpha = .56f), RoundedCornerShape(18.dp))
                .padding(horizontal = 7.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            TextButton(
                onClick = engine::previousStep,
                enabled = engine.viewedStepIndex > 0,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 6.dp),
            ) { Text("‹ Previous", style = MaterialTheme.typography.labelMedium) }
            Text(
                "${engine.viewedStepIndex + 1} of ${engine.stepCount}",
                color = Color.White,
                style = MaterialTheme.typography.labelMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            androidx.compose.material3.Button(
                onClick = {
                    if (reviewing) engine.nextRecordedStep()
                    else if (paused) engine.togglePause()
                    else engine.nextLessonStep()
                },
                enabled = enabled,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    horizontal = 11.dp, vertical = 9.dp,
                ),
                shape = RoundedCornerShape(13.dp),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                    containerColor = FocusPurple,
                ),
            ) { Text(nextLabel, style = MaterialTheme.typography.labelMedium) }
        }
        if (reviewing) {
            TextButton(onClick = engine::returnToLiveStep, modifier = Modifier.fillMaxWidth()) {
                Text("Return to live lesson", color = FocusPurple)
            }
        }
    }
}

/** Shows only after a genuine Lyo spoken contribution; never permanently docked. */
@Composable
fun FocusLyoTipOverlay(message: String, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth()
            .background(
                Brush.horizontalGradient(listOf(Color(0xFF182457), Color(0xFF24164F))),
                RoundedCornerShape(18.dp),
            )
            .border(1.dp, FocusPurple.copy(alpha = .78f), RoundedCornerShape(18.dp))
            .padding(horizontal = 9.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        TransparentClassroomPortrait(
            drawableRes = com.lyo.app.R.drawable.mascot_reading_1,
            contentDescription = "Lyo, the study companion",
            modifier = Modifier.size(39.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text("Lyo's tip", color = FocusPurple, fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelSmall)
            Text(
                cleanClassroomText(message).take(140),
                color = Color.White,
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text("✕", color = FocusMuted, style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.clickable(onClick = onDismiss).padding(7.dp))
    }
}
