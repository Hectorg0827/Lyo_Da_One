package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.LyoVioletLight
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/**
 * One teacher, one voice, two parallel processes: this is an UNGRADED
 * conversation, not a Classroom checkpoint. The authoritative lesson replaces
 * it immediately on scene_start; no mastery/evidence is written here.
 */
@Composable
fun ContinuousTeachingCard(
    text: String,
    phase: String,
    prompt: Boolean,
    spanish: Boolean,
    onReply: (String) -> Boolean,
    modifier: Modifier = Modifier,
) {
    var draft by remember(text, phase) { mutableStateOf("") }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(20.dp))
            .border(1.dp, LyoVioletLight.copy(alpha = 0.40f), RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            if (spanish) {
                if (phase == "startup") "EMPECEMOS AHORA · SIN CALIFICACIÓN"
                else "CONECTEMOS IDEAS · SIN CALIFICACIÓN"
            } else {
                if (phase == "startup") "START LEARNING NOW · NOT GRADED"
                else "CONNECTING IDEAS · NOT GRADED"
            },
            color = LyoVioletLight,
            style = MaterialTheme.typography.labelSmall,
        )
        Text(
            text,
            color = TextPrimary,
            style = MaterialTheme.typography.titleMedium,
        )
        if (prompt) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it.take(300) },
                modifier = Modifier.fillMaxWidth(),
                maxLines = 2,
                label = {
                    Text(if (spanish) "Comparte tu idea" else "Share your thinking")
                },
            )
            Button(
                enabled = draft.isNotBlank(),
                onClick = {
                    if (onReply(draft)) draft = ""
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (spanish) "Responder" else "Reply")
            }
        } else {
            Text(
                if (spanish) "Conectando tu idea con la clase…"
                else "Connecting your thought to the lesson…",
                color = TextSecondary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}
