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
        for (name in listOf("orientation", "focused_example", "model_1", "model_2", "guided")) {
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

    @Test fun `the opening probe renders as one tap with no worked example and no continue`() {
        // A unit opens by finding out where the learner is, before anything is
        // taught, and it asks with one tap: a learner who has never met the
        // skill can still answer it. It reaches Android through the components
        // Android already renders, which is why the opening needed no client
        // change — only this fixture regenerated. These assertions keep it so.
        val components = fixture().getAsJsonObject("scenes").getAsJsonObject("diagnostic")
            .getAsJsonArray("components").map { gson.fromJson(it, ClassroomComponent::class.java) }

        var board = emptyList<String>()
        val rendered = mutableListOf<com.lyo.app.data.a2ui.A2uiComponent>()
        for (component in components) {
            val mutation = ClassroomBridge.onImmediateComponentRender(component, board)
            board = mutation.boardChildren
            rendered += mutation.messages.filterIsInstance<A2uiMessage.UpdateComponents>().flatMap { it.components }
        }

        // The learner is asked something, and one tap answers it.
        assertTrue(rendered.any { it.component == "QuizCard" })
        assertFalse(rendered.any { it.component == "TransferInput" })
        // Four options: the answer, two named misconceptions, and somewhere to
        // say "not sure yet", so not knowing never forces a guess.
        val options = components.single { it.type == "QuizCard" }.options!!
        assertEquals(4, options.size)
        // No key on the device while the learner is still deciding. Android
        // reads a null is_correct as a neutral selection, and its feedback
        // lookup must find nothing to tell them either way.
        assertTrue(options.all { it.is_correct == null })
        assertTrue(options.all { it.feedback_correct == null && it.feedback_incorrect == null })
        // Nor the misconception each distractor reveals: that is the server's
        // diagnosis, made for the next teaching turn, not for the person still
        // choosing.
        assertTrue(options.all { it.misconception_tag == null })
        // One teacher line, then the floor is the learner's.
        assertEquals(1, components.count { it.type == "TeacherMessage" })
        // A Continue here would make answering optional, which is the
        // monologue with an extra tap.
        assertTrue(components.none { it.type == "CTAButton" })
        // No teaching visual either: the comparison tool's own description
        // explains why the answer is the answer, and a probe's board may carry
        // the situation but never the reasoning.
        assertTrue(components.none { it.block_type == "teaching_visual" })
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
    @Test fun `Classroom accepts approved education media and attribution domains`() {
        val sources = listOf(
            "https://upload.wikimedia.org/wikipedia/commons/leaf.jpg" to "https://commons.wikimedia.org/wiki/File:Leaf.jpg",
            "https://images.pexels.com/photos/1/photo.jpeg" to "https://www.pexels.com/photo/green-leaf-1/",
            "https://images-assets.nasa.gov/image/PIA1/thumb.jpg" to "https://images.nasa.gov/details/PIA1",
            "https://ids.si.edu/ids/deliveryService?id=ABC" to "https://www.si.edu/object/edanmdm-x",
        )
        sources.forEach { (media, source) ->
            assertTrue(ClassroomBlock(
                kind = "annotated_image", image_query = "leaf",
                image_url = media, source_url = source,
            ).isTeachingVisualValid())
        }
    }

    @Test fun `Classroom rejects spoofed visual hosts and invalid URL schemes`() {
        val safe = ClassroomBlock(
            kind = "annotated_image", image_query = "leaf",
            image_url = "https://images.pexels.com/photos/1/photo.jpeg",
            source_url = "https://www.pexels.com/photo/leaf-1/",
        )
        assertTrue(safe.isTeachingVisualValid())
        assertFalse(safe.copy(image_url = "https://images.pexels.com.attacker.test/a.jpg").isTeachingVisualValid())
        assertFalse(safe.copy(image_url = "https://images.pexels.com/%").isTeachingVisualValid())
        assertFalse(safe.copy(source_url = "https://www.pexels.com/%").isTeachingVisualValid())
        assertFalse(safe.copy(image_url = "http://images.pexels.com/photos/a.jpg").isTeachingVisualValid())
        assertFalse(safe.copy(image_url = "https://bad.test@images.pexels.com/a.jpg").isTeachingVisualValid())
        assertFalse(safe.copy(source_url = "https://www.pexels.com.evil.test/photo").isTeachingVisualValid())
        assertFalse(safe.copy(source_url = "https://images-assets.nasa.gov/image/1.jpg").isTeachingVisualValid())
    }

}
