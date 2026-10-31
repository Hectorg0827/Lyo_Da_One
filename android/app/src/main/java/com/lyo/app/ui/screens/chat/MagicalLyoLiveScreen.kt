package com.lyo.app.ui.screens.chat

import androidx.compose.animation.core.RepeatMode
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
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Subject
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
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
    userCaption: String,
    assistantCaption: String,
    thinkingNudge: String,
    messages: List<ChatMsg>,
    error: String?,
    onEnd: () -> Unit,
    onListen: () -> Unit,
    onTestSpeaker: () -> Unit,
    onInterrupt: () -> Unit,
    onTryHumanVoice: () -> Unit,
) {
    val spanish = remember { Locale.getDefault().language == "es" }
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
    } else R.drawable.mascot_standing

    val status = when {
        speaking -> if (spanish) "Lyo está hablando" else "Lyo is speaking"
        thinking -> if (spanish) "Lyo está pensando" else "Lyo is thinking"
        listening -> if (spanish) "Estoy escuchando…" else "I'm listening…"
        else -> if (spanish) "Listo para escuchar" else "Ready to listen"
    }
    val headline = when {
        speaking -> if (spanish) "Aprendamos juntos." else "Let's learn together."
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
    val breathing by stageTransition.animateFloat(
        initialValue = 0.98f, targetValue = 1.025f,
        animationSpec = infiniteRepeatable(tween(if (speaking) 650 else 2250), RepeatMode.Reverse),
        label = "mascotBreath",
    )

    BoxWithConstraints(
        modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                listOf(Color(0xFF090E28), Color(0xFF20134C), Color(0xFF25124E), Color(0xFF0F1737)),
            ),
        ),
    ) {
        val compact = maxHeight < 700.dp
        val characterSize = if (compact) 184.dp else 234.dp
        val heroHeight = if (compact) 245.dp else 320.dp
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 16.dp),
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
                            fontSize = if (compact) 25.sp else 29.sp,
                            lineHeight = 34.sp,
                            fontWeight = FontWeight.Bold,
                            color = LiveWhite,
                        )
                    }
                    Text(
                        if (spanish) "TU COMPAÑERO DE APRENDIZAJE" else "YOUR PERSONAL LEARNING COMPANION",
                        modifier = Modifier.padding(start = 21.dp, top = 3.dp),
                        color = Color(0xFFC6B7EF),
                        fontSize = 10.sp,
                        letterSpacing = 1.7.sp,
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
                        Box(
                            modifier = Modifier.size(characterSize + 34.dp)
                                .border(2.dp, Brush.sweepGradient(listOf(LiveMint.copy(alpha = 0.2f), LiveBlue, LiveLavender, Color(0xFFFFA66B), LiveMint.copy(alpha = 0.2f))), CircleShape)
                                .background(Brush.radialGradient(listOf(LiveLavender.copy(alpha = 0.17f), Color.Transparent)), CircleShape),
                        )
                        Text("✦", color = LiveMint, fontSize = 26.sp, modifier = Modifier.align(Alignment.TopStart).padding(start = 20.dp, top = 48.dp))
                        Text("✧", color = Color(0xFFFFC873), fontSize = 26.sp, modifier = Modifier.align(Alignment.TopEnd).padding(end = 20.dp, top = 36.dp))
                        Text("∑", color = Color(0xFFB69CFF), fontSize = 18.sp, modifier = Modifier.align(Alignment.BottomStart).padding(start = 23.dp, bottom = 50.dp))
                        Text("✦", color = LiveLavender, fontSize = 18.sp, modifier = Modifier.align(Alignment.BottomEnd).padding(end = 24.dp, bottom = 55.dp))
                        Image(
                            painter = painterResource(mascot),
                            contentDescription = status,
                            modifier = Modifier.size(characterSize).scale(breathing),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    Row(
                        modifier = Modifier.clip(RoundedCornerShape(40.dp))
                            .border(1.dp, LiveMint.copy(alpha = 0.48f), RoundedCornerShape(40.dp))
                            .background(Brush.horizontalGradient(listOf(Color(0x60316775), Color(0x60482F81))))
                            .padding(horizontal = 21.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Icon(Icons.Default.GraphicEq, contentDescription = null, tint = LiveMint, modifier = Modifier.size(21.dp))
                        Text(status, color = LiveWhite, fontWeight = FontWeight.Medium, fontSize = 15.sp)
                    }
                    Text(
                        headline,
                        modifier = Modifier.fillMaxWidth().padding(top = if (compact) 16.dp else 22.dp),
                        color = LiveWhite,
                        fontWeight = FontWeight.Bold,
                        fontSize = if (compact) 29.sp else 34.sp,
                        lineHeight = if (compact) 34.sp else 40.sp,
                        textAlign = TextAlign.Center,
                    )
                    Box(
                        modifier = Modifier.padding(top = 9.dp).size(width = 145.dp, height = 3.dp)
                            .background(Brush.horizontalGradient(listOf(LiveLavender, LiveBlue, LiveMint)), RoundedCornerShape(10.dp)),
                    )
                    Text(
                        caption,
                        modifier = Modifier.fillMaxWidth().padding(top = 17.dp)
                            .clip(RoundedCornerShape(24.dp))
                            .border(1.dp, Color.White.copy(alpha = 0.22f), RoundedCornerShape(24.dp))
                            .background(Color.White.copy(alpha = 0.08f))
                            .padding(horizontal = 19.dp, vertical = if (compact) 13.dp else 18.dp)
                            .heightIn(min = 26.dp),
                        color = LiveWhite.copy(alpha = 0.96f),
                        fontSize = if (compact) 15.sp else 17.sp,
                        lineHeight = 23.sp,
                        maxLines = if (compact) 2 else 3,
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
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 7.dp)
                    .clip(RoundedCornerShape(42.dp))
                    .border(1.dp, Color(0xFF9A86FF).copy(alpha = 0.65f), RoundedCornerShape(42.dp))
                    .background(Brush.horizontalGradient(listOf(Color(0xAA434A83), Color(0xB044287E))))
                    .padding(horizontal = 17.dp, vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                val canAct = speaking || thinking || !listening
                Box(
                    modifier = Modifier.size(58.dp).clip(CircleShape)
                        .background(Color.White.copy(alpha = if (canAct) 0.16f else 0.09f))
                        .clickable(enabled = canAct) {
                            if (speaking || thinking) onInterrupt() else onListen()
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (canAct) Icons.Default.Mic else Icons.Default.MicOff,
                        contentDescription = when {
                            speaking || thinking -> if (spanish) "Interrumpir y hablar" else "Interrupt to speak"
                            listening -> if (spanish) "Escuchando" else "Listening"
                            else -> if (spanish) "Escuchar" else "Listen"
                        },
                        tint = LiveWhite, modifier = Modifier.size(28.dp),
                    )
                }
                Icon(Icons.Default.GraphicEq, contentDescription = null, tint = LiveMint, modifier = Modifier.size(50.dp))
                Box(
                    modifier = Modifier.size(58.dp).clip(CircleShape)
                        .background(Brush.linearGradient(listOf(LiveCoral, Color(0xFFE33A72))))
                        .clickable(onClick = onEnd),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.CallEnd, contentDescription = if (spanish) "Finalizar" else "End", tint = Color.White,
                        modifier = Modifier.size(29.dp))
                }
            }
            if (speaking || thinking) {
                // A fallback remains visible even when hands-free interruption is unavailable.
                TextButton(onClick = onInterrupt) {
                    Text(if (spanish) "Interrumpir para hablar" else "Tap to interrupt",
                        fontSize = 12.sp, color = Color(0xFFE6CBFF))
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
