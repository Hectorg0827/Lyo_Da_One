package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.google.gson.JsonPrimitive
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

/**
 * An `InputField` component — a "transfer"/application-check that requires
 * an actual multi-word written response, gated by a minimum word count
 * (`min_words`, default 6 — see data.classroom.ClassroomComponent.min_words
 * and web's `isTransferReady()` in classroom-contract.mjs, which this
 * mirrors exactly). Submitted once via the component's own `action_intent`
 * if the backend set one, else the "submit_transfer" default (see
 * ClassroomBridge.actionToUserAction).
 */
@Composable
fun A2uiRenderScope.TransferInputRenderer() {
    val question = resolveString("question") ?: resolveString("text") ?: return
    val placeholder = resolveString("placeholder") ?: "Explain in your own words…"
    val minWords = resolve("minWords")?.takeIf { it.isJsonPrimitive }?.asInt ?: 6
    val submitted = resolve("submitted")?.takeIf { it.isJsonPrimitive }?.asBoolean ?: false
    val path = boundPath("response")
    val actionName = literalString("action") ?: "submitTransfer"

    var text by remember(component.id) { mutableStateOf(resolveString("response") ?: "") }
    val wordCount = text.trim().split(Regex("\\s+")).filter { it.isNotBlank() }.size
    val ready = wordCount >= minWords && !submitted

    Column(modifier = Modifier.padding(vertical = 6.dp)) {
        Text(text = question, color = TextPrimary)
        if (submitted) {
            Text(
                text = text,
                color = TextSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            )
        } else {
            OutlinedTextField(
                value = text,
                onValueChange = { newValue ->
                    text = newValue
                    if (path != null) writeLocalDataModel(path, JsonPrimitive(newValue))
                },
                placeholder = { Text(placeholder, color = TextSecondary) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
            )
            Row(modifier = Modifier.padding(top = 8.dp)) {
                Button(
                    onClick = { fireAction(actionName, mapOf("response" to JsonPrimitive(text.trim()))) },
                    enabled = ready,
                    colors = ButtonDefaults.buttonColors(containerColor = LyoPurple, contentColor = Color.White),
                ) {
                    Text("Submit")
                }
            }
        }
    }
}
