package com.lyo.app.ui.classroom

import com.google.gson.JsonParser
import com.lyo.app.data.classroom.ClassroomComponent
import com.lyo.app.data.classroom.parseBoardDocument
import com.lyo.app.data.classroom.presentationRole
import com.lyo.app.data.a2ui.A2uiMessage
import org.junit.Assert.*
import org.junit.Test

class BoardPresentationTest {
    @Test fun `different subjects use the same tools and preserve code indentation`() {
        val json = JsonParser.parseString("""{"version":1,"blocks":[{"kind":"steps","items":["Subtract 5","Divide by 3"]},{"kind":"code","language":"python","text":"    return total"},{"kind":"table","headers":["Term","Meaning"],"rows":[["Bonjour","Hello"]]}]}""")
        val document = parseBoardDocument(json)!!
        assertEquals(listOf("steps", "code", "table"), document.blocks.map { it.kind })
        assertEquals("    return total", document.blocks[1].text)
    }

    @Test fun `malformed or future documents degrade to the existing full content`() {
        listOf(
            """{"version":2,"blocks":[{"kind":"text","text":"Future"}]}""",
            """{"version":1,"blocks":[{"kind":"table","headers":["A","B"],"rows":[["A only"]]}]}""",
            """{"version":1,"blocks":[{"kind":"steps","items":[42]}]}""",
            """{"version":1,"blocks":[{"kind":"script","text":"execute()"}]}""",
        ).forEach { assertNull(parseBoardDocument(JsonParser.parseString(it))) }
    }

    @Test fun `bridge carries the document beside the fallback without an answer action`() {
        val json = JsonParser.parseString("""{"version":1,"blocks":[{"kind":"text","text":"An anchor."}]}""")
        val component = ClassroomComponent(component_id = "board:step", type = "ExampleBlock", title = "Observe", content = "Full legacy content", board_document = json, presentation_role = "board")
        val mutation = ClassroomBridge.onImmediateComponentRender(component, emptyList())
        val writes = mutation.messages.filterIsInstance<A2uiMessage.UpdateDataModel>().associateBy { it.path }
        assertEquals(json, writes.getValue("/board/elements/summary_board:step/document").value)
        assertEquals("Full legacy content", writes.getValue("/board/elements/summary_board:step/content").value.asString)
        assertFalse(writes.containsKey("/canContinue"))
        assertEquals("reference", ClassroomComponent(component_id = "memory-visual:earlier").presentationRole())
    }

    @Test fun `legacy recovery notice marks a paused lesson`() {
        val component = ClassroomComponent(component_id = "classroom-recovery/notice", type = "ExampleBlock", content = "Retry to carry on")
        val mutation = ClassroomBridge.onImmediateComponentRender(component, emptyList())
        val paused = mutation.messages.filterIsInstance<A2uiMessage.UpdateDataModel>().single { it.path == "/lessonRecovery" }
        assertTrue(paused.value.asBoolean)
    }
}
