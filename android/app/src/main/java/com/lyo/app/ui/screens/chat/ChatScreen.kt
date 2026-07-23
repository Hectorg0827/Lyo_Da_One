package com.lyo.app.ui.screens.chat

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ChatStreamClient
import com.lyo.app.data.api.ChatStreamEvent
import com.lyo.app.data.api.CreateAiConversationRequest
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

private const val MAX_CHAT_CHARS = 4_000
private const val MAX_CHAT_IMAGE_BYTES = 10 * 1024 * 1024
private val SupportedChatImageTypes = setOf(
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
)

private val ImageMarkdown = Regex("""!\[([^]]*)]\((https?://[^)]+)\)""")
private val FileMarkdown = Regex("""\[📎 ([^]]+)]\((https?://[^)]+)\)""")

data class ChatMsg(
    val role: String,
    val content: String,
    val id: String = UUID.randomUUID().toString(),
)

private data class PendingImageAttachment(
    val name: String,
    val url: String,
)

private data class LinkedAttachment(
    val name: String,
    val url: String,
    val isImage: Boolean,
)

private data class ParsedChatContent(
    val text: String,
    val attachment: LinkedAttachment?,
)

private val Suggestions = listOf(
    "Explain quantum computing",
    "Make me a study plan",
    "Help me learn Spanish",
    "Summarize photosynthesis",
)

@Composable
fun ChatScreen(nav: NavHostController) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val messages = remember { mutableStateListOf<ChatMsg>() }
    var input by remember { mutableStateOf("") }
    var isStreaming by remember { mutableStateOf(false) }
    var activeConversationId by remember { mutableStateOf<String?>(null) }
    var pendingAttachment by remember { mutableStateOf<PendingImageAttachment?>(null) }
    var uploadingAttachment by remember { mutableStateOf(false) }
    var dictating by remember { mutableStateOf(false) }
    var inputError by remember { mutableStateOf<String?>(null) }
    var textToSpeech by remember { mutableStateOf<TextToSpeech?>(null) }
    var textToSpeechReady by remember { mutableStateOf(false) }
    var speakingMessageId by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val mainHandler = remember { Handler(Looper.getMainLooper()) }

    DisposableEffect(context) {
        lateinit var engine: TextToSpeech
        engine = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val languageResult = engine.setLanguage(Locale.getDefault())
                textToSpeechReady = languageResult != TextToSpeech.LANG_MISSING_DATA &&
                    languageResult != TextToSpeech.LANG_NOT_SUPPORTED
            } else {
                textToSpeechReady = false
            }
        }
        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                mainHandler.post {
                    if (speakingMessageId == utteranceId) speakingMessageId = null
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    if (speakingMessageId == utteranceId) speakingMessageId = null
                }
            }
        })
        textToSpeech = engine

        onDispose {
            engine.stop()
            engine.shutdown()
            textToSpeech = null
            textToSpeechReady = false
            speakingMessageId = null
        }
    }

    val speechLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        dictating = false
        if (result.resultCode == Activity.RESULT_OK) {
            val transcript = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (transcript.isNotEmpty()) {
                input = listOf(input.trimEnd(), transcript)
                    .filter { it.isNotBlank() }
                    .joinToString(" ")
                    .take(MAX_CHAT_CHARS)
                inputError = null
            }
        }
    }

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent(),
    ) { uri ->
        if (uri == null || uploadingAttachment || isStreaming) return@rememberLauncherForActivityResult

        uploadingAttachment = true
        inputError = null
        scope.launch {
            runCatching {
                uploadChatImage(context, uri)
            }.onSuccess { attachment ->
                pendingAttachment = attachment
            }.onFailure { error ->
                inputError = error.message ?: "The image could not be uploaded."
            }
            uploadingAttachment = false
        }
    }

    fun send(raw: String) {
        val trimmed = raw.trim()
        val attachment = pendingAttachment
        if ((trimmed.isEmpty() && attachment == null) || isStreaming || uploadingAttachment) return

        val content = buildChatContent(trimmed, attachment)
        val clientMessageId = UUID.randomUUID().toString()
        messages.add(ChatMsg(role = "user", content = content, id = clientMessageId))
        messages.add(ChatMsg(role = "assistant", content = ""))
        input = ""
        pendingAttachment = null
        inputError = null
        isStreaming = true

        scope.launch {
            val conversationId = activeConversationId ?: runCatching {
                ApiClient.api.createAiConversation(
                    CreateAiConversationRequest(title = trimmed.ifBlank { attachment?.name.orEmpty() }.take(80)),
                ).id
            }.getOrElse {
                messages[messages.lastIndex] = messages.last().copy(
                    content = "I couldn't save this conversation. Please check your connection and try again.",
                )
                isStreaming = false
                return@launch
            }
            activeConversationId = conversationId

            runCatching {
                ChatStreamClient.stream(content, conversationId, clientMessageId).collect { event ->
                    when (event) {
                        is ChatStreamEvent.Chunk -> {
                            val last = messages.last()
                            messages[messages.lastIndex] = last.copy(content = last.content + event.text)
                        }

                        is ChatStreamEvent.Done -> Unit
                        is ChatStreamEvent.Conversation -> activeConversationId = event.id
                        is ChatStreamEvent.Error -> {
                            messages[messages.lastIndex] = messages.last().copy(
                                content = "The response was interrupted. Your conversation is saved—please try again.",
                            )
                        }
                    }
                }
            }.onFailure {
                messages[messages.lastIndex] = messages.last().copy(
                    content = "The response was interrupted. Your conversation is saved—please try again.",
                )
            }
            isStreaming = false
        }
    }

    fun startDictation() {
        if (isStreaming || uploadingAttachment || dictating) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak your message to Lyo")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        try {
            dictating = true
            inputError = null
            speechLauncher.launch(intent)
        } catch (_: ActivityNotFoundException) {
            dictating = false
            inputError = "Speech recognition is not available on this device."
        }
    }

    fun toggleSpeech(message: ChatMsg) {
        val engine = textToSpeech ?: return
        if (speakingMessageId == message.id) {
            engine.stop()
            speakingMessageId = null
            return
        }

        val parsed = parseChatContent(message.content)
        val spokenText = parsed.text.ifBlank {
            parsed.attachment?.let { "Image attachment: ${it.name}" }.orEmpty()
        }
        if (spokenText.isBlank()) return

        engine.stop()
        speakingMessageId = message.id
        engine.speak(
            spokenText,
            TextToSpeech.QUEUE_FLUSH,
            null,
            message.id,
        )
    }

    // Resume the most recent server conversation on any Android device.
    LaunchedEffect(Unit) {
        runCatching {
            val latest = ApiClient.api.aiConversations().conversations.firstOrNull() ?: return@runCatching
            val detail = ApiClient.api.aiConversation(latest.id)
            activeConversationId = detail.id
            messages.clear()
            messages.addAll(detail.messages.map { ChatMsg(it.role, it.content, it.id) })
        }
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(max(0, messages.size - 1))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
            .imePadding(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text("Lyo AI", style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            TextButton(
                enabled = !isStreaming && !uploadingAttachment,
                onClick = {
                    textToSpeech?.stop()
                    speakingMessageId = null
                    activeConversationId = null
                    pendingAttachment = null
                    inputError = null
                    messages.clear()
                },
            ) { Text("New chat", color = LyoPurple) }
        }

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
                items(messages, key = { it.id }) { msg ->
                    MessageBubble(
                        msg = msg,
                        showTyping = isStreaming &&
                            msg.id == messages.lastOrNull()?.id &&
                            msg.role == "assistant" &&
                            msg.content.isEmpty(),
                        canSpeak = textToSpeechReady && msg.role == "assistant" && msg.content.isNotBlank(),
                        speaking = speakingMessageId == msg.id,
                        onToggleSpeech = { toggleSpeech(msg) },
                    )
                }
            }
        }

        inputError?.let { error ->
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFFFF9A9A),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
            )
        }

        pendingAttachment?.let { attachment ->
            PendingAttachmentChip(
                attachment = attachment,
                onRemove = { pendingAttachment = null },
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface)
                .padding(horizontal = 8.dp, vertical = 8.dp),
        ) {
            IconButton(
                onClick = { imagePicker.launch("image/*") },
                enabled = !isStreaming && !uploadingAttachment,
                modifier = Modifier.size(44.dp),
            ) {
                if (uploadingAttachment) {
                    CircularProgressIndicator(
                        color = LyoPurple,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.AddPhotoAlternate,
                        contentDescription = "Attach image",
                        tint = TextSecondary,
                    )
                }
            }

            IconButton(
                onClick = ::startDictation,
                enabled = !isStreaming && !uploadingAttachment && !dictating,
                modifier = Modifier.size(44.dp),
            ) {
                if (dictating) {
                    CircularProgressIndicator(
                        color = LyoPurple,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Dictate message",
                        tint = TextSecondary,
                    )
                }
            }

            OutlinedTextField(
                value = input,
                onValueChange = { if (it.length <= MAX_CHAT_CHARS) input = it },
                enabled = !isStreaming,
                placeholder = {
                    Text(
                        when {
                            isStreaming -> "Lyo is thinking…"
                            dictating -> "Listening…"
                            else -> "Ask Lyo anything…"
                        },
                        color = TextSecondary,
                    )
                },
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
                enabled = !isStreaming &&
                    !uploadingAttachment &&
                    (input.isNotBlank() || pendingAttachment != null),
                modifier = Modifier
                    .padding(start = 6.dp)
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(
                        if (isStreaming || uploadingAttachment) LyoPurple.copy(alpha = 0.4f)
                        else LyoPurple,
                    ),
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
private fun PendingAttachmentChip(
    attachment: PendingImageAttachment,
    onRemove: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        AsyncImage(
            model = attachment.url,
            contentDescription = attachment.name,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp)),
        )
        Text(
            text = attachment.name,
            style = MaterialTheme.typography.bodySmall,
            color = TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onRemove, modifier = Modifier.size(36.dp)) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Remove image",
                tint = TextSecondary,
            )
        }
    }
}

@Composable
private fun MessageBubble(
    msg: ChatMsg,
    showTyping: Boolean,
    canSpeak: Boolean,
    speaking: Boolean,
    onToggleSpeech: () -> Unit,
) {
    val context = LocalContext.current
    val isUser = msg.role == "user"
    val parsed = remember(msg.content) { parseChatContent(msg.content) }

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
            .widthIn(max = 320.dp)
            .clip(bubbleShape)
            .let {
                if (isUser) it.background(LyoBrandGradient)
                else it
                    .background(Surface)
                    .border(1.dp, BorderColor, bubbleShape)
            }
            .padding(horizontal = 14.dp, vertical = 10.dp)

        Column(modifier = bubbleModifier) {
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
                parsed.attachment?.let { attachment ->
                    if (attachment.isImage) {
                        AsyncImage(
                            model = attachment.url,
                            contentDescription = attachment.name,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 120.dp, max = 240.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .clickable { openAttachment(context, attachment.url) },
                        )
                    } else {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(Color.White.copy(alpha = 0.08f))
                                .clickable { openAttachment(context, attachment.url) }
                                .padding(10.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Default.InsertDriveFile,
                                contentDescription = null,
                                tint = if (isUser) Color.White else LyoPurple,
                            )
                            Text(
                                text = attachment.name,
                                style = MaterialTheme.typography.bodySmall,
                                color = if (isUser) Color.White else TextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }

                if (parsed.text.isNotBlank()) {
                    Text(
                        text = parsed.text,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (isUser) Color.White else TextPrimary,
                        modifier = Modifier.padding(top = if (parsed.attachment != null) 8.dp else 0.dp),
                    )
                }

                if (canSpeak) {
                    IconButton(
                        onClick = onToggleSpeech,
                        modifier = Modifier
                            .align(Alignment.End)
                            .padding(top = 4.dp)
                            .size(32.dp),
                    ) {
                        Icon(
                            imageVector = if (speaking) Icons.Default.Stop else Icons.Default.VolumeUp,
                            contentDescription = if (speaking) "Stop reading" else "Read response aloud",
                            tint = LyoPurple,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
    }
}

private suspend fun uploadChatImage(
    context: Context,
    uri: Uri,
): PendingImageAttachment {
    val resolver = context.contentResolver
    val contentType = resolver.getType(uri)?.lowercase()
        ?: throw IllegalArgumentException("The selected image type could not be identified.")
    if (contentType !in SupportedChatImageTypes) {
        throw IllegalArgumentException("Choose a JPEG, PNG, WebP, or HEIC image.")
    }

    val displayName = attachmentDisplayName(context, uri)
    val bytes = withContext(Dispatchers.IO) {
        resolver.openInputStream(uri)?.use { stream ->
            val data = stream.readBytes()
            if (data.size > MAX_CHAT_IMAGE_BYTES) {
                throw IllegalArgumentException("Image too large. Maximum size is 10MB.")
            }
            data
        }
    } ?: throw IllegalStateException("The selected image could not be read.")

    val file = MultipartBody.Part.createFormData(
        "file",
        displayName,
        bytes.toRequestBody(contentType.toMediaType()),
    )
    val uploaded = ApiClient.api.uploadMedia(
        file = file,
        folder = "chat".toRequestBody("text/plain".toMediaType()),
    )
    val url = uploaded.url
        ?: throw IllegalStateException("The media service did not return an image URL.")
    return PendingImageAttachment(displayName, url)
}

private fun attachmentDisplayName(context: Context, uri: Uri): String {
    val resolver = context.contentResolver
    val queriedName = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    return queriedName
        ?.takeIf { it.isNotBlank() }
        ?.replace("[", "")
        ?.replace("]", "")
        ?.replace("(", "")
        ?.replace(")", "")
        ?: "chat-image.jpg"
}

private fun buildChatContent(
    text: String,
    attachment: PendingImageAttachment?,
): String {
    if (attachment == null) return text
    val markdown = "![${attachment.name}](${attachment.url})"
    return if (text.isBlank()) markdown else "$text\n\n$markdown"
}

private fun parseChatContent(content: String): ParsedChatContent {
    val imageMatch = ImageMarkdown.find(content)
    if (imageMatch != null) {
        return ParsedChatContent(
            text = content.replace(imageMatch.value, "").trim(),
            attachment = LinkedAttachment(
                name = imageMatch.groupValues[1].ifBlank { "Image" },
                url = imageMatch.groupValues[2],
                isImage = true,
            ),
        )
    }

    val fileMatch = FileMarkdown.find(content)
    if (fileMatch != null) {
        return ParsedChatContent(
            text = content.replace(fileMatch.value, "").trim(),
            attachment = LinkedAttachment(
                name = fileMatch.groupValues[1],
                url = fileMatch.groupValues[2],
                isImage = false,
            ),
        )
    }

    return ParsedChatContent(text = content, attachment = null)
}

private fun openAttachment(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}