package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoGold
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.delay

/**
 * Netflix/YouTube-style auto-hiding chrome state, matching the 3s idle
 * timeout already shipped on web (classroom/page.tsx's resetHideTimer) and
 * iOS (ActiveLessonView.swift's resetChromeTimer): visible on load,
 * auto-hides after `ClassroomTokens.CHROME_AUTO_HIDE_MS` of no interaction,
 * never schedules a hide while `blockAutoHide` is true (an active
 * checkpoint — see ClassroomEngine.hasActiveCheckpoint), and is forced back
 * visible the instant a checkpoint appears (blockAutoHide flipping true
 * changes the LaunchedEffect key, cancelling any pending hide).
 */
class ChromeVisibilityState {
    var visible by mutableStateOf(true)
        internal set

    fun poke() {
        visible = true
    }

    fun toggle() {
        visible = !visible
    }
}

@Composable
fun rememberChromeVisibility(blockAutoHide: Boolean): ChromeVisibilityState {
    val state = remember { ChromeVisibilityState() }
    LaunchedEffect(state.visible, blockAutoHide) {
        if (blockAutoHide || !state.visible) return@LaunchedEffect
        delay(ClassroomTokens.CHROME_AUTO_HIDE_MS)
        state.visible = false
    }
    return state
}

@Composable
fun ClassroomTopBar(
    topic: String,
    isPaused: Boolean,
    onBack: () -> Unit,
    onTogglePause: () -> Unit,
    onToggleNotebook: () -> Unit,
    onToggleSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.Filled.ArrowBack, contentDescription = "Leave classroom", tint = TextPrimary)
        }
        Text(
            text = topic,
            color = TextPrimary,
            style = MaterialTheme.typography.titleSmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onToggleNotebook) {
            Icon(Icons.Filled.MenuBook, contentDescription = "Your notebook", tint = TextPrimary)
        }
        IconButton(onClick = onToggleSettings) {
            Icon(Icons.Filled.Settings, contentDescription = "Classroom settings", tint = TextPrimary)
        }
        IconButton(onClick = onTogglePause) {
            Icon(
                imageVector = if (isPaused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                contentDescription = if (isPaused) "Resume class" else "Pause class",
                tint = if (isPaused) ClassroomTokens.Gold else TextPrimary,
            )
        }
    }
}

/**
 * Inline settings row (ported from web's classroom/page.tsx settingsOpen
 * panel), trimmed to what's actually wireable on Android v1: reduced
 * motion is the only setting that previously existed as a wire-contract
 * param (ClassroomSocketClient.connect's reducedMotion) with no user
 * control at all — ClassroomEngine.start() hardcoded `false`. Mode/
 * duration/voice-speed are NOT ported here: all three are connect-time
 * params on the real backend (same as reducedMotion), but changing them
 * live would require tearing down and reopening the WebSocket mid-session
 * — real surgery this v1 deliberately doesn't take on unverified (no
 * device/build available in this environment, see the implementation
 * plan's Verification section) — and voice-speed has nothing to control
 * yet: Android's classroom has no TTS integration in v1 (ClassroomBridge's
 * "ambient" turn handling is stubbed for the same reason).
 */
@Composable
fun SettingsPanel(
    reducedMotion: Boolean,
    onReducedMotionChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text("Accessibility", color = TextPrimary, style = MaterialTheme.typography.labelLarge)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Reduced motion", color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
                Text(
                    "Takes effect next session",
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            Switch(
                checked = reducedMotion,
                onCheckedChange = onReducedMotionChange,
                colors = SwitchDefaults.colors(checkedTrackColor = ClassroomTokens.AccentPurple),
            )
        }
    }
}

/**
 * The notebook drawer — the transcript, a byproduct (ported from web's
 * classroom/page.tsx notebook drawer). Rendered as an inline expanding
 * panel rather than a slide-in side sheet: simpler, and this v1 has no
 * confirmed-working device to validate a custom drawer-gesture/animation
 * against (see the implementation plan's Verification section) — the
 * content and behavior (chronological speaker: text lines, empty-state
 * copy) match web exactly, only the presentation chrome is simplified.
 */
@Composable
fun NotebookPanel(transcript: List<TranscriptLine>, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Filled.MenuBook, contentDescription = null, tint = LyoGold, modifier = Modifier.size(16.dp))
            Text("Your notebook", color = TextPrimary, style = MaterialTheme.typography.labelLarge)
        }
        if (transcript.isEmpty()) {
            Text(
                "Notes will appear as the class goes on.",
                color = TextSecondary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 220.dp)
                    .padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                items(transcript, key = { it.id }) { line ->
                    Row {
                        Text(
                            text = "${line.speaker}: ",
                            color = if (line.speaker == "You") LyoGold else ClassroomTokens.AccentPurple,
                            style = MaterialTheme.typography.labelSmall,
                        )
                        Text(text = line.text, color = TextPrimary, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
}

/**
 * The "your desk" row — Continue / Get help / Harder case / Raise your
 * hand, ported from web's desk row (classroom/page.tsx) and iOS's bottom
 * lens dock, trimmed to this v1's actually-wired actions (see
 * ClassroomEngine). Settings/notebook panels live in SettingsPanel/
 * NotebookPanel below, toggled from ClassroomTopBar.
 */
@Composable
fun BottomActionDock(
    canContinue: Boolean,
    continueLabel: String,
    onContinue: () -> Unit,
    onAskQuestion: (String) -> Unit,
    onHint: () -> Unit,
    onTooEasy: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var handRaised by remember { mutableStateOf(false) }
    var question by remember { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        if (canContinue) {
            Button(
                onClick = onContinue,
                colors = ButtonDefaults.buttonColors(containerColor = ClassroomTokens.AccentPurple, contentColor = androidx.compose.ui.graphics.Color.White),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
            ) {
                Text("$continueLabel →")
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(onClick = onHint) { Text("Get help") }
            OutlinedButton(onClick = onTooEasy) { Text("Harder case") }
            if (handRaised) {
                androidx.compose.material3.OutlinedTextField(
                    value = question,
                    onValueChange = { question = it },
                    placeholder = { Text("Ask the teacher…", color = TextSecondary) },
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = {
                    onAskQuestion(question)
                    question = ""
                    handRaised = false
                }) {
                    Icon(Icons.Filled.Send, contentDescription = "Send", tint = ClassroomTokens.AccentPurple)
                }
            } else {
                OutlinedButton(onClick = { handRaised = true }, modifier = Modifier.weight(1f)) {
                    Text("Raise your hand", color = LyoGold)
                }
            }
        }
    }
}

/** The permanent Teacher badge (never hides with the rest of chrome) sitting
 *  next to the caption — reuses MascotAvatar's rendering machinery directly
 *  via rememberMascotFrame rather than going through the A2UI tree, since
 *  the Teacher's identity here is 100% locally computed (a fixed portrait
 *  per course, matching web/iOS's `TEACHER_VARIANTS[stableHash(courseId)]`
 *  pattern), never driven by a wire-contract field. */
@Composable
fun TeacherBadgeAndCaption(caption: com.google.gson.JsonElement?, modifier: Modifier = Modifier) {
    val speaker = caption?.takeIf { it.isJsonObject }?.asJsonObject?.get("speaker")
        ?.takeIf { it.isJsonPrimitive }?.asString
    val text = caption?.takeIf { it.isJsonObject }?.asJsonObject?.get("text")
        ?.takeIf { it.isJsonPrimitive }?.asString

    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        val frame = com.lyo.app.ui.classroom.catalog.rememberMascotFrame(state = "", variant = "teacher")
        androidx.compose.foundation.Image(
            painter = androidx.compose.ui.res.painterResource(frame.drawableRes),
            contentDescription = "Teacher",
            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
            modifier = frame.modifier
                .size(40.dp)
                .background(Surface, CircleShape),
        )
        if (text != null) {
            Column {
                if (speaker != null) {
                    Text(text = speaker, color = ClassroomTokens.AccentPurple, style = MaterialTheme.typography.labelSmall)
                }
                Text(text = text, color = TextPrimary, style = MaterialTheme.typography.bodyMedium, maxLines = 3, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
