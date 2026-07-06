package com.lyo.app.ui.screens.chat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ChatStreamClient
import com.lyo.app.data.api.ChatStreamEvent
import com.lyo.app.data.api.SimpleChatRequest
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlin.math.max
import kotlinx.coroutines.launch

data class ChatMsg(val role: String, val content: String)

private val Suggestions = listOf(
    "Explain quantum computing",
    "Make me a study plan",
    "Help me learn Spanish",
    "Summarize photosynthesis",
)

@Composable
fun ChatScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()
    val messages = remember { mutableStateListOf<ChatMsg>() }
    var input by remember { mutableStateOf("") }
    var isStreaming by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    fun send(raw: String) {
        val text = raw.trim()
        if (text.isEmpty() || isStreaming) return
        val history = messages.map { mapOf("role" to it.role, "content" to it.content) }
        messages.add(ChatMsg("user", text))
        messages.add(ChatMsg("assistant", ""))
        input = ""
        isStreaming = true
        scope.launch {
            ChatStreamClient.stream(text, history).collect { event ->
                when (event) {
                    is ChatStreamEvent.Chunk -> {
                        val last = messages.last()
                        messages[messages.size - 1] =
                            last.copy(content = last.content + event.text)
                    }

                    is ChatStreamEvent.Done -> Unit

                    is ChatStreamEvent.Error -> {
                        val fallback = runCatching {
                            ApiClient.api.simpleChat(SimpleChatRequest(text))
                        }.getOrNull()?.response
                        messages[messages.size - 1] = messages.last().copy(
                            content = fallback ?: "Sorry, something went wrong."
                        )
                    }
                }
            }
            isStreaming = false
        }
    }

    LaunchedEffect(messages.size) {
        listState.animateScrollToItem(max(0, messages.size - 1))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
            .imePadding(),
    ) {
        if (messages.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
            ) {
                Text(
                    text = "Lyo AI",
                    style = MaterialTheme.typography.headlineLarge,
                    color = TextPrimary,
                )
                Text(
                    text = "Ask me anything about learning",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
                )
                Suggestions.forEach { suggestion ->
                    Box(
                        modifier = Modifier
                            .padding(vertical = 4.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(Surface)
                            .border(1.dp, BorderColor, RoundedCornerShape(20.dp))
                            .clickable(enabled = !isStreaming) { send(suggestion) }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                    ) {
                        Text(
                            text = suggestion,
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextPrimary,
                        )
                    }
                }
            }
        } else {
            LazyColumn(
                state = listState,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(16.dp),
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                items(messages) { msg ->
                    MessageBubble(
                        msg = msg,
                        showTyping = isStreaming &&
                            msg === messages.lastOrNull() &&
                            msg.role == "assistant" &&
                            msg.content.isEmpty(),
                    )
                }
            }
        }

        // Input bar pinned at the bottom.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface)
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                enabled = !isStreaming,
                placeholder = { Text("Ask Lyo anything…", color = TextSecondary) },
                shape = RoundedCornerShape(24.dp),
                maxLines = 4,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = LyoPurple,
                    unfocusedBorderColor = BorderColor,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = LyoPurple,
                ),
                modifier = Modifier.weight(1f),
            )
            IconButton(
                onClick = { send(input) },
                enabled = !isStreaming && input.isNotBlank(),
                modifier = Modifier
                    .padding(start = 8.dp)
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(if (isStreaming) LyoPurple.copy(alpha = 0.4f) else LyoPurple),
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = Color.White,
                )
            }
        }
    }
}

@Composable
private fun MessageBubble(msg: ChatMsg, showTyping: Boolean) {
    val isUser = msg.role == "user"
    Row(
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
        modifier = Modifier.fillMaxWidth(),
    ) {
        val bubbleShape = RoundedCornerShape(
            topStart = 18.dp,
            topEnd = 18.dp,
            bottomStart = if (isUser) 18.dp else 4.dp,
            bottomEnd = if (isUser) 4.dp else 18.dp,
        )
        val bubbleModifier = Modifier
            .widthIn(max = 300.dp)
            .clip(bubbleShape)
            .let {
                if (isUser) it.background(LyoBrandGradient)
                else it
                    .background(Surface)
                    .border(1.dp, BorderColor, bubbleShape)
            }
            .padding(horizontal = 14.dp, vertical = 10.dp)

        Box(modifier = bubbleModifier) {
            if (showTyping) {
                val transition = rememberInfiniteTransition(label = "typing")
                val blinkAlpha by transition.animateFloat(
                    initialValue = 0.2f,
                    targetValue = 1f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(durationMillis = 500),
                        repeatMode = RepeatMode.Reverse,
                    ),
                    label = "typingAlpha",
                )
                Text(
                    text = "...",
                    style = MaterialTheme.typography.bodyLarge,
                    color = TextSecondary,
                    modifier = Modifier.alpha(blinkAlpha),
                )
            } else {
                Text(
                    text = msg.content,
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (isUser) Color.White else TextPrimary,
                )
            }
        }
    }
}
