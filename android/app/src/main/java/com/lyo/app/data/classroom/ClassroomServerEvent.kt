package com.lyo.app.data.classroom

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyo.app.data.api.ApiClient

/**
 * One parsed message from the classroom WebSocket. This parser was
 * revised after reading the REAL backend source
 * (lyo_app/ai_classroom/websocket_routes.py, websocket_manager.py,
 * sdui_models.py in LyoBackendJune) rather than only the web frontend's
 * client code — two real, breaking shapes it has to handle that a naive
 * `event_type`/`component` reader would miss:
 *
 * 1. **The ad-hoc "fast welcome" envelope.** The very first content
 *    message on every connection (and every DB-init/lifecycle-engine/
 *    welcome-generation failure fallback) bypasses the normal Pydantic
 *    payload models entirely and hand-builds
 *    `{"type":"scene_stream","session_id":...,"data":{"event_type":"SCENE_START","scene":{...,"components":[...]}}}`
 *    — note the OUTER key is `type` (not `event_type`), and the real
 *    (uppercase) event type plus the actual content live nested under
 *    `data`. `"scene_stream"` is treated as a scene-start synonym here
 *    (see SCENE_START_TYPES) precisely so this shape resolves correctly.
 * 2. **scene_start/scene_update carry a full `scene.components[]` array,
 *    not a singular `component`.** Crucially, THIS is also the only
 *    delivery mechanism for the fast-welcome's content above — unlike the
 *    real (async, Pydantic-based) welcome scene, which sends its
 *    components BOTH embedded in scene_start AND individually via
 *    component_render, the fast-welcome scene_start is NOT followed by a
 *    duplicate component_render. So scene_start's embedded components
 *    must be extracted and rendered, not just used as an erase signal —
 *    see SceneStartEvent.components. ClassroomEngine de-duplicates
 *    against a component's own component_id (when present) so the real
 *    welcome scene's later component_render duplicates don't double-render.
 *
 * error events carry their message at `data.error` (a plain string), not
 * a top-level `message` field — also fixed here.
 */
sealed class ClassroomServerEvent {
    data class ComponentRenderEvent(val component: ClassroomComponent) : ClassroomServerEvent()

    /** `components` is non-empty for the ad-hoc fast-welcome shape (see
     *  class doc) and for the real welcome scene's embedded array — empty
     *  for a plain scene_start that carries no inline content, which is
     *  still a valid, common shape (mid-lesson scene transitions). */
    data class SceneStartEvent(val components: List<ClassroomComponent> = emptyList()) : ClassroomServerEvent()

    data object SceneCompleteEvent : ClassroomServerEvent()

    /** Acknowledged-but-currently-inert real event types (system_state,
     *  scene_update) — recognized explicitly so they're never mistaken for
     *  an unparseable/unknown message, even though nothing actionable is
     *  extracted from them yet. */
    data object IgnoredEvent : ClassroomServerEvent()

    data class ErrorEvent(val message: String?) : ClassroomServerEvent()
}

private val COMPONENT_RENDER_TYPES = setOf("component_render", "component_stream", "COMPONENT_RENDER")
private val SCENE_START_TYPES = setOf("scene_start", "scene_stream", "SCENE_START")
private val SCENE_COMPLETE_TYPES = setOf("scene_complete", "SCENE_COMPLETE")
private val SCENE_UPDATE_TYPES = setOf("scene_update", "SCENE_UPDATE")
private val SYSTEM_STATE_TYPES = setOf("system_state", "SYSTEM_STATE")
private val ERROR_TYPES = setOf("error", "ERROR")

fun parseServerEvent(raw: String): ClassroomServerEvent? {
    val root: JsonObject = try {
        JsonParser.parseString(raw).asJsonObject
    } catch (e: Exception) {
        return null
    }

    // The ad-hoc fast-welcome shape nests the REAL event type under
    // data.event_type; every other real shape carries it top-level as
    // event_type (the normal WebSocketPayload) or type (legacy/iOS-style).
    // Try top-level first, then the nested ad-hoc location, so a normal
    // envelope's own top-level "type"/"event_type" always wins if both
    // happen to be present.
    val dataObj = root.getAsJsonObject("data")
    val eventType = root.get("event_type")?.takeIf { it.isJsonPrimitive }?.asString
        ?: root.get("type")?.takeIf { it.isJsonPrimitive }?.asString
        ?: dataObj?.get("event_type")?.takeIf { it.isJsonPrimitive }?.asString
        ?: return null

    return when (eventType) {
        in COMPONENT_RENDER_TYPES -> {
            // Tried in this order: a top-level "component" (the common
            // case per ComponentRenderPayload.dict()), nested under
            // "data.component", or "data" itself being the component (a
            // defensive fallback for a shape variant we haven't observed
            // directly but can't rule out without live traffic).
            val componentJson = root.getAsJsonObject("component")
                ?: dataObj?.getAsJsonObject("component")
                ?: dataObj
                ?: return null
            parseComponent(componentJson)?.let { ClassroomServerEvent.ComponentRenderEvent(it) }
        }

        in SCENE_START_TYPES -> {
            val sceneObj = root.getAsJsonObject("scene")
                ?: dataObj?.getAsJsonObject("scene")
            val componentsArray = sceneObj?.getAsJsonArray("components")
            val components = componentsArray
                ?.mapNotNull { element -> if (element.isJsonObject) parseComponent(element.asJsonObject) else null }
                ?: emptyList()
            ClassroomServerEvent.SceneStartEvent(components)
        }

        in SCENE_COMPLETE_TYPES -> ClassroomServerEvent.SceneCompleteEvent
        in SCENE_UPDATE_TYPES -> ClassroomServerEvent.IgnoredEvent
        in SYSTEM_STATE_TYPES -> ClassroomServerEvent.IgnoredEvent

        in ERROR_TYPES -> ClassroomServerEvent.ErrorEvent(
            dataObj?.get("error")?.takeIf { it.isJsonPrimitive }?.asString
                ?: root.get("message")?.takeIf { it.isJsonPrimitive }?.asString
                ?: dataObj?.get("message")?.takeIf { it.isJsonPrimitive }?.asString,
        )

        else -> null
    }
}

private fun parseComponent(componentJson: JsonObject): ClassroomComponent? {
    val component = try {
        ApiClient.gson.fromJson(componentJson, ClassroomComponent::class.java)
    } catch (e: Exception) {
        null
    } ?: return null
    if (component.type.isNullOrEmpty()) return null
    return component
}
