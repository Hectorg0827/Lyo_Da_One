package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

@Composable
fun ClassroomModePicker(
    current: ClassroomDisplayMode?,
    canDismiss: Boolean,
    onChoose: (ClassroomDisplayMode) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = { if (canDismiss) onDismiss() },
        title = { Text("Choose your classroom", color = TextPrimary) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Switch how your lesson looks without losing your place.",
                    color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                ClassroomDisplayMode.entries.forEach { mode ->
                    OutlinedButton(
                        onClick = { onChoose(mode) },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(18.dp),
                    ) {
                        Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Text(
                                (if (mode == current) "✓  " else "") + mode.label,
                                style = MaterialTheme.typography.titleSmall,
                                color = ClassroomTokens.AccentPurple,
                            )
                            Text(mode.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = TextSecondary)
                        }
                    }
                }
                Text(
                    "Past steps are read-only. New steps and answers remain controlled by your live teacher.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        },
        confirmButton = {
            if (canDismiss) TextButton(onClick = onDismiss) { Text("Return to lesson") }
            else Text("Select a mode to begin", style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        },
        containerColor = Surface,
    )
}

@Composable
fun ClassroomModeSwitcher(mode: ClassroomDisplayMode, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.padding(horizontal = 14.dp, vertical = 2.dp),
        shape = RoundedCornerShape(20.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text("Mode: ${mode.label} ▾", color = ClassroomTokens.AccentPurple,
            style = MaterialTheme.typography.labelLarge)
    }
}

/** Moves through recorded scenes, never by resending a graded answer. */
@Composable
fun ClassroomStepNavigation(engine: ClassroomEngine) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 3.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface, RoundedCornerShape(16.dp))
                .border(1.dp, ClassroomTokens.AccentPurple.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                .padding(horizontal = 6.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            TextButton(onClick = engine::previousStep, enabled = engine.viewedStepIndex > 0) {
                Text("‹ Previous")
            }
            Text(
                text = "${engine.viewedStepIndex + 1} of ${engine.stepCount}",
                color = TextPrimary,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Center,
            )
            TextButton(
                onClick = engine::nextLessonStep,
                enabled = engine.isReviewingPastStep || engine.mayAdvanceLiveStep,
            ) {
                Text("Next ›")
            }
        }
        if (engine.isReviewingPastStep) {
            TextButton(onClick = engine::returnToLiveStep, modifier = Modifier.fillMaxWidth()) {
                Text("Review only · Return to live lesson")
            }
        }
    }
}
