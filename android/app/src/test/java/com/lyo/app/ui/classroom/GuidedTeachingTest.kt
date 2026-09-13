package com.lyo.app.ui.classroom

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.classroom.ClassroomBlock
import com.lyo.app.data.classroom.ClassroomComponent
import com.lyo.app.data.classroom.isTeachingVisualValid
import org.junit.Assert.*
import org.junit.Test

class GuidedTeachingTest {
    private val gson = Gson()
    private fun fixture(): JsonObject = javaClass.getResourceAsStream("/GuidedTeaching.json")!!.bufferedReader().use {
        JsonParser.parseReader(it).asJsonObject
    }

    @Test fun `public teaching tools preserve their validated saved values`() {
        val visuals = fixture().getAsJsonArray("visuals").map { gson.fromJson(it, ClassroomBlock::class.java) }
        assertEquals(setOf("fraction_bar", "comparison", "sequence", "graph"), visuals.map { it.kind }.toSet())
        visuals.forEach {
            assertTrue(it.isTeachingVisualValid())
            assertEquals(it, gson.fromJson(gson.toJson(it), ClassroomBlock::class.java))
        }
        assertFalse(visuals[0].copy(value = 20).isTeachingVisualValid())
        assertFalse(visuals[3].copy(y_min = 10.0, y_max = -10.0).isTeachingVisualValid())
    }

    @Test fun `modelled example and visual survive alongside a canonical Continue action`() {
        val scenes = fixture().getAsJsonObject("scenes")
        for (name in listOf("orientation", "model_1", "model_2", "guided")) {
            val components = scenes.getAsJsonObject(name).getAsJsonArray("components").map {
                gson.fromJson(it, ClassroomComponent::class.java)
            }
            var board = emptyList<String>()
            val rendered = mutableListOf<com.lyo.app.data.a2ui.A2uiComponent>()
            for (component in components) {
                val mutation = ClassroomBridge.onImmediateComponentRender(component, board)
                board = mutation.boardChildren
                rendered += mutation.messages.filterIsInstance<A2uiMessage.UpdateComponents>().flatMap { it.components }
            }
            val visual = components.single { it.block_type == "teaching_visual" }
            assertTrue(rendered.any { it.id == visual.component_id && it.component == "TeachingVisual" })
            if (name == "guided") {
                assertTrue(rendered.any { it.component == "QuizCard" })
            } else {
                assertFalse(rendered.any { it.component == "QuizCard" || it.component == "TransferInput" })
                val cta = components.single { it.type == "CTAButton" }
                val envelope = ClassroomBridge.continueLessonAction("fixture", "continue", cta.component_id!!)
                assertEquals(cta.component_id, envelope.component_id)
            }
        }
    }

    @Test fun `exploration sends bounded values without a grading or continue action`() {
        val action = A2uiAction(name = "update_activity", surfaceId = ClassroomBridge.SURFACE_ID,
            sourceComponentId = "visual:step-1", timestamp = "2026-01-01T00:00:00Z",
            context = mapOf("value" to JsonPrimitive(3)))
        val envelope = ClassroomBridge.actionToUserAction(action, "fixture")
        assertEquals("update_activity", envelope.action_intent)
        assertEquals("visual:step-1", envelope.component_id)
        assertEquals(mapOf("value" to 3), envelope.answer_data)
        val params = JsonObject().apply { addProperty("a", 2.0) }
        val graph = ClassroomBridge.actionToUserAction(action.copy(context = mapOf("params" to params)), "fixture")
        assertEquals(mapOf("params" to mapOf("a" to 2.0)), graph.answer_data)
    }
}
