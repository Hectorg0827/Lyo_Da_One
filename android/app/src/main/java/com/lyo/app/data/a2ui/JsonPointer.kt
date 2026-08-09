package com.lyo.app.data.a2ui

import com.google.gson.JsonElement
import com.google.gson.JsonObject

/**
 * RFC 6901 JSON Pointer resolve/set against Gson's JsonElement tree — the
 * data-binding mechanism A2UI properties use (A2uiValue.PathRef) to read
 * from, and ClassroomBridge/A2uiSurfaceState use to write to, the surface's
 * data model. See a2ui_protocol.md's "Data Model & Two-Way Binding" section.
 */

private fun unescapeToken(token: String): String =
    token.replace("~1", "/").replace("~0", "~")

private fun tokenize(pointer: String): List<String> {
    if (pointer.isEmpty() || pointer == "/") return emptyList()
    val trimmed = if (pointer.startsWith("/")) pointer.substring(1) else pointer
    if (trimmed.isEmpty()) return emptyList()
    return trimmed.split("/").map(::unescapeToken)
}

/**
 * Resolves `pointer` against this element. Returns null if any segment of
 * the path doesn't exist — a missing binding renders as "nothing" in the
 * catalog renderers, never a crash, matching the resilience the rest of the
 * wire parsing follows (see ClassroomServerEvent.parseServerEvent).
 */
fun JsonElement.resolvePointer(pointer: String): JsonElement? {
    var current: JsonElement = this
    for (token in tokenize(pointer)) {
        current = when {
            current.isJsonObject -> current.asJsonObject.get(token) ?: return null
            current.isJsonArray -> {
                val index = token.toIntOrNull() ?: return null
                val array = current.asJsonArray
                if (index < 0 || index >= array.size()) return null
                array.get(index)
            }
            else -> return null
        }
    }
    return current
}

/**
 * Upserts `value` at `pointer` inside this JsonObject, creating intermediate
 * objects as needed. `value == null` (or JsonNull) deletes the key at
 * `pointer` — upsert semantics per the protocol spec. Scoped to
 * object-keyed paths only (the classroom's data model never needs to write
 * a single element inside an existing array by numeric index — turns always
 * replace whole arrays/objects at a named key); a whole-root replace
 * (`pointer` empty or "/") is handled by the caller swapping the data model
 * reference directly (see A2uiSurfaceState.applyUpdateDataModel), not here.
 */
fun JsonObject.setPointer(pointer: String, value: JsonElement?) {
    val tokens = tokenize(pointer)
    if (tokens.isEmpty()) return
    var current = this
    for (i in 0 until tokens.size - 1) {
        val token = tokens[i]
        val next = current.get(token)
        current = if (next != null && next.isJsonObject) {
            next.asJsonObject
        } else {
            JsonObject().also { current.add(token, it) }
        }
    }
    val lastToken = tokens.last()
    if (value == null || value.isJsonNull) {
        current.remove(lastToken)
    } else {
        current.add(lastToken, value)
    }
}
