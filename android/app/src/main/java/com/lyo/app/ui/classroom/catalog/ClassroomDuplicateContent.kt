package com.lyo.app.ui.classroom.catalog

import com.lyo.app.data.a2ui.A2uiChildren
import com.lyo.app.data.a2ui.A2uiComponent
import com.lyo.app.data.a2ui.A2uiSurfaceState
import com.lyo.app.data.classroom.parseBoardDocument

/** Presentation only: never delete lesson state, answers or server components. */
internal fun isRepeatedQuestionCard(surface: A2uiSurfaceState, card: A2uiComponent): Boolean {
    fun text(component: A2uiComponent, key: String): String? =
        surface.resolve(component.properties[key])?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }?.asString
    fun normalized(value: String) = value.trim().replace(Regex("\\s+"), " ")
    if (card.component != "SummaryBlock") return false
    if (text(card, "role") !in listOf(null, "board", "practice")) return false
    if (surface.resolve(card.properties["retrievalScheduled"])?.toString() == "true") return false
    val items = surface.resolve(card.properties["items"])
    if (items != null && !items.isJsonNull && (!items.isJsonArray || items.asJsonArray.size() > 0)) return false
    val rawDocument = surface.resolve(card.properties["document"])
    val document = parseBoardDocument(rawDocument)
    if (rawDocument != null && !rawDocument.isJsonNull && document == null) return false
    if (document != null && document.blocks.any { it.kind != "text" }) return false
    val body = document?.blocks?.joinToString(" ") { it.text } ?: text(card, "content") ?: return false
    val candidate = normalized(body)
    if (candidate.isEmpty()) return false

    // Old components remain in the state table after clearBoard(). Only
    // compare questions reachable from the current board, never past scenes.
    val visited = mutableSetOf<String>()
    fun matches(id: String): Boolean {
        if (!visited.add(id)) return false
        val node = surface.components[id] ?: return false
        if (node.component in listOf("QuizCard", "TransferInput")) {
            if (text(node, "question")?.let(::normalized) == candidate) return true
        }
        // user_prompt panels keep their question in a Text child.
        if (node.component == "Text" && node.id.startsWith("prompt_") && node.id.endsWith("_q")) {
            if (text(node, "text")?.let(::normalized) == candidate) return true
        }
        if (node.child?.let(::matches) == true) return true
        return (node.children as? A2uiChildren.Fixed)?.ids?.any(::matches) == true
    }
    return matches("board_column")
}
