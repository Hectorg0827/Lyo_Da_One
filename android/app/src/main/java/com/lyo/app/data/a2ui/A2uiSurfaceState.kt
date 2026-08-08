package com.lyo.app.data.a2ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import com.google.gson.JsonElement
import com.google.gson.JsonObject

/**
 * The mutable, Compose-observable state for one A2UI surface: the flat
 * component table plus the data model. Not itself a Composable — designed
 * to be read from one. `ui.classroom.a2ui.A2uiRenderer`'s `A2uiSurface`
 * observes it directly via Compose's snapshot state system, so mutating
 * this class from `ui.classroom.ClassroomEngine` automatically triggers
 * exactly the recompositions that changed, nothing more.
 */
class A2uiSurfaceState(val surfaceId: String) {

    /** Flat component table, keyed by id. A SnapshotStateMap so recomposition
     *  is scoped to the exact component(s) that changed, not the whole tree. */
    val components: SnapshotStateMap<String, A2uiComponent> = mutableStateMapOf()

    var dataModel: JsonObject by mutableStateOf(JsonObject())
        private set

    var rootId: String? by mutableStateOf(null)
        private set

    fun applyCreateSurface(msg: A2uiMessage.CreateSurface) {
        components.clear()
        for (component in msg.components) {
            components[component.id] = component
        }
        rootId = msg.components.firstOrNull { it.id == "root" }?.id
        dataModel = (msg.dataModel as? JsonObject) ?: JsonObject()
    }

    fun applyUpdateComponents(msg: A2uiMessage.UpdateComponents) {
        for (component in msg.components) {
            components[component.id] = component
            if (component.id == "root") rootId = "root"
        }
    }

    fun applyUpdateDataModel(msg: A2uiMessage.UpdateDataModel) {
        val path = msg.path
        if (path.isEmpty() || path == "/") {
            dataModel = (msg.value as? JsonObject) ?: JsonObject()
            return
        }
        // Copy-on-write: `dataModel` is a single MutableState<JsonObject>, so
        // mutating the existing JsonObject in place would never notify
        // Compose — deep-copy, mutate the copy, then reassign so the
        // property's setter actually fires and triggers recomposition.
        val next = dataModel.deepCopy()
        next.setPointer(path, msg.value)
        dataModel = next
    }

    /**
     * Resolves a component property's declared A2uiValue against this
     * surface's data model. `scopePath` is the current template/iteration
     * scope (e.g. "/board/elements/3" while rendering the 4th item of a
     * List's template children) — PathRef paths not starting with "/" are
     * relative to it, per the protocol's collection-scope rules (see
     * a2ui_protocol.md "Collection Scopes & Relative Paths").
     */
    fun resolve(value: A2uiValue?, scopePath: String = "/"): JsonElement? = when (value) {
        null -> null
        is A2uiValue.Literal -> value.value
        is A2uiValue.PathRef -> {
            val absolute = if (value.path.startsWith("/")) {
                value.path
            } else {
                val base = if (scopePath.endsWith("/")) scopePath else "$scopePath/"
                base + value.path
            }
            dataModel.resolvePointer(absolute)
        }
        is A2uiValue.Call -> null // no custom functions registered for this classroom yet
    }
}
