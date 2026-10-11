package com.lyo.app.data.classroom

import com.google.gson.JsonElement

data class ClassroomBoardBlock(
    val kind: String,
    val text: String = "",
    val language: String = "",
    val items: List<String> = emptyList(),
    val headers: List<String> = emptyList(),
    val rows: List<List<String>> = emptyList(),
)

data class ClassroomBoardDocument(val blocks: List<ClassroomBoardBlock>)

/** Reject an unsupported or malformed document as a whole; keep the full content fallback. */
fun parseBoardDocument(value: JsonElement?): ClassroomBoardDocument? {
    return runCatching {
    val obj = value?.takeIf { it.isJsonObject }?.asJsonObject ?: return null
    if (obj.get("version")?.toString() != "1") return null
    val blocks = obj.get("blocks")?.takeIf { it.isJsonArray }?.asJsonArray ?: return null
    if (blocks.size() !in 1..20) return null
    fun string(value: JsonElement?): String? = value?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }?.asString
    fun bounded(text: String) = text.isNotBlank() && text.length <= 1500
    fun strings(value: JsonElement?, max: Int): List<String>? {
        val array = value?.takeIf { it.isJsonArray }?.asJsonArray ?: return null
        if (array.size() !in 1..max) return null
        return array.map { string(it)?.takeIf(::bounded) ?: return null }
    }
    val parsed = blocks.map { raw ->
        val block = raw.takeIf { it.isJsonObject }?.asJsonObject ?: return null
        val kind = string(block.get("kind")) ?: return null
        when (kind) {
            "text", "code" -> {
                val text = string(block.get("text"))?.takeIf(::bounded) ?: return null
                val language = block.get("language")?.takeUnless { it.isJsonNull }?.let { string(it) ?: return null } ?: ""
                if (language.length > 40) return null
                ClassroomBoardBlock(kind = kind, text = text, language = language)
            }
            "bullets", "steps" -> ClassroomBoardBlock(kind = kind, items = strings(block.get("items"), 20) ?: return null)
            "table" -> {
                val headers = strings(block.get("headers"), 8) ?: return null
                val rows = block.get("rows")?.takeIf { it.isJsonArray }?.asJsonArray ?: return null
                if (rows.size() !in 1..20) return null
                val parsedRows = rows.map { strings(it, 8)?.takeIf { row -> row.size == headers.size } ?: return null }
                ClassroomBoardBlock(kind = kind, headers = headers, rows = parsedRows)
            }
            else -> return null
        }
    }
    ClassroomBoardDocument(parsed)
    }.getOrNull()
}

fun ClassroomComponent.presentationRole(): String {
    if (presentation_role in listOf("narration", "board", "reference", "practice", "feedback", "recovery", "details")) return presentation_role!!
    if (type in listOf("QuizCard", "InputField")) return "practice"
    val id = component_id.orEmpty()
    if (id == "classroom-recovery/notice") return "recovery"
    if (id.startsWith("classroom-recovery/")) return "feedback"
    if (id.contains("board-memory") || id.startsWith("memory-visual:") || block_type == "summary") return "reference"
    return "board"
}
