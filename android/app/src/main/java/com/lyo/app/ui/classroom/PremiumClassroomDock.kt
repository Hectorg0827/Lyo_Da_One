package com.lyo.app.ui.classroom

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.unit.dp
import java.util.Locale

private val BaseDock = Color(0xFF121A3B)
private val Bright = Color(0xFFAC83FF)
private val DockBorder = Color(0xFF44467D)
private val ActiveGradient = Brush.verticalGradient(listOf(Color(0xFF8051F8), Color(0xFF6559F2)))
private val IdleGradient = Brush.verticalGradient(listOf(Color(0xFF1B2552), Color(0xFF131B3D)))

/** Mode-specific four/three-action dock from the approved reference. */
@Composable
fun PremiumClassroomDock(
    mode: ClassroomDisplayMode,
    canContinue: Boolean,
    continueLabel: String,
    onContinue: () -> Unit,
    onAskQuestion: (String) -> Unit,
    onHint: () -> Unit,
    onTooEasy: () -> Unit,
    allowLiveActions: Boolean,
) {
    var handOpen by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var question by remember { mutableStateOf("") }
    val speechLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val response = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()?.trim().orEmpty()
            if (response.isNotEmpty()) {
                question = listOf(question.trimEnd(), response)
                    .filter(String::isNotBlank).joinToString(" ")
            }
        }
    }
    fun beginSpeech() {
        handOpen = true
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Talk to your teacher")
        }
        try {
            speechLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            // Keep the text field open when the phone has no speech recognizer.
        }
    }
    Column(
        modifier = Modifier.fillMaxWidth()
            .padding(start = 12.dp, end = 12.dp, top = 3.dp, bottom = 6.dp)
            .background(
                Brush.horizontalGradient(listOf(Color(0xFF171B47), BaseDock)),
                RoundedCornerShape(24.dp),
            )
            .border(1.dp, DockBorder, RoundedCornerShape(24.dp))
            .padding(7.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        if (canContinue && continueLabel != "Continue" && continueLabel != "Next") {
            Box(
                modifier = Modifier.fillMaxWidth()
                    .background(ActiveGradient, RoundedCornerShape(16.dp))
                    .clickable(enabled = allowLiveActions, onClick = onContinue)
                    .padding(vertical = 9.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("$continueLabel →", color = Color.White,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold)
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(7.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (mode == ClassroomDisplayMode.REVIEW) {
                ClassroomDockAction("?", "Help", true, allowLiveActions, { onHint() }, Modifier.weight(1f))
                ClassroomDockAction("mic", "Speak", false, allowLiveActions, { beginSpeech() }, Modifier.weight(1f))
                ClassroomDockAction("•••", "More", false, true, { menuOpen = !menuOpen }, Modifier.weight(1f))
            } else {
                ClassroomDockAction(
                    "mic", if (mode == ClassroomDisplayMode.CLASSROOM) "Talk" else "Speak",
                    true, allowLiveActions, { beginSpeech() }, Modifier.weight(1f),
                )
                ClassroomDockAction("✋", "Raise hand", false, allowLiveActions,
                    { handOpen = !handOpen }, Modifier.weight(1f))
                ClassroomDockAction(
                    if (mode == ClassroomDisplayMode.CLASSROOM) "ϟ" else "?",
                    if (mode == ClassroomDisplayMode.CLASSROOM) "Challenge" else "Help",
                    false, allowLiveActions,
                    { if (mode == ClassroomDisplayMode.CLASSROOM) onTooEasy() else onHint() },
                    Modifier.weight(1f),
                )
                ClassroomDockAction("•••", "More", false, true,
                    { menuOpen = !menuOpen }, Modifier.weight(1f))
            }
        }
        if (menuOpen) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = { menuOpen = false; if (allowLiveActions) onHint() }) {
                    Text("Show hint", color = Bright)
                }
                TextButton(onClick = { menuOpen = false; if (allowLiveActions) onTooEasy() }) {
                    Text("Harder question", color = Bright)
                }
            }
        }
        if (handOpen && allowLiveActions) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = question,
                    onValueChange = { question = it },
                    modifier = Modifier.weight(1f),
                    label = { Text("Ask your teacher") },
                    maxLines = 3,
                )
                IconButton(
                    enabled = question.isNotBlank(),
                    onClick = {
                        onAskQuestion(question.trim())
                        question = ""
                        handOpen = false
                    },
                ) {
                    Icon(Icons.Filled.Send, "Send your question", tint = Bright)
                }
            }
        }
    }
}

@Composable
private fun ClassroomDockAction(
    symbol: String,
    label: String,
    active: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(17.dp)
    Column(
        modifier = modifier
            .height(72.dp)
            .background(if (active) ActiveGradient else IdleGradient, shape)
            .border(1.dp, if (active) Bright else DockBorder, shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 6.dp),
        verticalArrangement = Arrangement.SpaceEvenly,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (symbol == "mic") {
            Icon(
                Icons.Filled.Mic,
                contentDescription = null,
                tint = if (enabled) Color.White else Color(0xFF62678D),
                modifier = Modifier.size(24.dp),
            )
        } else {
            Text(
                symbol,
                color = if (enabled) Color(0xFFC8B8FF) else Color(0xFF62678D),
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
            )
        }
        Text(
            label,
            color = if (enabled) Color.White else Color(0xFF73799F),
            fontWeight = if (active) FontWeight.Bold else FontWeight.Normal,
            style = MaterialTheme.typography.labelSmall,
            maxLines = 1,
        )
    }
}
