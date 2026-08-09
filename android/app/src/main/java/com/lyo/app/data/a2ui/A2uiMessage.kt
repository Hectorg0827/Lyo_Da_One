package com.lyo.app.data.a2ui

import com.google.gson.JsonElement

/**
 * Kotlin model of Google's A2UI protocol wire messages (v1.0 —
 * github.com/google/A2UI, specification/v1_0/docs/a2ui_protocol.md). This
 * file models the message ENVELOPE and COMPONENT shape only — it is
 * intentionally generic and knows nothing about the AI Classroom. The
 * classroom-specific translation lives in ui.classroom.ClassroomBridge,
 * which is the "agent" that emits these messages (see that file's doc
 * comment for why: the real backend doesn't speak A2UI, so a local bridge
 * plays the agent role honestly rather than faking end-to-end protocol
 * conformance we can't actually deliver without backend changes).
 *
 * Every message in the real protocol has exactly one top-level key plus a
 * `"version": "v1.0"` field. We only need the Agent→Renderer subset for a
 * one-way-content / two-way-action classroom surface: createSurface,
 * updateComponents, updateDataModel, deleteSurface. callFunction/
 * actionResponse (function-calling extensions) aren't needed for this
 * screen and are deliberately not modeled.
 */
sealed class A2uiMessage {

    abstract val surfaceId: String

    data class CreateSurface(
        override val surfaceId: String,
        val catalogId: String? = null,
        val components: List<A2uiComponent> = emptyList(),
        val dataModel: JsonElement? = null,
    ) : A2uiMessage()

    data class UpdateComponents(
        override val surfaceId: String,
        val components: List<A2uiComponent>,
    ) : A2uiMessage()

    /** `path` is an RFC 6901 JSON Pointer, default `/` (whole-root replace).
     *  `value == null` deletes the key at `path` — upsert semantics. */
    data class UpdateDataModel(
        override val surfaceId: String,
        val path: String = "/",
        val value: JsonElement?,
    ) : A2uiMessage()

    data class DeleteSurface(override val surfaceId: String) : A2uiMessage()
}

/**
 * One entry in the FLAT component list. Components form a tree only by ID
 * reference — `child`/`children`/`children` (template form) point at other
 * components' `id`s, resolved at render time by A2uiRenderer.RenderNode.
 * Exactly one component per surface must have `id == "root"`.
 */
data class A2uiComponent(
    val id: String,
    /** Catalog component type name, e.g. "Text", "ChoicePicker", or a
     *  classroom-custom type like "MascotAvatar" — see ui.classroom.a2ui.A2uiCatalog. */
    val component: String,
    val properties: Map<String, A2uiValue> = emptyMap(),
    /** Single-child containers (e.g. Card). */
    val child: String? = null,
    /** Multi-child containers (e.g. Column, Row) or list/template iteration. */
    val children: A2uiChildren? = null,
)

sealed class A2uiChildren {
    data class Fixed(val ids: List<String>) : A2uiChildren()

    /** List-iteration binding: one child instantiated per element of the
     *  data-model array at `path`, each using `componentId` as its template,
     *  with relative paths inside the template scoped to that element. */
    data class Template(val path: String, val componentId: String) : A2uiChildren()
}

/**
 * A component property's dynamic value — one of three forms per the A2UI
 * data-binding spec: a literal, a JSON-Pointer reference into the surface's
 * data model (absolute if it starts with "/", else relative to the current
 * template/iteration scope), or a named function call. Only Literal and
 * PathRef are used by this classroom's catalog renderers; Call is modeled
 * for spec completeness but no classroom component currently needs it.
 */
sealed class A2uiValue {
    data class Literal(val value: JsonElement) : A2uiValue()
    data class PathRef(val path: String) : A2uiValue()
    data class Call(val name: String, val args: Map<String, A2uiValue> = emptyMap()) : A2uiValue()
}
