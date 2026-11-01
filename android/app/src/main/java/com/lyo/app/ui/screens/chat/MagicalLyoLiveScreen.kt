package com.lyo.app.ui.screens.chat

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Subject
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lyo.app.BuildConfig
import com.lyo.app.R
import kotlinx.coroutines.delay
import java.util.Locale
import kotlin.math.PI
import kotlin.math.sin

private val LiveMint = Color(0xFF79FFCB)
private val LiveBlue = Color(0xFF519CFF)
private val LiveLavender = Color(0xFFA87BFF)
private val LiveCoral = Color(0xFFFF6D83)
private val LiveOrange = Color(0xFFFF9C45)
private val LivePink = Color(0xFFFF678B)
private val LiveWhite = Color(0xFFF8F6FF)

/**
 * Visual layer only. This intentionally reuses canonical Chat's recognizer,
 * TTS, interruption and transcript callbacks. No new AI session or paid API.
 * Canonical standing and reading assets remain unmodified.
 */
@Composable
internal fun MagicalLyoLiveScreen(
    listening: Boolean,
    thinking: Boolean,
    speaking: Boolean,
    microphoneLevel: Float,
    playbackLevel: Float,
    userCaption: String,
    assistantCaption: String,
    thinkingNudge: String,
    messages: List<ChatMsg>,
    error: String?,
    onEnd: () -> Unit,
    onListen: () -> Unit,
    onPause: () -> Unit,
    onTestSpeaker: () -> Unit,
    onInterrupt: () -> Unit,
    onTryHumanVoice: () -> Unit,
    onSendText: (String) -> Unit,
    onTypingChanged: (Boolean) -> Unit,
    onAttach: () -> Unit,
    attachmentCount: Int,
    attachmentsUploading: Boolean,
) {
    val spanish = remember { Locale.getDefault().language == "es" }
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val haptics = LocalHapticFeedback.current
    var typing by remember { mutableStateOf(false) }
    var draftText by remember { mutableStateOf("") }
    var touchCount by remember { mutableIntStateOf(0) }
    var showTouchSpark by remember { mutableStateOf(false) }
    val touchScale = remember { Animatable(1f) }

    fun sendTyped() {
        val message = draftText.trim()
        if (message.isBlank() && attachmentCount == 0) return
        if (attachmentsUploading) return
        onSendText(message)
        draftText = ""
        keyboardController?.hide()
        focusManager.clearFocus()
    }

    LaunchedEffect(touchCount) {
        if (touchCount == 0) return@LaunchedEffect
        showTouchSpark = true
        touchScale.snapTo(1f)
        touchScale.animateTo(1.12f, tween(130))
        touchScale.animateTo(0.97f, tween(130))
        touchScale.animateTo(1f, tween(230))
        showTouchSpark = false
    }
    var showTranscript by remember { mutableStateOf(false) }
    var readingFrame by remember { mutableStateOf(0) }
    val transcriptScroll = rememberLazyListState()
    val transcript = messages.filter { it.role == "user" || it.role == "assistant" }

    LaunchedEffect(thinking) {
        readingFrame = 0
        while (thinking) {
            delay(230)
            readingFrame = (readingFrame + 1) % 4
        }
    }
    LaunchedEffect(showTranscript, transcript.size, messages.lastOrNull()?.content?.length) {
        if (showTranscript && transcript.isNotEmpty()) {
            transcriptScroll.animateScrollToItem(transcript.lastIndex)
        }
    }

    val mascot = if (thinking) when (readingFrame) {
        0 -> R.drawable.mascot_reading_1
        1 -> R.drawable.mascot_reading_2
        2 -> R.drawable.mascot_reading_3
        else -> R.drawable.mascot_reading_4
    } else R.drawable.lyo_live_front

    val status = when {
        speaking -> if (spanish) "Lyo está respondiendo" else "Lyo is responding"
        thinking -> if (spanish) "Lyo está pensando" else "Lyo is thinking"
        listening -> if (spanish) "Estoy escuchando…" else "I'm listening…"
        else -> if (spanish) "Listo para escuchar" else "Ready to listen"
    }
    val headline = when {
        speaking -> if (spanish) "Esto es lo que pienso…" else "Here's what I think…"
        thinking -> if (spanish) "Una idea a la vez." else "One thought at a time."
        else -> if (spanish) "Cuéntame, te escucho." else "Go on, I'm all ears."
    }
    val caption = when {
        speaking -> assistantCaption.ifBlank { if (spanish) "Hablando…" else "Speaking…" }
        thinking -> thinkingNudge.ifBlank {
            if (spanish) "Estoy pensando en tu pregunta…" else "Thinking about your question…"
        }
        listening -> userCaption.ifBlank {
            if (spanish) "Tómate tu tiempo, estoy aquí." else "Take your time. I'm here."
        }
        else -> if (spanish) "¿Qué te gustaría aprender hoy?" else "What would you like to learn today?"
    }
    val stageTransition = rememberInfiniteTransition(label = "lyoLiveMagic")
    val drift by stageTransition.animateFloat(
        initialValue = 0f, targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(if (speaking) 1550 else 4800), RepeatMode.Restart),
        label = "voiceWave",
    )
    val waveLevel by animateFloatAsState(
        targetValue = when {
            speaking -> playbackLevel.coerceIn(0f, 1f)
            listening -> microphoneLevel.coerceIn(0f, 1f)
            else -> 0f
        },
        animationSpec = tween(durationMillis = 120),
        label = "liveAudioEnergy",
    )
    val breathing by stageTransition.animateFloat(
        initialValue = 0.98f, targetValue = 1.025f,
        animationSpec = infiniteRepeatable(tween(if (speaking) 650 else 2250), RepeatMode.Reverse),
        label = "mascotBreath",
    )

    BoxWithConstraints(
        modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                listOf(Color(0xFF030506), Color(0xFF070C10), Color(0xFF080B10), Color(0xFF030506)),
            ),
        ),
    ) {
        val compact = maxHeight < 740.dp
        val characterSize = if (compact) 178.dp else 216.dp
        val heroHeight = if (compact) 215.dp else 280.dp
        Column(
            modifier = Modifier.fillMaxSize().imePadding().padding(horizontal = 18.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(9.dp).background(LiveMint, CircleShape))
                        Spacer(Modifier.width(12.dp))
                        Text(
                            if (spanish) "En vivo con Lyo" else "Live with Lyo",
                            fontSize = if (compact) 24.sp else 28.sp,
                            lineHeight = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = LiveWhite,
                        )
                    }
                    Text(
                        if (spanish) "TU COMPAÑERO DE APRENDIZAJE" else "YOUR PERSONAL LEARNING COMPANION",
                        modifier = Modifier.padding(start = 21.dp, top = 7.dp),
                        color = Color(0xFFAAB2C0),
                        fontSize = 10.sp,
                        letterSpacing = 0.65.sp,
                    )
                }
                Box(
                    modifier = Modifier.size(46.dp).clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                        .clickable(onClick = onEnd),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.Close, contentDescription = if (spanish) "Salir" else "End voice session", tint = LiveWhite)
                }
            }

            if (showTranscript) {
                Text(
                    if (spanish) "Nuestra conversación" else "Our conversation",
                    modifier = Modifier.padding(top = 18.dp, bottom = 8.dp),
                    color = LiveWhite,
                    fontWeight = FontWeight.Bold,
                    fontSize = 24.sp,
                )
                LazyColumn(
                    state = transcriptScroll,
                    modifier = Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(22.dp))
                        .background(Color.White.copy(alpha = 0.08f)).padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(transcript, key = { it.id }) { message ->
                        val latest = message.id == transcript.lastOrNull()?.id
                        val text = if (speaking && latest && message.role == "assistant") assistantCaption
                            else message.content
                        if (text.isNotBlank()) {
                            Column(
                                modifier = Modifier.fillMaxWidth()
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(
                                        if (message.role == "user") LiveLavender.copy(alpha = 0.25f)
                                        else Color.White.copy(alpha = 0.09f),
                                    ).padding(14.dp),
                            ) {
                                Text(
                                    if (message.role == "user") { if (spanish) "Tú" else "You" } else "Lyo",
                                    fontSize = 12.sp, color = LiveMint, fontWeight = FontWeight.SemiBold,
                                )
                                Text(text, fontSize = 14.sp, color = LiveWhite, modifier = Modifier.padding(top = 4.dp))
                            }
                        }
                    }
                    if (listening && userCaption.isNotBlank()) {
                        item {
                            Text(
                                if (spanish) "Tú · en vivo: $userCaption" else "You · live: $userCaption",
                                color = LiveMint, fontSize = 14.sp,
                            )
                        }
                    }
                }
            } else if (typing) {
                Box(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (spanish) "Pregunta a Lyo…" else "Ask Lyo anything…",
                        color = LiveWhite,
                        fontSize = 23.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                Column(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(heroHeight),
                        contentAlignment = Alignment.Center,
                    ) {
                        LiveRibbon(modifier = Modifier.fillMaxWidth().height(heroHeight), drift = drift, speaking = speaking, thinking = thinking)
                        val haloGradient = if (speaking) Brush.sweepGradient(
                            listOf(LiveOrange, Color(0xFFFFC66F), LivePink, Color(0xFFE879F9), LiveOrange),
                        ) else Brush.sweepGradient(
                            listOf(LiveMint.copy(alpha = 0.38f), LiveBlue, LiveLavender, LiveMint),
                        )
                        Box(
                            modifier = Modifier.size(characterSize + 34.dp)
                                .scale(if (speaking) breathing else 1f)
                                .border(2.dp, haloGradient, CircleShape)
                                .background(
                                    Brush.radialGradient(
                                        listOf(if (speaking) LiveOrange.copy(alpha = 0.16f)
                                            else LiveBlue.copy(alpha = 0.1f), Color.Transparent),
                                    ), CircleShape,
                                ),
                        )
                        Image(
                            painter = painterResource(mascot),
                            contentDescription = status,
                            modifier = Modifier.size(characterSize).scale(breathing * touchScale.value)
                                .clickable {
                                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    touchCount += 1
                                },
                            contentScale = ContentScale.Fit,
                        )
                        if (showTouchSpark) {
                            Text(
                                "✦",
                                color = LiveOrange,
                                fontSize = 30.sp,
                                modifier = Modifier.align(Alignment.TopEnd).padding(end = 45.dp, top = 68.dp),
                            )
                        }
                    }
                    Row(
                        modifier = Modifier.clip(RoundedCornerShape(40.dp))
                            .border(1.dp, if (speaking) LiveOrange else LiveMint.copy(alpha = 0.48f), RoundedCornerShape(40.dp))
                            .background(
                                Brush.horizontalGradient(
                                    if (speaking) listOf(Color(0xAB673016), Color(0x99491C35))
                                    else listOf(Color(0x60316775), Color(0x60482F81)),
                                ),
                            )
                            .padding(horizontal = 21.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(Icons.Default.GraphicEq, contentDescription = null,
                            tint = if (speaking) LiveOrange else LiveMint, modifier = Modifier.size(21.dp))
                        Text(status, color = LiveWhite, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                    }
                    Text(
                        headline,
                        modifier = Modifier.fillMaxWidth().padding(top = if (compact) 11.dp else 17.dp),
                        color = LiveWhite,
                        fontWeight = FontWeight.Bold,
                        fontSize = if (compact) 28.sp else 32.sp,
                        lineHeight = if (compact) 34.sp else 40.sp,
                        textAlign = TextAlign.Center,
                    )
                    // The underline is a real voice meter: user microphone
                    // RMS while listening and TTS PCM energy when available.
                    LiveVoiceWave(
                        modifier = Modifier.fillMaxWidth().height(if (compact) 48.dp else 60.dp),
                        level = waveLevel,
                        drift = drift,
                        speaking = speaking,
                        thinking = thinking,
                        listening = listening,
                    )
                    Text(
                        caption,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp)
                            .heightIn(min = 23.dp),
                        color = LiveWhite.copy(alpha = 0.78f),
                        fontSize = if (compact) 14.sp else 15.sp,
                        lineHeight = 23.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                    )
                }
            }

            error?.let {
                Text(it, color = Color(0xFFFFB8C1), fontSize = 12.sp, textAlign = TextAlign.Center,
                    modifier = Modifier.padding(vertical = 5.dp))
            }
            TextButton(onClick = { showTranscript = !showTranscript }) {
                Icon(Icons.Default.Subject, contentDescription = null, tint = Color(0xFFD4BEFF), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    if (showTranscript) { if (spanish) "Volver a Lyo" else "Back to Lyo" }
                    else { if (spanish) "Ver transcripción" else "See transcript" },
                    color = Color(0xFFD4BEFF), fontSize = 14.sp,
                )
            }
            // One compact dock: one mic control, one hang-up, and typed
            // input. The app tab bar is hidden only while Live is active.
            Column(
                modifier = Modifier.fillMaxWidth()
                    .padding(top = 6.dp)
                    .clip(RoundedCornerShape(28.dp))
                    .border(1.dp, Color(0xFF718597).copy(alpha = 0.48f), RoundedCornerShape(28.dp))
                    .background(Color(0xFF141B25))
                    .padding(horizontal = 10.dp, vertical = 9.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    val micEnabled = speaking || thinking || listening
                    Box(
                        modifier = Modifier.size(43.dp).clip(CircleShape)
                            .border(
                                2.dp,
                                if (speaking) Brush.sweepGradient(listOf(LiveOrange, LivePink, LiveOrange))
                                else Brush.sweepGradient(listOf(LiveMint, LiveBlue, LiveMint)),
                                CircleShape,
                            )
                            .background(
                                Brush.linearGradient(
                                    if (speaking) listOf(Color(0xAA672D17), Color(0xAA8E3544))
                                    else listOf(Color(0xB11D343A), Color(0xB119323D)),
                                ),
                            )
                            .clickable {
                                when {
                                    speaking || thinking -> onInterrupt()
                                    listening -> onPause()
                                    else -> onListen()
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            if (micEnabled) Icons.Default.Mic else Icons.Default.MicOff,
                            contentDescription = when {
                                speaking || thinking -> if (spanish) "Interrumpir para hablar" else "Interrupt Lyo to speak"
                                listening -> if (spanish) "Pausar micrófono" else "Mute microphone"
                                else -> if (spanish) "Reanudar micrófono" else "Resume microphone"
                            },
                            tint = if (speaking) LiveOrange else if (micEnabled) LiveMint else Color.LightGray,
                            modifier = Modifier.size(26.dp),
                        )
                    }
                    Box(modifier = Modifier.weight(1f)) {
                    OutlinedTextField(
                    value = draftText,
                    onValueChange = { draftText = it.take(4000) },
                    modifier = Modifier.fillMaxWidth()
                        .onFocusChanged { state ->
                            if (typing != state.isFocused) {
                                typing = state.isFocused
                                onTypingChanged(state.isFocused)
                            }
                        },
                    placeholder = {
                        Text(
                            if (attachmentCount > 0) {
                                if (spanish) "$attachmentCount archivo(s) listo(s)" else "$attachmentCount attachment(s) ready"
                            } else if (spanish) "Pregunta a Lyo…" else "Ask Lyo…",
                            color = Color.White.copy(alpha = 0.52f),
                        )
                    },
                    leadingIcon = {
                        IconButton(onClick = onAttach, enabled = !attachmentsUploading && attachmentCount < 4) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = if (spanish) "Adjuntar archivo o foto" else "Attach photo or document",
                                tint = LiveWhite,
                            )
                        }
                    },
                    trailingIcon = {
                        IconButton(onClick = ::sendTyped,
                            enabled = !attachmentsUploading && (draftText.isNotBlank() || attachmentCount > 0)) {
                            Icon(
                                Icons.Default.Send,
                                contentDescription = if (spanish) "Enviar mensaje" else "Send typed message",
                                tint = if (!attachmentsUploading && (draftText.isNotBlank() || attachmentCount > 0)) LiveMint else Color.Gray,
                            )
                        }
                    },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { sendTyped() }),
                    singleLine = true,
                    shape = RoundedCornerShape(28.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedContainerColor = Color(0xFF10151D),
                        unfocusedContainerColor = Color(0xFF10151D),
                        focusedBorderColor = LiveMint,
                        unfocusedBorderColor = Color.White.copy(alpha = 0.18f),
                        cursorColor = LiveMint,
                    ),
                )
                    }
                }
            }
            if (error != null && !speaking && !thinking) {
                TextButton(onClick = onTestSpeaker) {
                    Text(if (spanish) "Probar el altavoz" else "Test speaker",
                        color = LiveMint, fontSize = 12.sp)
                }
            }
            if (BuildConfig.API_ENVIRONMENT == "staging" && BuildConfig.GPT_LIVE_TRIAL_UI) {
                TextButton(onClick = onTryHumanVoice) {
                    Text(
                        if (spanish) "Laboratorio de voz natural · solo prueba"
                        else "Try more human voice · staging only",
                        fontSize = 12.sp, color = LiveMint,
                    )
                }
            }
        }
    }
}


/**
 * The waveform below the headline follows actual SpeechRecognizer onRmsChanged
 * readings, or Android TTS PCM energy on engines supporting onAudioAvailable.
 * Without available output PCM, speaking uses only a subdued ambient motion.
 */
@Composable
private fun LiveVoiceWave(
    modifier: Modifier,
    level: Float,
    drift: Float,
    speaking: Boolean,
    thinking: Boolean,
    listening: Boolean,
) {
    val colors = if (speaking) listOf(LiveOrange, LivePink, Color(0xFFFFB470))
        else listOf(LiveMint, LiveBlue, LiveLavender)
    val energy = when {
        thinking -> 0.015f
        speaking -> (level * 0.82f).coerceAtLeast(0.06f)
        listening -> level.coerceIn(0f, 1f)
        else -> 0f
    }
    Canvas(modifier) {
        val centerY = size.height * 0.5f
        val brush = Brush.horizontalGradient(colors)
        val maxHeight = (size.height * 0.39f) * energy
        for (layer in 0..2) {
            val path = Path()
            for (step in 0..100) {
                val position = step / 100f
                val envelope = sin((position * PI)).toFloat().coerceAtLeast(0f)
                val motion = sin((position * 13.0 * PI + drift * (0.36 + layer * 0.08) + layer * 0.8)).toFloat()
                val x = size.width * position
                val y = centerY + maxHeight * envelope * motion * (1f - layer * 0.15f)
                if (step == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, brush, style = Stroke(width = 12f - layer * 3f), alpha = 0.06f + layer * 0.09f)
            if (layer == 0) drawPath(path, brush, style = Stroke(width = 3.4f), alpha = 0.75f)
        }
    }
}

/** Decorative waveform: motion follows conversation state, never drives recognition. */
@Composable
private fun LiveRibbon(modifier: Modifier, drift: Float, speaking: Boolean, thinking: Boolean) {
    Canvas(modifier) {
        val center = size.height * 0.54f
        val amplitude = size.height * (if (speaking) 0.17f else if (thinking) 0.08f else 0.12f)
        val colors = listOf(LiveMint, LiveBlue, LiveLavender)
        colors.forEachIndexed { index, color ->
            val path = Path()
            for (step in 0..80) {
                val x = step * size.width / 80f
                val angle = (step / 80f * 2f * PI).toFloat() * 1.4f + drift + index * 0.33f
                val y = center + sin(angle.toDouble()).toFloat() * amplitude + (index - 1) * 22f
                if (step == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, color = color.copy(alpha = 0.12f), style = Stroke(width = 30f))
            drawPath(path, color = color.copy(alpha = 0.64f), style = Stroke(width = 5f))
        }
    }
}
