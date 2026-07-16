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

/** One streamed chunk from the AI, or a terminal signal. */
sealed class ChatStreamEvent {
    data class Chunk(val text: String) : ChatStreamEvent()
    data object Done : ChatStreamEvent()
    data class Error(val message: String) : ChatStreamEvent()
}

/**
 * SSE client for POST /api/v1/lyo2/chat/stream — reads `data: {json}` lines
 * until `data: [DONE]`, mirroring the web client's api.chat.stream().
 */
object ChatStreamClient {

    fun stream(
        text: String,
        history: List<Map<String, String>> = emptyList(),
    ): Flow<ChatStreamEvent> = callbackFlow {
        val payload = ApiClient.gson.toJson(
            mapOf("text" to text, "history" to history)
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
                            val chunkText = parseChunk(data)
                            if (chunkText != null) trySend(ChatStreamEvent.Chunk(chunkText))
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
    private fun parseChunk(data: String): String? = try {
        val obj: JsonObject = JsonParser.parseString(data).asJsonObject
        when {
            obj.has("data") && obj.get("data").isJsonPrimitive -> obj.get("data").asString
            obj.has("content") && obj.get("content").isJsonPrimitive -> obj.get("content").asString
            obj.has("text") && obj.get("text").isJsonPrimitive -> obj.get("text").asString
            obj.has("answer") && obj.get("answer").isJsonPrimitive -> obj.get("answer").asString
            else -> null
        }
    } catch (e: Exception) {
        null
    }
}
