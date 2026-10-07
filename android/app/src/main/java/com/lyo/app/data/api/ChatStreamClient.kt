package com.lyo.app.data.api

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyo.app.BuildConfig
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

/** One streamed chunk from the AI, or a terminal signal. */
sealed class ChatStreamEvent {
    data class Chunk(val text: String) : ChatStreamEvent()
    data class FinalAnswer(val text: String) : ChatStreamEvent()
    data class Conversation(val id: String) : ChatStreamEvent()
    data class VoiceSegment(
        val text: String,
        val sequence: Int,
        val messageId: String,
    ) : ChatStreamEvent()
    data class VoiceReady(
        val text: String,
        val messageId: String,
        val speak: Boolean,
    ) : ChatStreamEvent()
    data class VoiceIncomplete(
        val text: String,
        val messageId: String,
    ) : ChatStreamEvent()
    /**
     * Structured lesson content — every beat of a composed lesson (hook,
     * callout, dataViz, flashcard, quiz, ...), not just plain prose. Web and
     * iOS decode this same `smart_blocks` event; see chat-contract.mjs.
     */
    data class SmartBlocks(val blocks: List<SmartBlock>) : ChatStreamEvent()
    data object Done : ChatStreamEvent()
    data class Error(val message: String) : ChatStreamEvent()
}

/** Structured media metadata consumed by RouterRequest.media on the backend. */
data class ChatMediaRef(
    val modality: String,
    val uri: String,
    val mimeType: String,
    val name: String,
    val sizeBytes: Long,
)

/**
 * SSE client for POST /api/v1/lyo2/chat/stream — reads `data: {json}` lines
 * until `data: [DONE]`, mirroring the web client's api.chat.stream().
 */
object ChatStreamClient {

    private data class TeachingRuntimeState(
        val lastAction: String? = null,
        val consecutiveChecks: Int = 0,
        val consecutiveExplanations: Int = 0,
    )

    private val teachingRuntimeByConversation = ConcurrentHashMap<String, TeachingRuntimeState>()
    private val checkActions = setOf(
        "diagnose", "guide", "check_recall", "check_application", "check_transfer", "review",
    )
    private val explanationActions = setOf("explain", "demonstrate", "remediate")
    private val validActions = setOf(
        "answer", "diagnose", "explain", "demonstrate", "guide", "check_recall",
        "check_application", "check_transfer", "remediate", "review", "advance", "pause",
    )

    private fun applyTeachingPolicy(conversationId: String, action: String) {
        if (action !in validActions) return
        val old = teachingRuntimeByConversation[conversationId] ?: TeachingRuntimeState()
        teachingRuntimeByConversation[conversationId] = when {
            action in checkActions -> old.copy(
                lastAction = action,
                consecutiveChecks = (old.consecutiveChecks + 1).coerceAtMost(8),
                consecutiveExplanations = 0,
            )
            action in explanationActions -> old.copy(
                lastAction = action,
                consecutiveChecks = 0,
                consecutiveExplanations = (old.consecutiveExplanations + 1).coerceAtMost(8),
            )
            else -> old.copy(
                lastAction = action,
                consecutiveChecks = 0,
                consecutiveExplanations = 0,
            )
        }
    }

    fun stream(
        text: String,
        conversationId: String,
        clientMessageId: String,
        media: List<ChatMediaRef> = emptyList(),
        voiceSession: Boolean = false,
        voiceInterruptedPreviousTurn: Boolean = false,
        voiceTurnId: String? = null,
        voiceLocale: String = java.util.Locale.getDefault().toLanguageTag(),
    ): Flow<ChatStreamEvent> = callbackFlow {
        val requestFields = mutableMapOf<String, Any?>(
            "text" to text,
            "conversation_id" to conversationId,
            "device_id" to "android",
            "client_message_id" to clientMessageId,
            "timezone" to java.time.ZoneId.systemDefault().id,
        )
        val stateSummary = mutableMapOf<String, Any?>(
            "stream_capabilities" to mapOf("text_delta" to true),
        )
        teachingRuntimeByConversation[conversationId]?.let { runtime ->
            runtime.lastAction?.let {
                stateSummary["teaching_runtime"] = mapOf(
                    "last_action" to runtime.lastAction,
                    "consecutive_checks" to runtime.consecutiveChecks,
                    "consecutive_explanations" to runtime.consecutiveExplanations,
                )
            }
        }
        if (voiceSession) {
            requestFields["voice_session"] = mapOf(
                "active" to true,
                "transport" to "client_stt_tts",
                "locale" to voiceLocale,
                "turn_id" to (voiceTurnId ?: clientMessageId),
                "interrupted_previous_turn" to voiceInterruptedPreviousTurn,
                "delivery" to "segments",
                "hands_free" to true,
            )
        }
        if (stateSummary.isNotEmpty()) {
            requestFields["state_summary"] = stateSummary
        }
        if (media.isNotEmpty()) {
            requestFields["media"] = media.map { item ->
                mapOf(
                    "modality" to item.modality,
                    "uri" to item.uri,
                    "mime_type" to item.mimeType,
                    "name" to item.name,
                    "size_bytes" to item.sizeBytes,
                )
            }
        }
        val payload = ApiClient.gson.toJson(
            requestFields,
        ).toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(BuildConfig.API_BASE_URL + "api/v1/lyo2/chat/stream")
            .post(payload)
            .build()

        val call = ApiClient.okHttp.newCall(request)
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                trySend(ChatStreamEvent.Error(e.message ?: "Stream failed"))
                close()
            }

            override fun onResponse(call: Call, response: Response) {
                response.use { resp ->
                    if (!resp.isSuccessful) {
                        trySend(ChatStreamEvent.Error("Stream failed: HTTP ${resp.code}"))
                        close()
                        return
                    }
                    val source = resp.body?.source()
                    if (source == null) {
                        trySend(ChatStreamEvent.Error("Empty response body"))
                        close()
                        return
                    }
                    try {
                        while (!source.exhausted()) {
                            val line = source.readUtf8Line() ?: break
                            val trimmed = line.trim()
                            if (!trimmed.startsWith("data:")) continue
                            val data = trimmed.removePrefix("data:").trim()
                            if (data == "[DONE]") {
                                trySend(ChatStreamEvent.Done)
                                close()
                                return
                            }
                            val parsed = parseChunk(data, conversationId)
                            if (parsed != null) trySend(parsed)
                        }
                        trySend(ChatStreamEvent.Done)
                    } catch (e: Exception) {
                        trySend(ChatStreamEvent.Error(e.message ?: "Stream interrupted"))
                    }
                    close()
                }
            }
        })

        awaitClose { call.cancel() }
    }

    /** Extract text from the varied chunk shapes the backend emits. */
    private fun parseChunk(data: String, conversationId: String): ChatStreamEvent? = try {
        val obj: JsonObject = JsonParser.parseString(data).asJsonObject
        when {
            obj.get("type")?.asString == "teaching_policy" -> {
                obj.get("action")?.takeIf { it.isJsonPrimitive }?.asString?.let {
                    applyTeachingPolicy(conversationId, it)
                }
                null
            }
            obj.get("type")?.asString == "error" ->
                ChatStreamEvent.Error(
                    obj.get("message")?.asString ?: "The response could not be generated.",
                )
            obj.get("type")?.asString == "conversation" && obj.has("conversation_id") ->
                ChatStreamEvent.Conversation(obj.get("conversation_id").asString)
            obj.get("type")?.asString == "voice_text_segment" &&
                obj.has("text") && obj.has("sequence") && obj.has("message_id") ->
                ChatStreamEvent.VoiceSegment(
                    text = obj.get("text").asString,
                    sequence = obj.get("sequence").asInt,
                    messageId = obj.get("message_id").asString,
                )
            obj.get("type")?.asString == "voice_ready" &&
                obj.has("text") && obj.has("message_id") ->
                ChatStreamEvent.VoiceReady(
                    text = obj.get("text").asString,
                    messageId = obj.get("message_id").asString,
                    speak = !obj.has("speak") || obj.get("speak").asBoolean,
                )
            obj.get("type")?.asString == "voice_incomplete" ->
                ChatStreamEvent.VoiceIncomplete(
                    text = obj.get("text")?.takeIf { it.isJsonPrimitive }?.asString.orEmpty(),
                    messageId = obj.get("message_id")?.takeIf { it.isJsonPrimitive }?.asString
                        ?: "voice-incomplete",
                )
            obj.get("type")?.asString == "text_delta" && obj.has("content") ->
                ChatStreamEvent.Chunk(obj.get("content").asString)
            obj.get("type")?.asString == "answer" && obj.has("block") -> {
                val text = obj.getAsJsonObject("block")
                    ?.getAsJsonObject("content")
                    ?.get("text")
                    ?.asString
                text?.let { ChatStreamEvent.FinalAnswer(it) }
            }
            obj.get("type")?.asString == "clarification" && obj.has("text") ->
                ChatStreamEvent.Chunk(obj.get("text").asString)
            obj.get("type")?.asString == "smart_blocks" && obj.has("blocks") -> {
                val blocksJson = obj.getAsJsonArray("blocks")
                val blocks: List<SmartBlock> = blocksJson.map { element ->
                    ApiClient.gson.fromJson(element, SmartBlock::class.java)
                }
                blocks.takeIf { it.isNotEmpty() }?.let { ChatStreamEvent.SmartBlocks(it) }
            }
            obj.has("data") && obj.get("data").isJsonPrimitive -> ChatStreamEvent.Chunk(obj.get("data").asString)
            obj.has("content") && obj.get("content").isJsonPrimitive -> ChatStreamEvent.Chunk(obj.get("content").asString)
            obj.has("text") && obj.get("text").isJsonPrimitive -> ChatStreamEvent.Chunk(obj.get("text").asString)
            obj.has("answer") && obj.get("answer").isJsonPrimitive -> ChatStreamEvent.Chunk(obj.get("answer").asString)
            else -> null
        }
    } catch (e: Exception) {
        null
    }
}
