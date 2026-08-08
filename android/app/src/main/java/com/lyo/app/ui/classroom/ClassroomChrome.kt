package com.lyo.app.ui.classroom

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
 * The "your desk" row — Continue / Get help / Harder case / Raise your
 * hand, ported from web's desk row (classroom/page.tsx) and iOS's bottom
 * lens dock, trimmed to this v1's actually-wired actions (see
 * ClassroomEngine). Settings/notebook panels are a documented follow-up,
 * not yet ported — see the implementation plan.
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
