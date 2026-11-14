package com.lyo.app.ui.screens.chat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lyo.app.R
import com.lyo.app.ui.theme.LyoPurple
import java.util.Locale
import kotlinx.coroutines.delay

/**
 * Live mode is a distinct, mascot-led screen. It shares ChatScreen's canonical
 * messages and stream, so returning to text chat never loses the conversation.
 */
@Composable
internal fun LiveVoiceConversationScreen(
    listening: Boolean,
    thinking: Boolean,
    speaking: Boolean,
    userCaption: String,
    assistantCaption: String,
    thinkingNudge: String,
    messages: List<ChatMsg>,
    error: String?,
    onEnd: () -> Unit,
) {
    var transcriptVisible by remember { mutableStateOf(false) }
    var readingFrame by remember { mutableStateOf(0) }
    val spanish = remember { Locale.getDefault().language == "es" }
    val transcriptState = rememberLazyListState()

    LaunchedEffect(thinking) {
        readingFrame = 0
        while (thinking) {
            delay(220)
            readingFrame = (readingFrame + 1) % 4
        }
    }
    LaunchedEffect(transcriptVisible, messages.size, messages.lastOrNull()?.content?.length) {
        val visibleCount = messages.count { it.role == "user" || it.role == "assistant" }
        if (transcriptVisible && visibleCount > 0) {
            transcriptState.animateScrollToItem(visibleCount - 1)
        }
    }

    val pulse = rememberInfiniteTransition(label = "voicePulse")
    val scale by pulse.animateFloat(
        initialValue = 0.96f,
        targetValue = 1.045f,
        animationSpec = infiniteRepeatable(
            tween(if (speaking) 470 else 950), RepeatMode.Reverse,
        ),
        label = "mascotBreathing",
    )
    val image = if (thinking) when (readingFrame) {
        0 -> R.drawable.mascot_reading_1
        1 -> R.drawable.mascot_reading_2
        2 -> R.drawable.mascot_reading_3
        else -> R.drawable.mascot_reading_4
    } else R.drawable.mascot_standing

    val status = when {
        speaking -> if (spanish) "Lyo está hablando" else "Lyo is speaking"
        thinking -> if (spanish) "Lyo está pensando" else "Lyo is thinking"
        listening -> if (spanish) "Escuchando" else "Listening"
        else -> if (spanish) "Listo para escuchar" else "Ready to listen"
    }
    val caption = when {
        speaking -> assistantCaption.ifBlank { if (spanish) "Hablando…" else "Speaking…" }
        thinking -> thinkingNudge.ifBlank {
            if (spanish) "Pensando en tu pregunta…" else "Thinking about your question…"
        }
        listening -> userCaption.ifBlank {
            if (spanish) "Adelante, te escucho." else "Go ahead. I'm listening."
        }
        else -> userCaption.ifBlank {
            if (spanish) "Habla con naturalidad." else "Speak naturally to begin."
        }
    }
    val transcript = messages.filter { it.role == "user" || it.role == "assistant" }

    Column(
        modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                listOf(Color(0xFF100D20), Color(0xFF211237), Color(0xFF110E24)),
            ),
        ).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(
                    if (spanish) "●  En vivo con Lyo" else "●  Live with Lyo",
                    color = Color(0xFF95EDC3),
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    if (spanish) "Tu compañero de aprendizaje" else "Your personal learning companion",
                    color = Color.White.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            TextButton(onClick = onEnd) {
                Icon(Icons.Default.Close, contentDescription = null, tint = Color.White)
                Text(if (spanish) "Salir" else "End", color = Color.White)
            }
        }

        Box(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(contentAlignment = Alignment.Center) {
                    Box(
                        modifier = Modifier.size(250.dp).scale(scale).clip(CircleShape)
                            .background(
                                if (speaking) Color(0x663FBC93)
                                else if (listening) Color(0x4455CDA0)
                                else Color(0x553A2A7A),
                            ),
                    )
                    Image(
                        painter = painterResource(image),
                        contentDescription = status,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.size(235.dp).scale(scale),
                    )
                }
                Text(
                    status,
                    color = Color(0xFFCBBAFF),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 24.dp),
                )
                Text(
                    caption,
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 14.dp).fillMaxWidth().heightIn(min = 90.dp),
                )
                Text(
                    when {
                        speaking -> if (spanish) "Habla para interrumpir a Lyo"
                            else "Just start talking to interrupt Lyo"
                        thinking -> if (spanish) "Estoy preparando la respuesta"
                            else "I'm working on your answer"
                        else -> if (spanish) "Lyo responderá al terminar de hablar"
                            else "Lyo will answer when you finish speaking"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.55f),
                    textAlign = TextAlign.Center,
                )
                error?.let {
                    Text(
                        it,
                        color = Color(0xFFFF9A9A),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 12.dp),
                    )
                }
            }
        }

        if (transcriptVisible) {
            LazyColumn(
                state = transcriptState,
                modifier = Modifier.fillMaxWidth().weight(0.75f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Color.White.copy(alpha = 0.07f)).padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(transcript, key = { it.id }) { message ->
                    val latest = message.id == transcript.lastOrNull()?.id
                    val visibleText = if (speaking && latest && message.role == "assistant")
                        assistantCaption else message.content
                    if (visibleText.isNotBlank()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (message.role == "user") LyoPurple.copy(alpha = 0.24f)
                                    else Color.White.copy(alpha = 0.07f),
                                ).padding(12.dp),
                        ) {
                            Text(
                                if (message.role == "user") {
                                    if (spanish) "Tú" else "You"
                                } else "Lyo",
                                color = Color.White.copy(alpha = 0.55f),
                                style = MaterialTheme.typography.labelSmall,
                            )
                            Text(visibleText, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
                if (listening && userCaption.isNotBlank()) {
                    item {
                        Text(
                            if (spanish) "Tú · en vivo: $userCaption" else "You · live: $userCaption",
                            color = Color(0xFFCBBAFF),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }
        }

        TextButton(onClick = { transcriptVisible = !transcriptVisible }) {
            Text(
                if (transcriptVisible) {
                    if (spanish) "Ocultar transcripción" else "Hide transcript"
                } else {
                    if (spanish) "Ver transcripción en vivo" else "View live transcript"
                },
                color = Color(0xFFCBBAFF),
            )
        }
    }
}
