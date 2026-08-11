package com.lyo.app.data.api

import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName
import java.lang.reflect.Type
import java.util.UUID

/**
 * Unified block type shared across chat, classroom, and course generation.
 *
 * Mirrors `SmartBlockType` in Sources/Models/SmartBlock.swift (iOS) and
 * `CHAT_BLOCK_TYPES` in web/src/lib/chat-contract.mjs — the three clients
 * decode the backend's SmartBlock envelope (lyo_app/ai/schemas/smart_block.py)
 * independently, so the vocabulary must stay in lockstep across all three.
 */
enum class SmartBlockType(val wireValue: String) {
    TEXT("text"),
    CODE("code"),
    QUIZ("quiz"),
    FLASHCARD("flashcard"),
    DATA_VIZ("dataViz"),
    MEDIA("media"),
    PROGRESS("progress"),
    INTERACTIVE("interactive"),
    MASTERY_MAP("masteryMap"),
    UNKNOWN("unknown"),
    ;

    companion object {
        /** Handles both camelCase ("dataViz") and snake_case ("data_viz") from the backend. */
        fun fromWire(raw: String?): SmartBlockType {
            if (raw == null) return UNKNOWN
            entries.firstOrNull { it.wireValue == raw }?.let { return it }
            val parts = raw.split("_")
            val camelCased = parts.mapIndexed { index, part ->
                if (index == 0) part else part.replaceFirstChar { it.uppercase() }
            }.joinToString("")
            return entries.firstOrNull { it.wireValue == camelCased } ?: UNKNOWN
        }
    }
}

/** Type-safe content container — each block type has its own payload. */
sealed class SmartBlockContent {
    data class Text(val payload: TextBlockPayload) : SmartBlockContent()
    data class Code(val payload: CodeBlockPayload) : SmartBlockContent()
    data class Quiz(val payload: QuizBlockPayload) : SmartBlockContent()
    data class Flashcard(val payload: FlashcardBlockPayload) : SmartBlockContent()
    data class DataViz(val payload: DataVizBlockPayload) : SmartBlockContent()
    data class Media(val payload: MediaBlockPayload) : SmartBlockContent()
    data class Progress(val payload: ProgressBlockPayload) : SmartBlockContent()
    data class Interactive(val payload: InteractiveBlockPayload) : SmartBlockContent()
    data class MasteryMap(val payload: MasteryMapBlockPayload) : SmartBlockContent()
    data class Unknown(val raw: JsonObject) : SmartBlockContent()
}

/** A single renderable content block with schema versioning. */
data class SmartBlock(
    val id: String,
    val schemaVersion: Int,
    val type: SmartBlockType,
    val subtype: String?,
    val content: SmartBlockContent,
    val metadata: Map<String, JsonElement>?,
)

// ── Content Payloads ─────────────────────────────────────────────────────────
// Field-for-field mirrors of Sources/Models/SmartBlock.swift's payload structs.

data class TextBlockPayload(
    val text: String = "",
    val style: String? = null,
)

data class CodeBlockPayload(
    val language: String = "plain",
    val code: String = "",
    @SerializedName("is_runnable") val isRunnable: Boolean? = null,
)

data class QuizOptionPayload(
    val id: String = "",
    val text: String = "",
    /** The misconception this distractor reveals, when the answer is wrong. */
    val reveals: String? = null,
)

data class QuizBlockPayload(
    val question: String = "",
    val options: List<QuizOptionPayload> = emptyList(),
    /**
     * Present on the wire for the *server's* use when grading — never read
     * here to decide correctness client-side. See SmartBlockRenderer's quiz
     * composable, which renders only off the server's CheckAnswerResult.
     */
    @SerializedName("correct_index") val correctIndex: Int = 0,
    val explanation: String? = null,
    val hint: String? = null,
    /** The "just explain it" opt-out option index, when offered. */
    @SerializedName("bailout_index") val bailoutIndex: Int? = null,
)

data class FlashcardBlockPayload(
    val front: String,
    val back: String,
    val tags: String? = null,
)

data class DataVizBlockPayload(
    /** mermaid, chart, table, math, text */
    val format: String,
    val source: String,
    val title: String? = null,
)

data class MediaBlockPayload(
    val url: String,
    val alt: String? = null,
    val caption: String? = null,
)

data class ProgressBlockPayload(
    val completed: Int,
    val total: Int,
    val label: String? = null,
)

data class InteractiveItem(
    val label: String,
    val detail: String,
)

data class InteractiveBlockPayload(
    val items: List<InteractiveItem> = emptyList(),
    val title: String? = null,
)

data class MasteryNodePayload(
    @SerializedName("node_id") val nodeId: String = UUID.randomUUID().toString(),
    val title: String,
    val status: String,
    @SerializedName("mastery_level") val masteryLevel: Double? = null,
)

data class MasteryMapBlockPayload(
    val title: String,
    val nodes: List<MasteryNodePayload> = emptyList(),
)

/**
 * Routes the `content` object to the right typed payload based on the
 * sibling `type` field. Gson has no native sealed-class polymorphism, so
 * this does by hand what `SmartBlock.init(from decoder:)` does on iOS and
 * what the backend's discriminated union does in Python: fail closed to
 * `.Unknown` (never crash, never render raw JSON) rather than throw when a
 * payload doesn't match its declared type.
 *
 * Registered on the shared `ApiClient.gson` instance, so this applies
 * uniformly to Retrofit responses (a reloaded conversation's `blocks`) and
 * the manually-parsed SSE `smart_blocks` event alike.
 */
class SmartBlockDeserializer : JsonDeserializer<SmartBlock> {
    override fun deserialize(
        json: JsonElement,
        typeOfT: Type,
        context: JsonDeserializationContext,
    ): SmartBlock {
        val obj = json.asJsonObject
        val id = obj.get("id")?.takeIf { it.isJsonPrimitive }?.asString ?: UUID.randomUUID().toString()
        val schemaVersion = obj.get("schema_version")?.takeIf { it.isJsonPrimitive }?.asInt
            ?: obj.get("schemaVersion")?.takeIf { it.isJsonPrimitive }?.asInt
            ?: 1
        val type = SmartBlockType.fromWire(obj.get("type")?.takeIf { it.isJsonPrimitive }?.asString)
        val subtype = obj.get("subtype")?.takeIf { it.isJsonPrimitive }?.asString
        val contentElement = obj.get("content")?.takeIf { it.isJsonObject } ?: JsonObject()
        val metadata = obj.get("metadata")?.takeIf { it.isJsonObject }
            ?.asJsonObject?.entrySet()?.associate { it.key to it.value }

        val content = try {
            when (type) {
                SmartBlockType.TEXT ->
                    SmartBlockContent.Text(context.deserialize(contentElement, TextBlockPayload::class.java))
                SmartBlockType.CODE ->
                    SmartBlockContent.Code(context.deserialize(contentElement, CodeBlockPayload::class.java))
                SmartBlockType.QUIZ ->
                    SmartBlockContent.Quiz(context.deserialize(contentElement, QuizBlockPayload::class.java))
                SmartBlockType.FLASHCARD ->
                    SmartBlockContent.Flashcard(context.deserialize(contentElement, FlashcardBlockPayload::class.java))
                SmartBlockType.DATA_VIZ ->
                    SmartBlockContent.DataViz(context.deserialize(contentElement, DataVizBlockPayload::class.java))
                SmartBlockType.MEDIA ->
                    SmartBlockContent.Media(context.deserialize(contentElement, MediaBlockPayload::class.java))
                SmartBlockType.PROGRESS ->
                    SmartBlockContent.Progress(context.deserialize(contentElement, ProgressBlockPayload::class.java))
                SmartBlockType.INTERACTIVE ->
                    SmartBlockContent.Interactive(context.deserialize(contentElement, InteractiveBlockPayload::class.java))
                SmartBlockType.MASTERY_MAP ->
                    SmartBlockContent.MasteryMap(context.deserialize(contentElement, MasteryMapBlockPayload::class.java))
                SmartBlockType.UNKNOWN -> SmartBlockContent.Unknown(contentElement.asJsonObject)
            }
        } catch (e: Exception) {
            SmartBlockContent.Unknown(contentElement.asJsonObject)
        }

        return SmartBlock(
            id = id,
            schemaVersion = schemaVersion,
            type = type,
            subtype = subtype,
            content = content,
            metadata = metadata,
        )
    }
}

// ── Check-grading (mirrors CheckAnswerResult.swift / web's CheckAnswerResult) ─

/**
 * A learner's answer to an in-chat check, sent to the server for grading.
 *
 * Deliberately carries neither the question nor the answer key — the server
 * reads those back from the block it already emitted, so the client cannot
 * assert its own correctness.
 */
data class CheckAnswerRequest(
    @SerializedName("conversation_id") val conversationId: String,
    @SerializedName("block_id") val blockId: String,
    @SerializedName("selected_index") val selectedIndex: Int,
    @SerializedName("time_taken_ms") val timeTakenMs: Int = 0,
    @SerializedName("hint_used") val hintUsed: Boolean = false,
)

/**
 * Server verdict for an answered check. The client renders this — it never
 * computes `correct` itself, and `QuizBlockPayload.correctIndex` is never
 * used to decide it.
 */
data class CheckAnswerResult(
    val correct: Boolean,
    @SerializedName("correct_index") val correctIndex: Int,
    /** Echoed back so the chosen option can be highlighted after a reload. */
    @SerializedName("selected_index") val selectedIndex: Int,
    val explanation: String? = null,
    /** The confusion this particular wrong answer reveals, when known. */
    val misconception: String? = null,
    @SerializedName("bailed_out") val bailedOut: Boolean = false,
    @SerializedName("skill_id") val skillId: String? = null,
    val mastery: Double? = null,
)
