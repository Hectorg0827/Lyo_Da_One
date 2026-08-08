package com.lyo.app.data.classroom

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyo.app.data.api.ApiClient

/**
 * One parsed message from the classroom WebSocket. Mirrors the envelope
 * dispatch in web/src/stores/classroom-store.ts's `handleMessage` — the web
 * contract only recognizes `component_render`/`scene_start`/
 * `scene_complete`/`error`, but this parser is deliberately as permissive as
 * iOS's `LivingClassroomService` (Sources/Services/LivingClassroomService.swift),
 * which additionally tolerates `scene_stream`/`component_stream` synonyms
 * and uppercase legacy variants — both keyed off `type` OR `event_type`, and
 * a component payload nested at `component`, `data.component`, or `data`
 * itself. An unrecognized message is dropped (`parseServerEvent` returns
 * null), matching both platforms' silent-ignore behavior for unknown types.
 */
sealed class ClassroomServerEvent {
    data class ComponentRenderEvent(val component: ClassroomComponent) : ClassroomServerEvent()
    data object SceneStartEvent : ClassroomServerEvent()
    data object SceneCompleteEvent : ClassroomServerEvent()
    data class ErrorEvent(val message: String?) : ClassroomServerEvent()
}

private val COMPONENT_RENDER_TYPES = setOf("component_render", "component_stream", "COMPONENT_RENDER")
private val SCENE_START_TYPES = setOf("scene_start", "scene_stream", "SCENE_START")
private val SCENE_COMPLETE_TYPES = setOf("scene_complete", "SCENE_COMPLETE")
private val ERROR_TYPES = setOf("error", "ERROR")

fun parseServerEvent(raw: String): ClassroomServerEvent? {
    val root: JsonObject = try {
        JsonParser.parseString(raw).asJsonObject
    } catch (e: Exception) {
        return null
    }

    val eventType = root.get("event_type")?.takeIf { it.isJsonPrimitive }?.asString
        ?: root.get("type")?.takeIf { it.isJsonPrimitive }?.asString
        ?: return null

    return when (eventType) {
        in COMPONENT_RENDER_TYPES -> {
            val componentJson = root.getAsJsonObject("component")
                ?: root.getAsJsonObject("data")?.getAsJsonObject("component")
                ?: root.getAsJsonObject("data")
                ?: return null
            val component = try {
                ApiClient.gson.fromJson(componentJson, ClassroomComponent::class.java)
            } catch (e: Exception) {
                null
            } ?: return null
            if (component.type.isNullOrEmpty()) return null
            ClassroomServerEvent.ComponentRenderEvent(component)
        }

        in SCENE_START_TYPES -> ClassroomServerEvent.SceneStartEvent
        in SCENE_COMPLETE_TYPES -> ClassroomServerEvent.SceneCompleteEvent
        in ERROR_TYPES -> ClassroomServerEvent.ErrorEvent(
            root.get("message")?.takeIf { it.isJsonPrimitive }?.asString,
        )

        else -> null
    }
}
