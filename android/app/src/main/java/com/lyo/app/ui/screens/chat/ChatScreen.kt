package com.lyo.app.ui.screens.chat

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Menu
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.R
import com.lyo.app.data.Session
import com.lyo.app.data.api.AiConversationMessageDto
import com.lyo.app.data.api.AiConversationSummaryDto
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ChatStreamClient
import com.lyo.app.data.api.ChatStreamEvent
import com.lyo.app.data.api.ChatMediaRef
import com.lyo.app.data.api.CheckAnswerRequest
import com.lyo.app.data.api.CheckAnswerResult
import com.lyo.app.data.api.CreateAiConversationRequest
import com.lyo.app.data.api.SmartBlock
import com.lyo.app.data.api.VisualUpdateRequest
import com.google.gson.JsonElement
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.components.SmartBlockList
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

private const val MAX_CHAT_CHARS = 4_000
private const val MAX_CHAT_ATTACHMENT_BYTES = 10L * 1024 * 1024
private const val MAX_CHAT_ATTACHMENT_TOTAL_BYTES = 20L * 1024 * 1024
private const val MAX_CHAT_ATTACHMENTS = 4
private const val ASSISTANT_RESPONSE_WIDTH_FRACTION = 0.99f
private val SupportedChatAttachmentTypes = setOf(
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "application/pdf",
    "text/plain",
    "text/markdown",
    "text/csv",
    "application/json",
)

private val ImageMarkdown = Regex(
    """!\[([^]]*)]\((https?://[^)]*/api/v1/media/file/chat/[^)]+)\)""",
)
private val FileMarkdown = Regex(
    """\[📎 ([^]]+)]\((https?://[^)]*/api/v1/media/file/chat/[^)]+)\)""",
)

data class ChatMsg(
    val role: String,
    val content: String,
    val id: String = UUID.randomUUID().toString(),
    /** Structured lesson blocks, when the turn carried them. */
    val blocks: List<SmartBlock>? = null,
    /** Server-graded verdicts for this message's answered checks, keyed by block id. */
    val checkResults: Map<String, CheckAnswerResult> = emptyMap(),
)

/**
 * Restores a reloaded conversation's structured blocks *and* any checks
 * already answered in a previous session — the server persists the verdict
 * onto `block.metadata.result` when a check is graded (see /chat/check),
 * so without reading it back a reloaded check would re-offer itself as
 * unanswered. Mirrors web's extractCheckResults (chat-store.ts).
 */
private fun AiConversationMessageDto.toChatMsg(): ChatMsg {
    val checkResults = blocks.orEmpty().mapNotNull { block ->
        val resultJson = block.metadata?.get("result") ?: return@mapNotNull null
        runCatching { ApiClient.gson.fromJson(resultJson, CheckAnswerResult::class.java) }
            .getOrNull()
            ?.let { block.id to it }
    }.toMap()
    return ChatMsg(role = role, content = content, id = id, blocks = blocks, checkResults = checkResults)
}

private data class PendingChatAttachment(
    val name: String,
    val url: String,
    val mimeType: String,
    val size: Long,
    val isImage: Boolean,
)

private data class LinkedAttachment(
    val name: String,
    val url: String,
    val isImage: Boolean,
)

private data class ParsedChatContent(
    val text: String,
    val attachments: List<LinkedAttachment>,
)

private val Suggestions = listOf(
    "Teach me something new",
    "Create a course for me",
    "Quiz me on a topic",
    "Help me study for an exam",
)

@Composable
fun ChatScreen(nav: NavHostController) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val messages = remember { mutableStateListOf<ChatMsg>() }
    val conversations = remember { mutableStateListOf<AiConversationSummaryDto>() }
    var showHistory by remember { mutableStateOf(false) }
    val mascotEntrance = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        mascotEntrance.animateTo(
            targetValue = 1f,
            animationSpec = tween(durationMillis = 760, easing = FastOutSlowInEasing),
        )
    }
    BackHandler(enabled = showHistory) { showHistory = false }
    var historyError by remember { mutableStateOf<String?>(null) }
    var input by remember { mutableStateOf("") }
    var isStreaming by remember { mutableStateOf(false) }
    var activeConversationId by remember { mutableStateOf<String?>(null) }
    val pendingAttachments = remember { mutableStateListOf<PendingChatAttachment>() }
    var uploadingAttachment by remember { mutableStateOf(false) }
    var dictating by remember { mutableStateOf(false) }
    var recognizerInFlight by remember { mutableStateOf(false) }
    var inputError by remember { mutableStateOf<String?>(null) }
    var textToSpeech by remember { mutableStateOf<TextToSpeech?>(null) }
    var textToSpeechReady by remember { mutableStateOf(false) }
    var speakingMessageId by remember { mutableStateOf<String?>(null) }
    var voiceConversation by remember { mutableStateOf(false) }
    var voiceInterruptedPreviousTurn by remember { mutableStateOf(false) }
    var liveVoiceTranscript by remember { mutableStateOf("") }
    var voiceLanguageTag by remember { mutableStateOf(Locale.getDefault().toLanguageTag()) }
    var enableAutomaticLanguageSwitch by remember { mutableStateOf(Build.VERSION.SDK_INT >= 34) }
    var spokenVoiceCaption by remember { mutableStateOf("") }
    var voiceThinkingNudge by remember { mutableStateOf("") }
    val spokenRanges = remember { mutableMapOf<String, Pair<String, String>>() }
    var bargeInCandidate by remember { mutableStateOf("") }
    var bargeInConfirmations by remember { mutableStateOf(0) }
    var lastSpokenVoiceText by remember { mutableStateOf("") }
    var lastThinkingNudgeText by remember { mutableStateOf("") }
    var voiceListenNonce by remember { mutableStateOf(0) }
    var voiceSegmentStreamOpen by remember { mutableStateOf(false) }
    var pendingVoiceUtterances by remember { mutableStateOf(0) }
    val streamedVoiceSegmentKeys = remember { mutableSetOf<String>() }
    var continuousRecognizer by remember { mutableStateOf<SpeechRecognizer?>(null) }
    var streamJob by remember { mutableStateOf<Job?>(null) }
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
            override fun onStart(utteranceId: String?) {
                mainHandler.post {
                    if (voiceConversation && utteranceId != null) {
                        spokenRanges[utteranceId]?.let { (prefix, _) -> spokenVoiceCaption = prefix }
                    }
                }
            }

            override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                mainHandler.post {
                    if (voiceConversation && utteranceId != null) {
                        spokenRanges[utteranceId]?.let { (prefix, segment) ->
                            spokenVoiceCaption = (prefix + " " + segment.take(end.coerceIn(0, segment.length))).trim()
                        }
                    }
                }
            }

            override fun onDone(utteranceId: String?) {
                mainHandler.post {
                    if (utteranceId != null) spokenRanges.remove(utteranceId)?.let { (prefix, segment) ->
                        spokenVoiceCaption = (prefix + " " + segment).trim()
                    }
                    if (utteranceId?.startsWith("voice-segment:") == true) {
                        pendingVoiceUtterances = (pendingVoiceUtterances - 1).coerceAtLeast(0)
                    }
                    if (speakingMessageId == utteranceId) speakingMessageId = null
                    if (
                        voiceConversation &&
                        !voiceSegmentStreamOpen &&
                        pendingVoiceUtterances == 0
                    ) {
                        voiceListenNonce += 1
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    if (utteranceId?.startsWith("voice-segment:") == true) {
                        pendingVoiceUtterances = (pendingVoiceUtterances - 1).coerceAtLeast(0)
                    }
                    if (speakingMessageId == utteranceId) speakingMessageId = null
                    if (
                        voiceConversation &&
                        !voiceSegmentStreamOpen &&
                        pendingVoiceUtterances == 0
                    ) {
                        voiceListenNonce += 1
                    }
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
            continuousRecognizer?.destroy()
            continuousRecognizer = null
            streamJob?.cancel()
            streamJob = null
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

    val voicePermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            voiceConversation = true
            voiceListenNonce += 1
            inputError = null
        } else {
            voiceConversation = false
            inputError = "Microphone permission is required for live voice."
        }
    }

    val attachmentPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris ->
        if (uris.isEmpty() || uploadingAttachment || isStreaming) {
            return@rememberLauncherForActivityResult
        }
        val remaining = MAX_CHAT_ATTACHMENTS - pendingAttachments.size
        if (remaining <= 0) {
            inputError = "You can attach up to four files."
            return@rememberLauncherForActivityResult
        }
        if (uris.size > remaining) {
            inputError = "Only $remaining more attachment${if (remaining == 1) "" else "s"} can be added."
        } else {
            inputError = null
        }

        uploadingAttachment = true
        scope.launch {
            var totalBytes = pendingAttachments.sumOf { it.size }
            for (uri in uris.take(remaining)) {
                try {
                    val attachment = uploadChatAttachment(
                        context = context,
                        uri = uri,
                        remainingTotalBytes = MAX_CHAT_ATTACHMENT_TOTAL_BYTES - totalBytes,
                    )
                    pendingAttachments.add(attachment)
                    totalBytes += attachment.size
                } catch (error: Exception) {
                    inputError = error.message ?: "The attachment could not be uploaded."
                }
            }
            uploadingAttachment = false
        }
    }

    fun send(raw: String) {
        val trimmed = raw.trim()
        val attachments = pendingAttachments.toList()
        if ((trimmed.isEmpty() && attachments.isEmpty()) || isStreaming || uploadingAttachment) return

        val content = buildChatContent(trimmed, attachments)
        if (voiceConversation && textToSpeechReady) {
            val requestedLocale = Locale.forLanguageTag(voiceLanguageTag)
            val availability = textToSpeech?.isLanguageAvailable(requestedLocale)
            if (availability != TextToSpeech.LANG_MISSING_DATA &&
                availability != TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                textToSpeech?.language = requestedLocale
            }
        }
        val clientMessageId = UUID.randomUUID().toString()
        val interruptedPreviousTurn = voiceInterruptedPreviousTurn
        voiceInterruptedPreviousTurn = false
        messages.add(ChatMsg(role = "user", content = content, id = clientMessageId))
        messages.add(ChatMsg(role = "assistant", content = ""))
        input = ""
        pendingAttachments.clear()
        inputError = null
        isStreaming = true
        streamedVoiceSegmentKeys.clear()
        voiceSegmentStreamOpen = false
        pendingVoiceUtterances = 0
        // Echo suppression must compare only against the assistant reply for
        // this turn, never the accumulated speech from earlier turns.
        lastSpokenVoiceText = ""
        lastThinkingNudgeText = ""
        spokenVoiceCaption = ""
        voiceThinkingNudge = ""
        spokenRanges.clear()

        streamJob?.cancel()
        streamJob = scope.launch {
            var responseCompleted = false
            val conversationId = activeConversationId ?: runCatching {
                ApiClient.api.createAiConversation(
                    CreateAiConversationRequest(
                        title = trimmed.ifBlank { attachments.firstOrNull()?.name.orEmpty() }.take(80),
                    ),
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
                ChatStreamClient.stream(
                    text = trimmed,
                    conversationId = conversationId,
                    clientMessageId = clientMessageId,
                    media = attachments.map { attachment ->
                        ChatMediaRef(
                            modality = if (attachment.isImage) "IMAGE" else "DOCUMENT",
                            uri = attachment.url,
                            mimeType = attachment.mimeType,
                            name = attachment.name,
                            sizeBytes = attachment.size,
                        )
                    },
                    voiceSession = voiceConversation,
                    voiceInterruptedPreviousTurn = interruptedPreviousTurn,
                    voiceTurnId = clientMessageId,
                    voiceLocale = voiceLanguageTag,
                ).collect { event ->
                    when (event) {
                        is ChatStreamEvent.Chunk -> {
                            val last = messages.last()
                            messages[messages.lastIndex] = last.copy(content = last.content + event.text)
                        }

                        is ChatStreamEvent.FinalAnswer -> {
                            val last = messages.last()
                            messages[messages.lastIndex] = last.copy(content = event.text)
                        }

                        is ChatStreamEvent.SmartBlocks -> {
                            // Structured lesson content — every beat, not just
                            // plain prose. Previously unhandled, so lessons
                            // rendered as whatever plain text also came through.
                            val last = messages.last()
                            messages[messages.lastIndex] = last.copy(blocks = event.blocks)
                        }

                        is ChatStreamEvent.VoiceSegment -> {
                            if (voiceConversation && event.text.isNotBlank()) {
                                val key = "${event.messageId}:${event.sequence}"
                                voiceSegmentStreamOpen = true
                                if (
                                    textToSpeechReady &&
                                    !streamedVoiceSegmentKeys.contains(key)
                                ) {
                                    val utteranceId =
                                        "voice-segment:${event.messageId}:${event.sequence}"
                                    pendingVoiceUtterances += 1
                                    spokenRanges[utteranceId] = lastSpokenVoiceText to event.text
                                    val accepted = textToSpeech?.speak(
                                        event.text,
                                        if (pendingVoiceUtterances == 1) {
                                            TextToSpeech.QUEUE_FLUSH
                                        } else {
                                            TextToSpeech.QUEUE_ADD
                                        },
                                        null,
                                        utteranceId,
                                    ) == TextToSpeech.SUCCESS
                                    if (accepted) {
                                        streamedVoiceSegmentKeys.add(key)
                                        lastSpokenVoiceText = listOf(
                                            lastSpokenVoiceText,
                                            event.text,
                                        ).filter { it.isNotBlank() }.joinToString(" ")
                                        speakingMessageId = utteranceId
                                    } else {
                                        spokenRanges.remove(utteranceId)
                                        pendingVoiceUtterances =
                                            (pendingVoiceUtterances - 1).coerceAtLeast(0)
                                    }
                                }
                            }
                        }

                        is ChatStreamEvent.VoiceReady -> {
                            val hadSegments = streamedVoiceSegmentKeys.any {
                                it.startsWith("${event.messageId}:")
                            }
                            voiceSegmentStreamOpen = false
                            if (
                                voiceConversation &&
                                event.speak &&
                                !hadSegments &&
                                event.text.isNotBlank() &&
                                textToSpeechReady
                            ) {
                                val utteranceId = event.messageId
                                lastSpokenVoiceText = event.text
                                spokenRanges[utteranceId] = "" to event.text
                                speakingMessageId = utteranceId
                                textToSpeech?.speak(
                                    event.text,
                                    TextToSpeech.QUEUE_FLUSH,
                                    null,
                                    utteranceId,
                                )
                            } else if (
                                voiceConversation &&
                                pendingVoiceUtterances == 0 &&
                                speakingMessageId == null
                            ) {
                                voiceListenNonce += 1
                            }
                        }

                        is ChatStreamEvent.VoiceIncomplete -> {
                            voiceSegmentStreamOpen = false
                            if (
                                voiceConversation &&
                                pendingVoiceUtterances == 0 &&
                                speakingMessageId == null
                            ) {
                                voiceListenNonce += 1
                            }
                        }

                        is ChatStreamEvent.Done -> responseCompleted = true
                        is ChatStreamEvent.Conversation -> activeConversationId = event.id
                        is ChatStreamEvent.Error -> {
                            messages[messages.lastIndex] = messages.last().copy(
                                content = "The response was interrupted. Your conversation is saved—please try again.",
                            )
                        }
                    }
                }
            }.onFailure { error ->
                if (error !is CancellationException || !voiceConversation) {
                    messages[messages.lastIndex] = messages.last().copy(
                        content = "The response was interrupted. Your conversation is saved—please try again.",
                    )
                }
            }
            isStreaming = false
            streamJob = null

            if (voiceConversation && responseCompleted) {
                val assistant = messages.lastOrNull { it.role == "assistant" && it.content.isNotBlank() }
                val spokenText = assistant?.let { parseChatContent(it.content).text }?.trim().orEmpty()
                val engine = textToSpeech
                val streamedSegments = streamedVoiceSegmentKeys.isNotEmpty()
                if (
                    !streamedSegments &&
                    assistant != null &&
                    spokenText.isNotBlank() &&
                    textToSpeechReady &&
                    engine != null
                ) {
                    engine.stop()
                    lastSpokenVoiceText = spokenText
                    spokenRanges[assistant.id] = "" to spokenText
                    speakingMessageId = assistant.id
                    engine.speak(spokenText, TextToSpeech.QUEUE_FLUSH, null, assistant.id)
                } else if (
                    !voiceSegmentStreamOpen &&
                    pendingVoiceUtterances == 0 &&
                    speakingMessageId == null
                ) {
                    voiceListenNonce += 1
                }
            } else if (voiceConversation) {
                // Barge-in cancellation or an interrupted transport should
                // return control to the microphone, never speak the old turn.
                voiceListenNonce += 1
            }
        }
    }


    fun stopVoiceConversation() {
        voiceConversation = false
        dictating = false
        recognizerInFlight = false
        liveVoiceTranscript = ""
        voiceThinkingNudge = ""
        spokenRanges.clear()
        bargeInCandidate = ""
        bargeInConfirmations = 0
        runCatching { continuousRecognizer?.cancel() }
        textToSpeech?.stop()
        speakingMessageId = null
        voiceSegmentStreamOpen = false
        pendingVoiceUtterances = 0
        streamedVoiceSegmentKeys.clear()
    }

    fun startVoiceRecognition() {
        if (!voiceConversation || recognizerInFlight) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            voicePermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            return
        }
        val recognizer = continuousRecognizer ?: return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, voiceLanguageTag)
            // Android 14+ can detect and switch between English and Spanish.
            // Some recognition services ignore this optional hint.
            if (Build.VERSION.SDK_INT >= 34 && enableAutomaticLanguageSwitch) {
                putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH, RecognizerIntent.LANGUAGE_SWITCH_BALANCED)
                putStringArrayListExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES,
                    arrayListOf("en-US", "es-ES", "es-US"),
                )
            }
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Favor natural conversational turn-taking: complete phrases end
            // quickly, while a short hesitation does not immediately submit.
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 800L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 250L)
        }
        liveVoiceTranscript = ""
        runCatching {
            recognizerInFlight = true
            recognizer.startListening(intent)
            dictating = true
        }.onFailure {
            recognizerInFlight = false
            dictating = false
            inputError = "Speech recognition is not available on this device."
        }
    }

    DisposableEffect(context) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            inputError = "Live speech recognition is not available on this device."
            onDispose { }
        } else {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    dictating = true
                    liveVoiceTranscript = ""
                }

                override fun onBeginningOfSpeech() {
                    // A single speech-start can be the speaker's echo.
                    // Only confirmed, non-echo words may interrupt Lyo.
                    bargeInCandidate = ""
                    bargeInConfirmations = 0
                }

                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() { dictating = false }

                override fun onError(error: Int) {
                    recognizerInFlight = false
                    dictating = false
                    if (Build.VERSION.SDK_INT >= 34 && (
                        error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
                            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
                    )) {
                        // Model pack missing: recover in the selected device
                        // locale without looping through an unsupported mode.
                        enableAutomaticLanguageSwitch = false
                    }
                    if (voiceConversation) {
                        mainHandler.postDelayed({ voiceListenNonce += 1 }, 250)
                    }
                }

                override fun onResults(results: Bundle?) {
                    recognizerInFlight = false
                    dictating = false
                    val transcript = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        .orEmpty()
                    val wasSpeaking = speakingMessageId != null || pendingVoiceUtterances > 0
                    val accepted = voiceConversation &&
                        !VoiceTurnSafety.isLikelyEcho(transcript, lastThinkingNudgeText) &&
                        VoiceTurnSafety.shouldSubmitFinal(
                        heard = transcript,
                        assistantText = lastSpokenVoiceText,
                        assistantAudible = wasSpeaking,
                        confirmedDuringPlayback = bargeInConfirmations >= 2,
                    )
                    liveVoiceTranscript = if (accepted) transcript else ""
                    bargeInCandidate = ""
                    bargeInConfirmations = 0

                    if (accepted) {
                        if (speakingMessageId != null || isStreaming) {
                            voiceInterruptedPreviousTurn = true
                        }
                        textToSpeech?.stop()
                        speakingMessageId = null
                        if (isStreaming) {
                            streamJob?.cancel()
                            streamJob = null
                            isStreaming = false
                        }
                        send(transcript)
                    }
                    if (voiceConversation) voiceListenNonce += 1
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        .orEmpty()
                    if (!voiceConversation || partial.isBlank() ||
                        VoiceTurnSafety.isLikelyEcho(partial, lastSpokenVoiceText) ||
                        VoiceTurnSafety.isLikelyEcho(partial, lastThinkingNudgeText)
                    ) {
                        return
                    }
                    liveVoiceTranscript = partial
                    val speaking = speakingMessageId != null || pendingVoiceUtterances > 0
                    if (speaking) {
                        bargeInConfirmations = VoiceTurnSafety.confirmationCount(
                            bargeInCandidate, bargeInConfirmations, partial
                        )
                        bargeInCandidate = partial
                        if (bargeInConfirmations < 2) return
                    }
                    if (speaking || isStreaming) {
                        voiceInterruptedPreviousTurn = true
                        textToSpeech?.stop()
                        speakingMessageId = null
                        pendingVoiceUtterances = 0
                        voiceSegmentStreamOpen = false
                        spokenRanges.clear()
                        if (isStreaming) {
                            streamJob?.cancel()
                            streamJob = null
                            isStreaming = false
                        }
                    }
                }

                override fun onLanguageDetection(results: Bundle) {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val detected = results.getString(SpeechRecognizer.DETECTED_LANGUAGE)
                        if (detected?.startsWith("en", ignoreCase = true) == true ||
                            detected?.startsWith("es", ignoreCase = true) == true
                        ) {
                            voiceLanguageTag = detected
                        }
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) = Unit
            })
            continuousRecognizer = recognizer
            onDispose {
                recognizer.cancel()
                recognizer.destroy()
                if (continuousRecognizer === recognizer) continuousRecognizer = null
            }
        }
    }

    LaunchedEffect(voiceConversation, isStreaming, speakingMessageId, pendingVoiceUtterances) {
        voiceThinkingNudge = ""
        if (voiceConversation && isStreaming && speakingMessageId == null && pendingVoiceUtterances == 0) {
            delay(2400)
            if (voiceConversation && isStreaming && speakingMessageId == null &&
                pendingVoiceUtterances == 0 && !voiceSegmentStreamOpen
            ) {
                voiceThinkingNudge = if (voiceLanguageTag.startsWith("es"))
                    "Mmm, déjame ver…" else "Hmm, let me see…"
                lastThinkingNudgeText = voiceThinkingNudge
                // Only the first gentle nudge speaks. Later wait messages are
                // visual, so Lyo does not chatter or obscure a user interruption.
                if (textToSpeechReady) {
                    textToSpeech?.speak(
                        voiceThinkingNudge, TextToSpeech.QUEUE_FLUSH,
                        null, "voice-thinking-nudge",
                    )
                }
            }
            delay(4200)
            if (voiceConversation && isStreaming && speakingMessageId == null && pendingVoiceUtterances == 0) {
                voiceThinkingNudge = if (voiceLanguageTag.startsWith("es"))
                    "Sigo revisando…" else "Still checking…"
            }
        }
    }

    LaunchedEffect(voiceConversation, voiceListenNonce, isStreaming, speakingMessageId) {
        if (voiceConversation && !recognizerInFlight) {
            delay(180)
            startVoiceRecognition()
        }
    }

    /**
     * Grade an in-chat check against the block the server itself emitted.
     *
     * Sends only which option was picked. Correctness comes back from the
     * server — this must never be inferred locally from
     * `QuizBlockPayload.correctIndex`, which is the exact bug this endpoint
     * exists to remove (chat praising a wrong answer). Mirrors web's
     * answerCheck / iOS's UnifiedChatService.answerCheck.
     */
    fun answerCheck(messageId: String, blockId: String, selectedIndex: Int) {
        val conversationId = activeConversationId ?: return
        scope.launch {
            runCatching {
                ApiClient.api.checkChatAnswer(
                    CheckAnswerRequest(
                        conversationId = conversationId,
                        blockId = blockId,
                        selectedIndex = selectedIndex,
                    ),
                )
            }.onSuccess { result ->
                val index = messages.indexOfFirst { it.id == messageId }
                if (index >= 0) {
                    val current = messages[index]
                    messages[index] = current.copy(checkResults = current.checkResults + (blockId to result))
                }
            }
            // No onFailure handler: best-effort, same as web/iOS. A failed
            // grade leaves the check pending rather than faking a verdict —
            // the option stays tappable so the learner can try again.
        }
    }

    fun updateVisual(messageId: String, blockId: String, values: Map<String, JsonElement>) {
        val conversationId = activeConversationId ?: return
        com.lyo.app.data.api.ChatVisualSaves.queue.enqueue(
            VisualUpdateRequest(conversationId, blockId, values),
            onSaved = { block ->
                if (activeConversationId == conversationId) {
                    val index = messages.indexOfFirst { it.id == messageId }
                    if (index >= 0) {
                        val current = messages[index]
                        messages[index] = current.copy(blocks = current.blocks?.map {
                            if (it.id == blockId) block else it
                        })
                    }
                    if (inputError == "Could not save this diagram change. Adjust it again to retry.") inputError = null
                }
            },
            onFailure = {
                if (activeConversationId == conversationId) {
                    inputError = "Could not save this diagram change. Adjust it again to retry."
                }
            },
        )
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
            parsed.attachments.joinToString(", ") { "Attachment: ${it.name}" }
        }
        if (spokenText.isBlank()) return

        engine.stop()
        lastSpokenVoiceText = spokenText
        speakingMessageId = message.id
        engine.speak(
            spokenText,
            TextToSpeech.QUEUE_FLUSH,
            null,
            message.id,
        )
    }

    // The web Create studio seeds an actual new chat turn to generate a course.
    // The normal Android entry still restores the last server conversation.
    LaunchedEffect(Unit) {
        val seededPrompt = nav.previousBackStackEntry?.savedStateHandle
            ?.remove<String>("lyo_chat_seed_prompt")
        if (!seededPrompt.isNullOrBlank()) {
            activeConversationId = null
            messages.clear()
            send(seededPrompt)
        } else {
            runCatching {
                val latest = ApiClient.api.aiConversations().conversations.firstOrNull() ?: return@runCatching
                val detail = ApiClient.api.aiConversation(latest.id)
                activeConversationId = detail.id
                messages.clear()
                messages.addAll(detail.messages.map { it.toChatMsg() })
            }
        }
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(max(0, messages.size - 1))
    }

    LaunchedEffect(showHistory) {
        if (showHistory) {
            historyError = null
            runCatching { ApiClient.api.aiConversations().conversations }
                .onSuccess { loaded ->
                    conversations.clear()
                    conversations.addAll(loaded)
                }
                .onFailure { historyError = "Could not load your conversations. Please try again." }
        }
    }

    fun newChat() {
        textToSpeech?.stop()
        speakingMessageId = null
        streamJob?.cancel()
        streamJob = null
        activeConversationId = null
        pendingAttachments.clear()
        inputError = null
        messages.clear()
        showHistory = false
    }

    if (voiceConversation) {
        LiveVoiceConversationScreen(
            listening = dictating && !isStreaming && speakingMessageId == null && pendingVoiceUtterances == 0,
            thinking = isStreaming && speakingMessageId == null && pendingVoiceUtterances == 0,
            speaking = speakingMessageId != null || pendingVoiceUtterances > 0,
            userCaption = liveVoiceTranscript,
            assistantCaption = spokenVoiceCaption,
            thinkingNudge = voiceThinkingNudge,
            messages = messages,
            error = inputError,
            onEnd = ::stopVoiceConversation,
        )
    } else {
    Box(modifier = Modifier.fillMaxSize()) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Transparent)
            .imePadding(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0x550C0C17))
                .border(0.5.dp, Color.White.copy(alpha = 0.06f))
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            IconButton(
                onClick = { showHistory = true },
                enabled = !isStreaming,
                modifier = Modifier.size(40.dp),
            ) {
                Icon(Icons.Default.Menu, contentDescription = "Open conversation history", tint = TextSecondary)
            }
            Image(
                painter = painterResource(R.drawable.mascot_standing),
                contentDescription = null,
                modifier = Modifier.padding(start = 6.dp).size(30.dp),
            )
            Text(
                "Lyo", style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold, color = TextPrimary,
                modifier = Modifier.padding(start = 6.dp),
            )
            Text(
                "● online", style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF86EFAC), modifier = Modifier.padding(start = 8.dp).weight(1f),
            )
            IconButton(
                onClick = ::newChat,
                enabled = !isStreaming && !uploadingAttachment,
                modifier = Modifier.size(40.dp),
            ) {
                Icon(Icons.Default.Add, contentDescription = "New chat", tint = TextPrimary)
            }
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
                    text = "Hello, ${Session.user?.displayName?.substringBefore(" ")?.takeIf { it.isNotBlank() } ?: "there"}!",
                    style = TextStyle(
                        brush = Brush.horizontalGradient(
                            listOf(Color(0xFFFFC46A), Color(0xFFFF8956), Color(0xFFED80D4)),
                        ),
                        fontWeight = FontWeight.Bold,
                        fontSize = 28.sp,
                    ),
                )
                Text(
                    text = "Ready to embark on a learning journey?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextPrimary.copy(alpha = 0.82f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp, bottom = 12.dp),
                )
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.graphicsLayer {
                        // The bottom-tab mascot rises into its full-size greeting,
                        // following the mobile-web Chat entrance motion.
                        translationY = (1f - mascotEntrance.value) * 390.dp.toPx()
                        scaleX = 0.42f + mascotEntrance.value * 0.58f
                        scaleY = 0.42f + mascotEntrance.value * 0.58f
                        alpha = 0.45f + mascotEntrance.value * 0.55f
                    },
                ) {
                    Box(
                        modifier = Modifier.size(180.dp).background(
                            Brush.radialGradient(
                                listOf(Color(0x667C3AED), Color(0x33FF8C00), Color.Transparent),
                            ),
                            CircleShape,
                        ),
                    )
                    Image(
                        painter = painterResource(R.drawable.mascot_standing),
                        contentDescription = "Lyo is ready to help you learn",
                        modifier = Modifier.size(160.dp),
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(top = 8.dp, bottom = 8.dp),
                ) {
                    Suggestions.forEach { suggestion ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(Color.White.copy(alpha = 0.08f))
                                .border(1.dp, Color.White.copy(alpha = 0.13f), RoundedCornerShape(20.dp))
                                .clickable(enabled = !isStreaming) { send(suggestion) }
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                        ) {
                            Text(
                                text = suggestion,
                                style = MaterialTheme.typography.bodySmall,
                                color = TextPrimary,
                            )
                        }
                    }
                }
            }
        } else {
            LazyColumn(
                state = listState,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 16.dp),
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
                            msg.content.isEmpty() &&
                            msg.blocks.isNullOrEmpty(),
                        canSpeak = textToSpeechReady && msg.role == "assistant" && msg.content.isNotBlank(),
                        speaking = speakingMessageId == msg.id,
                        onAnswerCheck = { blockId, index -> answerCheck(msg.id, blockId, index) },
                        onVisualUpdate = { blockId, values -> updateVisual(msg.id, blockId, values) },
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

        pendingAttachments.forEach { attachment ->
            PendingAttachmentChip(
                attachment = attachment,
                onRemove = { pendingAttachments.remove(attachment) },
            )
        }

        if (voiceConversation) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(LyoPurple.copy(alpha = 0.10f))
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Icon(Icons.Default.Mic, contentDescription = null, tint = LyoPurple)
                Text(
                    text = when {
                        speakingMessageId != null -> "Lyo is speaking — start talking to interrupt"
                        isStreaming -> "Lyo is thinking…"
                        liveVoiceTranscript.isNotBlank() -> liveVoiceTranscript
                        else -> "Listening…"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = ::stopVoiceConversation) {
                    Text("End", color = LyoPurple)
                }
            }
        }

        // The mobile-web input island: text above a compact row of controls.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(Color(0xF210111C))
                .border(
                    1.dp,
                    Brush.horizontalGradient(
                        listOf(Color(0x884C62DB), Color(0x998B5CF6), Color(0x779D4EDD)),
                    ),
                    RoundedCornerShape(24.dp),
                )
                .padding(horizontal = 14.dp, vertical = 12.dp),
        ) {
            BasicTextField(
                value = input,
                onValueChange = { if (it.length <= MAX_CHAT_CHARS) input = it },
                enabled = !isStreaming,
                textStyle = TextStyle(color = TextPrimary, fontSize = 16.sp, lineHeight = 23.sp),
                cursorBrush = SolidColor(LyoPurple),
                maxLines = 4,
                modifier = Modifier.fillMaxWidth().heightIn(min = 28.dp, max = 120.dp),
                decorationBox = { innerTextField ->
                    Box(modifier = Modifier.padding(vertical = 3.dp)) {
                        if (input.isEmpty()) {
                            Text(
                                when {
                                    isStreaming -> "Lyo is thinking…"
                                    dictating -> "Listening…"
                                    else -> "Message Lyo..."
                                },
                                color = TextSecondary.copy(alpha = 0.75f),
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                        innerTextField()
                    }
                },
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
            ) {
                IconButton(
                    onClick = {
                        attachmentPicker.launch(
                            arrayOf(
                                "image/jpeg", "image/png", "image/webp", "image/heic",
                                "application/pdf", "text/plain", "text/markdown", "text/csv",
                                "application/json",
                            ),
                        )
                    },
                    enabled = !isStreaming && !uploadingAttachment &&
                        pendingAttachments.size < MAX_CHAT_ATTACHMENTS,
                    modifier = Modifier
                        .size(34.dp).clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.10f)),
                ) {
                    if (uploadingAttachment) {
                        CircularProgressIndicator(
                            color = LyoPurple, strokeWidth = 2.dp,
                            modifier = Modifier.size(18.dp),
                        )
                    } else {
                        Icon(Icons.Default.Add, contentDescription = "Attach an image or document",
                            tint = TextPrimary, modifier = Modifier.size(20.dp))
                    }
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.10f))
                        .clickable(enabled = !uploadingAttachment) {
                            if (voiceConversation) {
                                stopVoiceConversation()
                            } else if (
                                ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                                android.content.pm.PackageManager.PERMISSION_GRANTED
                            ) {
                                voiceConversation = true
                                voiceListenNonce += 1
                            } else {
                                voicePermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    Icon(Icons.Default.Mic, contentDescription = null,
                        tint = TextPrimary, modifier = Modifier.size(16.dp))
                    Text(
                        if (voiceConversation) "Stop" else "Talk",
                        color = TextPrimary,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }
                Box(modifier = Modifier.weight(1f))
                if (input.length > MAX_CHAT_CHARS * 9 / 10) {
                    Text(
                        "${MAX_CHAT_CHARS - input.length}",
                        color = TextSecondary, style = MaterialTheme.typography.labelSmall,
                    )
                }
                IconButton(
                    onClick = ::startDictation,
                    enabled = !isStreaming,
                    modifier = Modifier.size(34.dp),
                ) {
                    Icon(Icons.Default.Mic, contentDescription = "Dictate a message",
                        tint = if (dictating) Color(0xFFFFAC65) else TextPrimary,
                        modifier = Modifier.size(20.dp))
                }
                val canSend = !isStreaming && !uploadingAttachment &&
                    (input.isNotBlank() || pendingAttachments.isNotEmpty())
                IconButton(
                    onClick = { send(input) },
                    enabled = canSend,
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(if (canSend) Color.White else Color.White.copy(alpha = 0.12f)),
                ) {
                    Icon(
                        imageVector = Icons.Default.ArrowUpward,
                        contentDescription = "Send message",
                        tint = if (canSend) Color(0xFF11111A) else TextSecondary.copy(alpha = 0.55f),
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
    }
    AnimatedVisibility(
        visible = showHistory,
        enter = slideInHorizontally(
            initialOffsetX = { -it },
            animationSpec = tween(durationMillis = 260, easing = FastOutSlowInEasing),
        ) + fadeIn(animationSpec = tween(220)),
        exit = slideOutHorizontally(
            targetOffsetX = { -it },
            animationSpec = tween(durationMillis = 200),
        ) + fadeOut(animationSpec = tween(170)),
    ) {
        Row(
            modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.64f)),
        ) {
            Column(
                modifier = Modifier
                    .width(288.dp)
                    .fillMaxHeight()
                    .background(Color(0xFF11111F))
                    .border(0.5.dp, Color.White.copy(alpha = 0.10f))
                    .padding(top = 18.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(9.dp),
                        modifier = Modifier.weight(1f),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Brush.linearGradient(listOf(LyoPurple, Color(0xFF8D49DB)))),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("LYO", color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                        }
                        Text("LYO", color = TextPrimary, fontWeight = FontWeight.Bold)
                    }
                    IconButton(onClick = { showHistory = false }) {
                        Icon(Icons.Default.Close, contentDescription = "Close conversation history",
                            tint = TextSecondary)
                    }
                }
                Box(
                    modifier = Modifier.fillMaxWidth().padding(12.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(
                            Brush.horizontalGradient(
                                listOf(LyoPurple.copy(alpha = 0.35f),
                                    Color(0xFF9C4ADA).copy(alpha = 0.20f)),
                            ),
                        )
                        .border(1.dp, LyoPurple.copy(alpha = 0.32f), RoundedCornerShape(14.dp))
                        .clickable(enabled = !isStreaming) { newChat() }
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("+  New Chat", color = TextPrimary, fontWeight = FontWeight.Medium)
                }
                historyError?.let {
                    Text(it, color = Color(0xFFFF9A9A),
                        modifier = Modifier.padding(16.dp))
                }
                if (conversations.isEmpty() && historyError == null) {
                    Text(
                        "No conversations yet. Start chatting!",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(20.dp),
                    )
                }
                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    items(conversations, key = { it.id }) { conversation ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (conversation.id == activeConversationId)
                                        LyoPurple.copy(alpha = 0.22f)
                                    else Color.Transparent,
                                )
                                .clickable(enabled = !isStreaming) {
                                    scope.launch {
                                        runCatching { ApiClient.api.aiConversation(conversation.id) }
                                            .onSuccess { detail ->
                                                activeConversationId = detail.id
                                                messages.clear()
                                                messages.addAll(detail.messages.map { it.toChatMsg() })
                                                pendingAttachments.clear()
                                                input = ""
                                                showHistory = false
                                            }
                                            .onFailure {
                                                historyError = "Could not open this conversation."
                                            }
                                    }
                                }
                                .padding(horizontal = 12.dp, vertical = 12.dp),
                        ) {
                            Icon(Icons.Default.ChatBubbleOutline, contentDescription = null,
                                tint = if (conversation.id == activeConversationId)
                                    LyoPurple else TextSecondary,
                                modifier = Modifier.size(18.dp))
                            Text(
                                conversation.title.ifBlank {
                                    conversation.lastMessagePreview ?: "New Chat"
                                },
                                color = if (conversation.id == activeConversationId)
                                    TextPrimary else TextSecondary,
                                maxLines = 1, overflow = TextOverflow.Ellipsis,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.padding(start = 10.dp),
                            )
                        }
                    }
                }
                Text(
                    "Powered by LYO · All chats private",
                    style = MaterialTheme.typography.labelSmall,
                    color = TextSecondary.copy(alpha = 0.6f),
                    modifier = Modifier.fillMaxWidth().padding(14.dp),
                    textAlign = TextAlign.Center,
                )
            }
            Box(
                modifier = Modifier.weight(1f).fillMaxHeight()
                    .clickable { showHistory = false },
            )
        }
    }
    }
    }
}

@Composable
private fun PendingAttachmentChip(
    attachment: PendingChatAttachment,
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
        if (attachment.isImage) {
            AsyncImage(
                model = attachment.url,
                contentDescription = attachment.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(10.dp)),
            )
        } else {
            Icon(
                imageVector = Icons.Default.InsertDriveFile,
                contentDescription = null,
                tint = LyoPurple,
                modifier = Modifier.size(32.dp),
            )
        }
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
                contentDescription = "Remove attachment",
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
    onAnswerCheck: (blockId: String, selectedIndex: Int) -> Unit,
    onVisualUpdate: (blockId: String, values: Map<String, JsonElement>) -> Unit,
) {
    val context = LocalContext.current
    val isUser = msg.role == "user"
    val parsed = remember(msg.content) { parseChatContent(msg.content) }

    Row(
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Center,
        modifier = if (isUser) {
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
        } else {
            Modifier.fillMaxWidth()
        },
    ) {
        val bubbleShape = RoundedCornerShape(
            topStart = 18.dp,
            topEnd = 18.dp,
            bottomStart = if (isUser) 18.dp else 4.dp,
            bottomEnd = if (isUser) 4.dp else 18.dp,
        )
        val bubbleModifier = Modifier
            .then(
                if (isUser) Modifier.widthIn(max = 320.dp)
                else Modifier.fillMaxWidth(ASSISTANT_RESPONSE_WIDTH_FRACTION),
            )
            .clip(bubbleShape)
            .let {
                if (isUser) it.background(LyoBrandGradient)
                else it
                    .background(Color.White.copy(alpha = 0.075f))
                    .border(1.dp, Color.White.copy(alpha = 0.12f), bubbleShape)
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
                parsed.attachments.forEachIndexed { index, attachment ->
                    if (attachment.isImage) {
                        AsyncImage(
                            model = attachment.url,
                            contentDescription = attachment.name,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 120.dp, max = 240.dp)
                                .padding(top = if (index == 0) 0.dp else 8.dp)
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
                                .fillMaxWidth()
                                .padding(top = if (index == 0) 0.dp else 8.dp)
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

                val blocks = msg.blocks
                if (!blocks.isNullOrEmpty()) {
                    // Structured lesson content — every beat (hook, callout,
                    // dataViz, flashcard, quiz, ...), not just the plain text
                    // in msg.content. Rendered instead of parsed.text below,
                    // same mutual exclusivity web/iOS use: a turn's answer
                    // lives in one place or the other, never both.
                    SmartBlockList(
                        blocks = blocks,
                        checkResults = msg.checkResults,
                        onQuizAnswer = onAnswerCheck,
                        onVisualUpdate = onVisualUpdate,
                        modifier = Modifier.padding(top = if (parsed.attachments.isNotEmpty()) 8.dp else 0.dp),
                        contentColor = if (isUser) Color.White else TextPrimary,
                    )
                } else if (parsed.text.isNotBlank()) {
                    Text(
                        text = parsed.text,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (isUser) Color.White else TextPrimary,
                        modifier = Modifier.padding(top = if (parsed.attachments.isNotEmpty()) 8.dp else 0.dp),
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

private suspend fun uploadChatAttachment(
    context: Context,
    uri: Uri,
    remainingTotalBytes: Long,
): PendingChatAttachment {
    val resolver = context.contentResolver
    val displayName = attachmentDisplayName(context, uri)
    val contentType = chatAttachmentMimeType(resolver.getType(uri), displayName)
        ?: throw IllegalArgumentException("Choose an image, PDF, TXT, Markdown, CSV, or JSON file.")
    if (contentType !in SupportedChatAttachmentTypes) {
        throw IllegalArgumentException("That file type is not supported in chat.")
    }
    if (remainingTotalBytes <= 0) {
        throw IllegalArgumentException("Attachments may total at most 20MB.")
    }

    val byteLimit = minOf(MAX_CHAT_ATTACHMENT_BYTES, remainingTotalBytes)
    val bytes = withContext(Dispatchers.IO) {
        resolver.openInputStream(uri)?.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (total > byteLimit) {
                    val message = if (total > MAX_CHAT_ATTACHMENT_BYTES) {
                        "Each attachment must be 10MB or smaller."
                    } else {
                        "Attachments may total at most 20MB."
                    }
                    throw IllegalArgumentException(message)
                }
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        }
    } ?: throw IllegalStateException("The selected attachment could not be read.")

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
        ?: throw IllegalStateException("The media service did not return a file URL.")
    return PendingChatAttachment(
        name = displayName,
        url = url,
        mimeType = contentType,
        size = bytes.size.toLong(),
        isImage = contentType.startsWith("image/"),
    )
}

private fun chatAttachmentMimeType(reportedType: String?, displayName: String): String? {
    val normalized = reportedType?.substringBefore(';')?.trim()?.lowercase()
    if (normalized in SupportedChatAttachmentTypes) return normalized
    return when (displayName.substringAfterLast('.', "").lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "heic" -> "image/heic"
        "pdf" -> "application/pdf"
        "txt" -> "text/plain"
        "md", "markdown" -> "text/markdown"
        "csv" -> "text/csv"
        "json" -> "application/json"
        else -> null
    }
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
        ?.take(120)
        ?: "attachment"
}

private fun buildChatContent(
    text: String,
    attachments: List<PendingChatAttachment>,
): String {
    val parts = mutableListOf<String>()
    if (text.isNotBlank()) parts.add(text)
    attachments.forEach { attachment ->
        parts.add(
            if (attachment.isImage) "![${attachment.name}](${attachment.url})"
            else "[📎 ${attachment.name}](${attachment.url})",
        )
    }
    return parts.joinToString("\n\n")
}

private fun parseChatContent(content: String): ParsedChatContent {
    val attachments = mutableListOf<Pair<Int, LinkedAttachment>>()
    ImageMarkdown.findAll(content).forEach { match ->
        attachments.add(
            match.range.first to LinkedAttachment(
                name = match.groupValues[1].ifBlank { "Image" },
                url = match.groupValues[2],
                isImage = true,
            ),
        )
    }
    FileMarkdown.findAll(content).forEach { match ->
        attachments.add(
            match.range.first to LinkedAttachment(
                name = match.groupValues[1],
                url = match.groupValues[2],
                isImage = false,
            ),
        )
    }
    val text = content
        .replace(ImageMarkdown, "")
        .replace(FileMarkdown, "")
        .trim()
    return ParsedChatContent(
        text = text,
        attachments = attachments.sortedBy { it.first }.map { it.second },
    )
}

private fun openAttachment(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
