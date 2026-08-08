package com.lyo.app.ui.classroom

import com.google.gson.JsonPrimitive
import com.lyo.app.data.a2ui.A2uiAction
import com.lyo.app.data.a2ui.A2uiMessage
import com.lyo.app.data.a2ui.resolvePointer
import com.lyo.app.data.classroom.DirectorTurn
import com.lyo.app.data.classroom.ExplorableParam
import com.lyo.app.data.classroom.isoTimestampNow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Turn-table and action-routing coverage for ClassroomBridge — the
 * stateless translator between the real backend's DirectorTurn/
 * ClassroomComponent wire contract and the generic A2UI message layer.
 * This is the file the operator-precedence bug (`as` binding tighter than
 * infix `to`, see git history) lived in, undetected by hand-tracing and a
 * real `kotlinc` type-check alike — kotlinc catches type errors, not wrong
 * *values*. These tests catch the latter: they replay a handful of the
 * turn-type table's rows and assert on the actual A2uiMessage values
 * produced, the same way the "representative round trip" in the
 * implementation plan was hand-verified once, except repeatable.
 */
class ClassroomBridgeTest {

    private fun dataModelWrites(messages: List<A2uiMessage>): Map<String, A2uiMessage.UpdateDataModel> =
        messages.filterIsInstance<A2uiMessage.UpdateDataModel>().associateBy { it.path }

    @Test
    fun `lyo_state turn writes mascot state and nothing else`() {
        val turn = DirectorTurn(type = "lyo_state", state = "celebrating")
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = emptyList())

        val writes = dataModelWrites(mutation.messages)
        assertEquals(1, mutation.messages.size)
        assertEquals(JsonPrimitive("celebrating"), writes.getValue("/mascot/state").value)
        assertTrue(mutation.boardChildren.isEmpty())
    }

    @Test
    fun `lyo_state turn with a missing state is a no-op`() {
        val turn = DirectorTurn(type = "lyo_state", state = null)
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = listOf("existing"))
        assertTrue(mutation.messages.isEmpty())
        assertEquals(listOf("existing"), mutation.boardChildren)
    }

    @Test
    fun `board explorable turn forwards expression, params, and the xMin-xMax axis range`() {
        // Regression test for the gap found while cross-checking against
        // LyoBackendJune's director_prompt.py schema: the DirectorTurn
        // carries x_min/x_max but the bridge originally never forwarded
        // them into the A2uiComponent's data-model writes.
        val turn = DirectorTurn(
            type = "board",
            action = "explorable",
            expression = "a * x^2 + b * x",
            x_min = -5.0,
            x_max = 5.0,
            prompt = "Slide a — what happens to the steepness?",
            params = listOf(ExplorableParam(name = "a", min = -3.0, max = 3.0, initial = 1.0, step = 0.1)),
        )
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = emptyList())

        assertEquals(1, mutation.boardChildren.size)
        val id = mutation.boardChildren.single()
        val writes = dataModelWrites(mutation.messages)

        assertEquals(JsonPrimitive("a * x^2 + b * x"), writes.getValue("/board/elements/$id/expression").value)
        assertEquals(JsonPrimitive(-5.0), writes.getValue("/board/elements/$id/xMin").value)
        assertEquals(JsonPrimitive(5.0), writes.getValue("/board/elements/$id/xMax").value)

        // The ExplorableBlock component itself must declare xMin/xMax as
        // bound properties (PathRefs), not just write them into the data
        // model with nothing reading them.
        val componentsMsg = mutation.messages.filterIsInstance<A2uiMessage.UpdateComponents>().single()
        val explorable = componentsMsg.components.single { it.id == id }
        assertTrue(explorable.properties?.containsKey("xMin") == true)
        assertTrue(explorable.properties?.containsKey("xMax") == true)
    }

    @Test
    fun `board explorable turn omits xMin-xMax as JsonNull when the director didn't send them`() {
        val turn = DirectorTurn(
            type = "board",
            action = "explorable",
            expression = "sin(x)",
            params = listOf(ExplorableParam(name = "a", min = 0.0, max = 1.0, initial = 0.5, step = 0.1)),
        )
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = emptyList())
        val id = mutation.boardChildren.single()
        val writes = dataModelWrites(mutation.messages)
        assertTrue(writes.getValue("/board/elements/$id/xMin").value?.isJsonNull != false)
        assertTrue(writes.getValue("/board/elements/$id/xMax").value?.isJsonNull != false)
    }

    @Test
    fun `board explorable turn with no params is dropped, not emitted half-built`() {
        val turn = DirectorTurn(type = "board", action = "explorable", expression = "x^2", params = null)
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = listOf("prior"))
        assertTrue(mutation.messages.isEmpty())
        assertEquals(listOf("prior"), mutation.boardChildren)
    }

    @Test
    fun `board highlight turn marks the last board element and also adds a spotlight`() {
        val turn = DirectorTurn(type = "board", action = "highlight", content = "3x")
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = listOf("chalk_1"))

        val writes = dataModelWrites(mutation.messages)
        assertEquals(JsonPrimitive("3x"), writes.getValue("/board/elements/chalk_1/highlightedTerm").value)

        // exactly one new board child (the spotlight) appended after the
        // pre-existing chalk_1
        assertEquals(2, mutation.boardChildren.size)
        assertEquals("chalk_1", mutation.boardChildren[0])
        assertTrue(mutation.boardChildren[1].startsWith("highlight_"))
    }

    @Test
    fun `board write turn classifies plain text as ChalkboardText`() {
        val turn = DirectorTurn(type = "board", action = "write", content = "speed = distance / time")
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = emptyList())
        val componentsMsg = mutation.messages.filterIsInstance<A2uiMessage.UpdateComponents>().single()
        val id = mutation.boardChildren.single()
        assertEquals("ChalkboardText", componentsMsg.components.single { it.id == id }.component)
    }

    @Test
    fun `board write turn classifies a mermaid diagram as MermaidBlock`() {
        val turn = DirectorTurn(type = "board", action = "draw", content = "graph TD\n  A --> B")
        val mutation = ClassroomBridge.directorTurnToA2ui(turn, boardChildren = emptyList())
        val componentsMsg = mutation.messages.filterIsInstance<A2uiMessage.UpdateComponents>().single()
        val id = mutation.boardChildren.single()
        assertEquals("MermaidBlock", componentsMsg.components.single { it.id == id }.component)
    }

    // ---- actionToUserAction ----

    private fun action(name: String, context: Map<String, com.google.gson.JsonElement>) = A2uiAction(
        name = name,
        surfaceId = ClassroomBridge.SURFACE_ID,
        sourceComponentId = "component_42",
        timestamp = isoTimestampNow(),
        context = context,
    )

    @Test
    fun `submitPrompt action prefers the explicit promptId over the source component id`() {
        val envelope = ClassroomBridge.actionToUserAction(
            action(
                "submitPrompt",
                mapOf(
                    "promptId" to JsonPrimitive("prompt_7"),
                    "selectedLabel" to JsonPrimitive("Got it"),
                ),
            ),
            sessionId = "sess_1",
        )
        assertEquals("prompt_7", envelope.component_id)
        assertEquals("user_message", envelope.action_intent)
        assertEquals("Got it", envelope.answer_data?.get("message"))
    }

    @Test
    fun `submitPrompt action falls back to the free-typed value when no chip label was selected`() {
        val envelope = ClassroomBridge.actionToUserAction(
            action("submitPrompt", mapOf("promptId" to JsonPrimitive("prompt_7"), "value" to JsonPrimitive("my own answer"))),
            sessionId = "sess_1",
        )
        assertEquals("my own answer", envelope.answer_data?.get("message"))
    }

    @Test
    fun `submitTransfer action threads the actionIntent context key instead of overloading action name`() {
        // Regression test for the "dropped action_intent" bug documented in
        // this session's implementation history: a custom backend intent
        // must survive the round trip via the separate actionIntent key,
        // not get silently discarded because action.name is always
        // "submitTransfer" at the routing layer.
        val envelope = ClassroomBridge.actionToUserAction(
            action(
                "submitTransfer",
                mapOf(
                    "actionIntent" to JsonPrimitive("custom_backend_intent"),
                    "response" to JsonPrimitive("my answer"),
                ),
            ),
            sessionId = "sess_1",
        )
        assertEquals("custom_backend_intent", envelope.action_intent)
        assertEquals("component_42", envelope.component_id)
        assertEquals("my answer", envelope.answer_data?.get("response"))
    }

    @Test
    fun `submitTransfer action defaults actionIntent when the backend didn't send a custom one`() {
        val envelope = ClassroomBridge.actionToUserAction(
            action("submitTransfer", mapOf("response" to JsonPrimitive("42"))),
            sessionId = "sess_1",
        )
        assertEquals("submit_transfer", envelope.action_intent)
    }

    @Test
    fun `unrecognized action names pass through as their own action_intent rather than crashing`() {
        val envelope = ClassroomBridge.actionToUserAction(action("someFutureAction", emptyMap()), sessionId = "sess_1")
        assertEquals("someFutureAction", envelope.action_intent)
        assertNull(envelope.answer_data)
    }

    @Test
    fun `initial surface data model round-trips through resolvePointer`() {
        val surface = ClassroomBridge.createInitialSurface()
        assertEquals(JsonPrimitive("reading"), surface.dataModel?.resolvePointer("/mascot/state"))
        assertEquals(JsonPrimitive(false), surface.dataModel?.resolvePointer("/canContinue"))
    }
}
