package com.lyo.app.ui.classroom

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.data.api.LearnerConceptRecordDto
import com.lyo.app.data.api.LearnerEvidenceRecordDto
import com.lyo.app.data.classroom.ClassroomOpening
import com.lyo.app.data.classroom.ClassroomSessionContract
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.ClassroomTokens
import com.lyo.app.ui.theme.LyoGold
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.delay
import java.util.Locale

/**
 * Immersive chrome state shared by the native classroom surfaces: visible on load,
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
    isVoiceEnabled: Boolean,
    onBack: () -> Unit,
    onTogglePause: () -> Unit,
    onToggleVoice: () -> Unit,
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
        Column(modifier = Modifier.weight(1f)) {
            Text("LYO CLASSROOM", color = ClassroomTokens.AccentPurple,
                style = MaterialTheme.typography.labelSmall)
            Text(topic, color = TextPrimary, style = MaterialTheme.typography.titleSmall,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        IconButton(onClick = onToggleNotebook) {
            Icon(Icons.Filled.MenuBook, contentDescription = "Your notebook", tint = TextPrimary)
        }
        IconButton(onClick = onToggleSettings) {
            Icon(Icons.Filled.Settings, contentDescription = "Classroom settings", tint = TextPrimary)
        }
        IconButton(onClick = onToggleVoice) {
            Icon(
                imageVector = if (isVoiceEnabled) Icons.Filled.VolumeUp else Icons.Filled.VolumeOff,
                contentDescription = if (isVoiceEnabled) "Mute teacher voice" else "Enable teacher voice",
                tint = if (isVoiceEnabled) TextPrimary else TextSecondary,
            )
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
 * panel). Reduced motion is applied on the next session; spoken captions
 * are immediate. Lesson length is a server session parameter, so choosing
 * a different length explicitly starts a new lesson rather than silently
 * extending or shortening the current one.
 */
@Composable
fun SettingsPanel(
    reducedMotion: Boolean,
    onReducedMotionChange: (Boolean) -> Unit,
    captionsEnabled: Boolean,
    onCaptionsEnabledChange: (Boolean) -> Unit,
    durationMinutes: Int,
    onDurationChange: (Int) -> Unit,
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
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Spoken captions", color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
                Text("Brief captions; full lesson in the notebook", color = TextSecondary, style = MaterialTheme.typography.labelSmall)
            }
            Switch(
                checked = captionsEnabled,
                onCheckedChange = onCaptionsEnabledChange,
                colors = SwitchDefaults.colors(checkedTrackColor = ClassroomTokens.AccentPurple),
            )
        }
        Text("Lesson length", color = TextPrimary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 12.dp))
        Text("Selecting a new length starts a fresh lesson.", color = TextSecondary, style = MaterialTheme.typography.labelSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
            ClassroomLessonDuration.choices.forEach { minutes ->
                OutlinedButton(
                    onClick = { onDurationChange(minutes) },
                    enabled = minutes != durationMinutes,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("$minutes min", color = if (minutes == durationMinutes) ClassroomTokens.AccentPurple else TextPrimary)
                }
            }
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
fun NotebookPanel(
    transcript: List<TranscriptLine>,
    learnerRecord: LearnerEvidenceRecordDto?,
    learnerRecordLoading: Boolean,
    learnerRecordFailed: Boolean,
    currentConceptIds: List<String>,
    modifier: Modifier = Modifier,
) {
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
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 320.dp)
                .padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            item {
                Text(
                    "What you've shown",
                    color = TextPrimary,
                    style = MaterialTheme.typography.labelLarge,
                )
                Text(
                    "Read from committed evidence. Being taught something does not count as proof.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(top = 2.dp, bottom = 4.dp),
                )
            }

            when {
                learnerRecordLoading && learnerRecord == null -> item {
                    Text("Reading your record…", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                }
                learnerRecordFailed || learnerRecord?.unavailable == true -> item {
                    Text(
                        "Your record could not be loaded just now. This is not a reading of your work — nothing you have done has been lost.",
                        color = LyoGold,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                learnerRecord?.concepts.isNullOrEmpty() -> item {
                    Text(
                        "Nothing recorded yet. Answering a checkpoint is what puts something here.",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                else -> {
                    val current = currentConceptIds.toSet()
                    val ordered = learnerRecord!!.concepts.sortedByDescending { it.conceptId in current }
                    items(ordered, key = { it.conceptId }) { concept ->
                        LearnerConceptRecordCard(concept, concept.conceptId in current)
                    }
                }
            }

            item {
                Text(
                    "Class notes",
                    color = TextPrimary,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.padding(top = 7.dp),
                )
            }
            if (transcript.isEmpty()) {
                item {
                    Text(
                        "Notes will appear as the class goes on.",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            } else {
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

@Composable
private fun LearnerConceptRecordCard(concept: LearnerConceptRecordDto, current: Boolean) {
    val reached = concept.rungs.map { it.kind }.toSet()
    val ladder = listOf("recognition", "explanation", "application", "transfer", "retention")
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface, RoundedCornerShape(9.dp))
            .padding(9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = concept.displayName ?: humanizeConceptId(concept.conceptId),
                color = TextPrimary,
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier.weight(1f),
            )
            if (current) {
                Text("This class", color = ClassroomTokens.AccentPurple, style = MaterialTheme.typography.labelSmall)
            }
        }
        Text(
            humanizeEvidenceState(concept.state),
            color = ClassroomTokens.AccentPurple,
            style = MaterialTheme.typography.labelSmall,
        )
        ladder.forEach { rung ->
            val shown = rung in reached
            Text(
                text = "${if (shown) "✓" else "🔒"} ${evidenceLabel(rung)} — ${if (shown) "shown" else "not shown yet"}",
                color = if (shown) TextPrimary else TextSecondary,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        concept.misconception?.takeIf { it.isNotBlank() }?.let {
            Text(
                "Worth a second look: $it",
                color = LyoGold,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        concept.nextRung?.let {
            Text(
                "Next: ${evidenceLabel(it)}",
                color = ClassroomTokens.AccentPurple,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(top = 3.dp),
            )
        }
    }
}

private fun evidenceLabel(value: String): String = when (value) {
    "recognition" -> "Recognized"
    "explanation" -> "Explained"
    "application" -> "Applied"
    "transfer" -> "Transferred"
    "retention" -> "Remembered"
    else -> value.replace("_", " ").replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
}

private fun humanizeEvidenceState(value: String): String =
    value.replace("_", " ").lowercase().replaceFirstChar { it.titlecase() }

private fun humanizeConceptId(value: String): String =
    value.replace("_", " ").replace("-", " ")
        .split(" ").filter { it.isNotBlank() }
        .joinToString(" ") { token -> token.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() } }

/**
 * The "your desk" row — Continue / Help / Challenge / Raise hand.
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
    val context = LocalContext.current
    val speechLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val transcript = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (transcript.isNotEmpty()) {
                question = listOf(question.trimEnd(), transcript)
                    .filter { it.isNotBlank() }
                    .joinToString(" ")
            }
        }
    }

    fun startDictation() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Ask the teacher")
        }
        try {
            speechLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            // Text input remains fully available when device dictation is absent.
        }
    }

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
        if (handRaised) {
            // Question entry is its own row. Previously Help + Challenge +
            // text field + two icons competed for one 320dp-wide line,
            // leaving the input and send control underneath the screen edge.
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                androidx.compose.material3.OutlinedTextField(
                    value = question,
                    onValueChange = { question = it },
                    placeholder = { Text("Ask the teacher…", color = TextSecondary) },
                    singleLine = false,
                    maxLines = 3,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = { startDictation() }) {
                    Icon(Icons.Filled.Mic, contentDescription = "Speak your question", tint = ClassroomTokens.AccentPurple)
                }
                IconButton(
                    onClick = {
                        if (question.isNotBlank()) {
                            onAskQuestion(question.trim())
                            question = ""
                            handRaised = false
                        }
                    },
                    enabled = question.isNotBlank(),
                ) {
                    Icon(Icons.Filled.Send, contentDescription = "Send", tint = ClassroomTokens.AccentPurple)
                }
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedButton(onClick = onHint, modifier = Modifier.weight(1f).heightIn(min = 48.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Help") }
                OutlinedButton(onClick = { handRaised = false }, modifier = Modifier.weight(1f).heightIn(min = 48.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Close") }
            }
        } else {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedButton(onClick = onHint, modifier = Modifier.weight(1f).heightIn(min = 48.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Help") }
                OutlinedButton(onClick = onTooEasy, modifier = Modifier.weight(1f).heightIn(min = 48.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Challenge") }
                OutlinedButton(onClick = { handRaised = true }, modifier = Modifier.weight(1f).heightIn(min = 48.dp), contentPadding = PaddingValues(horizontal = 8.dp)) {
                    Text("Raise hand", color = LyoGold)
                }
            }
        }
    }
}

/** A contextual teacher badge sitting
 *  next to the caption — reuses MascotAvatar's rendering machinery directly
 *  via rememberMascotFrame rather than going through the A2UI tree, since
 *  the Teacher's identity here is 100% locally computed (a fixed portrait
 *  per course, matching web/iOS's `TEACHER_VARIANTS[stableHash(courseId)]`
 *  pattern), never driven by a wire-contract field. */
@Composable
fun TeacherBadgeAndCaption(caption: com.google.gson.JsonElement?, topic: String, modifier: Modifier = Modifier, lessonRecovery: Boolean = false, onTranscript: () -> Unit = {}) {
    val speaker = caption?.takeIf { it.isJsonObject }?.asJsonObject?.get("speaker")
        ?.takeIf { it.isJsonPrimitive }?.asString
    val text = caption?.takeIf { it.isJsonObject }?.asJsonObject?.get("text")
        ?.takeIf { it.isJsonPrimitive }?.asString
    val character = ClassroomCast.speaker(speaker, topic)

    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .background(Surface, RoundedCornerShape(16.dp))
            .padding(12.dp),
    ) {
        Image(
            painter = painterResource(character.portrait),
            contentDescription = "${character.name}, ${if (character.id.startsWith("student_")) "AI classmate" else "AI teacher"}",
            contentScale = androidx.compose.ui.layout.ContentScale.Fit,
            modifier = Modifier
                .size(48.dp)
                .background(androidx.compose.ui.graphics.Color.White, RoundedCornerShape(12.dp)),
        )
        if (text != null) {
            Column(modifier = Modifier.weight(1f)) {
                if (speaker != null) {
                    Text(text = "${character.name} · ${if (character.id.startsWith("student_")) "AI classmate" else "AI teacher"}", color = ClassroomTokens.AccentPurple, style = MaterialTheme.typography.labelSmall)
                }
                Text(text = text, color = TextPrimary, style = MaterialTheme.typography.bodyMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        } else {
            Text("Your teacher is speaking", color = TextSecondary, modifier = Modifier.weight(1f))
        }
        Column {
            if (lessonRecovery) Text("Paused", color = ClassroomTokens.Gold, style = MaterialTheme.typography.labelSmall)
            androidx.compose.material3.TextButton(onClick = onTranscript) { Text("Transcript", color = ClassroomTokens.AccentPurple) }
        }
    }
}

/** Lyo remains beside the learner, not in the teacher's seat. */
@Composable
fun LyoCompanionBadge(state: String, spokenClassmates: List<String>, modifier: Modifier = Modifier, caption: com.google.gson.JsonElement? = null) {
    val frame = com.lyo.app.ui.classroom.catalog.rememberMascotFrame(state = state, variant = "lyo")
    val text = caption?.takeIf { it.isJsonObject }?.asJsonObject?.get("text")
        ?.takeIf { it.isJsonPrimitive }?.asString
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.fillMaxWidth().padding(horizontal = 12.dp)
            .background(Surface.copy(alpha = 0.78f), RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Image(painter = painterResource(frame.drawableRes), contentDescription = "Lyo, your companion",
            modifier = frame.modifier.size(30.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text("LYO  ·  Your study companion", color = TextSecondary, style = MaterialTheme.typography.labelSmall)
            if (text != null) Text(text, color = TextPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall)
        }
        ClassroomCast.classmates.filter { it.name in spokenClassmates }.forEach { peer ->
            Image(painter = painterResource(peer.portrait), contentDescription = "${peer.name}, AI classmate",
                modifier = Modifier.size(28.dp).background(androidx.compose.ui.graphics.Color.White, CircleShape))
        }
    }
}

/**
 * The first thing on the board: what this class is, before any of it is
 * taught.
 *
 * A lesson used to open on whatever the engine generated first, which left a
 * learner no way to tell the start of a class from the middle of one — worst
 * of all on a resumed session, where the teacher really did carry on from a
 * place the learner had been given no reminder of. This says the subject,
 * what the session is for, how long it runs, and that they are allowed to
 * interrupt. It teaches nothing, and claims nothing the class was not asked
 * for.
 */
@Composable
fun OpeningCard(opening: ClassroomOpening, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp)
            .background(Surface, RoundedCornerShape(16.dp))
            .padding(14.dp),
    ) {
        Text(opening.title, color = TextPrimary, style = MaterialTheme.typography.titleMedium)
        if (opening.resumed) {
            Text(
                "Picking up where you left off",
                color = ClassroomTokens.AccentPurple,
                style = MaterialTheme.typography.labelSmall,
            )
        }
        Text(
            "By the end: ${opening.objective}",
            color = TextPrimary,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 6.dp),
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(top = 8.dp),
        ) {
            opening.facts.forEach { fact ->
                Text(
                    fact,
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier
                        .background(Background, RoundedCornerShape(10.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                )
            }
        }
        Text(
            opening.note,
            color = TextSecondary,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

/**
 * The step never arrived.
 *
 * Says so, says it is not the learner's fault, and gives them two things that
 * actually move the class on — asking again, and leaving the stuck session
 * behind. A retry that silently re-enters the same dead session is what made
 * this a loop rather than a hiccup.
 */
@Composable
fun StallRecoveryCard(
    onAskAgain: () -> Unit,
    onStartOver: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text("This step is stuck", color = TextPrimary, style = MaterialTheme.typography.labelLarge)
        Text(
            ClassroomSessionContract.STALL_RECOVERY,
            color = TextSecondary,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(top = 4.dp),
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 10.dp),
        ) {
            Button(
                onClick = onAskAgain,
                colors = ButtonDefaults.buttonColors(
                    containerColor = ClassroomTokens.AccentPurple,
                    contentColor = TextPrimary,
                ),
            ) { Text("Ask Lyo again") }
            OutlinedButton(onClick = onStartOver) { Text("Start this lesson over") }
        }
    }
}

/**
 * A problem the classroom reported and is carrying on from. Not the error
 * text above the board: the class is still open.
 */
@Composable
fun ClassroomNoticeCard(
    message: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            message,
            color = TextSecondary,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
        )
        OutlinedButton(onClick = onDismiss) { Text("Dismiss") }
    }
}

/**
 * A seat the learner left part-way through, offered rather than forced on
 * them. Opening the same topic again now starts a new class, so the old one
 * has to be reachable on purpose or it is simply gone.
 */
@Composable
fun ResumeOfferCard(onResume: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .background(Surface, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            "You have an unfinished class on this topic.",
            color = TextSecondary,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
        )
        Button(
            onClick = onResume,
            colors = ButtonDefaults.buttonColors(
                containerColor = ClassroomTokens.AccentPurple,
                contentColor = TextPrimary,
            ),
        ) { Text("Pick up") }
    }
}
