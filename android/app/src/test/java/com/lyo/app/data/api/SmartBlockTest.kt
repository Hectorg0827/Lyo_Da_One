package com.lyo.app.data.api

import com.google.gson.GsonBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Coverage for SmartBlockDeserializer — the hand-written Gson routing that
 * gets a `content` object to the right typed payload based on the sibling
 * `type` field (Gson has no native sealed-class polymorphism). A mismatch
 * here silently drops or misreads a lesson beat rather than crashing, which
 * is exactly the kind of thing worth pinning down with real wire-shaped
 * JSON rather than trusting the implementation by inspection — same
 * reasoning ExpressionEvaluatorTest gives for the plot parser.
 */
class SmartBlockTest {

    private val gson = GsonBuilder()
        .registerTypeAdapter(SmartBlock::class.java, SmartBlockDeserializer())
        .create()

    private fun decode(json: String): SmartBlock = gson.fromJson(json, SmartBlock::class.java)

    @Test
    fun `decodes a text block with subtype`() {
        val block = decode(
            """{"id":"b1","type":"text","subtype":"callout","content":{"text":"Watch the sign.","style":"callout"}}""",
        )
        assertEquals("b1", block.id)
        assertEquals(SmartBlockType.TEXT, block.type)
        assertEquals("callout", block.subtype)
        val content = block.content as SmartBlockContent.Text
        assertEquals("Watch the sign.", content.payload.text)
    }

    @Test
    fun `decodes a quiz block including bailout and options`() {
        val block = decode(
            """
            {
              "id": "q1",
              "type": "quiz",
              "content": {
                "question": "What is the square root of 49?",
                "options": [
                  {"id": "0", "text": "7"},
                  {"id": "1", "text": "9", "reveals": "confusing the root with a nearby square"},
                  {"id": "2", "text": "Not sure — just explain it"}
                ],
                "correct_index": 0,
                "explanation": "7 x 7 = 49.",
                "bailout_index": 2
              },
              "metadata": {"skill_id": "square_roots"}
            }
            """.trimIndent(),
        )
        val content = block.content as SmartBlockContent.Quiz
        assertEquals("What is the square root of 49?", content.payload.question)
        assertEquals(3, content.payload.options.size)
        assertEquals("confusing the root with a nearby square", content.payload.options[1].reveals)
        assertEquals(0, content.payload.correctIndex)
        assertEquals(2, content.payload.bailoutIndex)
        assertEquals("square_roots", block.metadata?.get("skill_id")?.asString)
    }

    @Test
    fun `decodes dataViz camelCase type directly`() {
        val block = decode(
            """{"id":"d1","type":"dataViz","content":{"format":"mermaid","source":"graph TD; A-->B;"}}""",
        )
        assertEquals(SmartBlockType.DATA_VIZ, block.type)
        val content = block.content as SmartBlockContent.DataViz
        assertEquals("mermaid", content.payload.format)
    }

    @Test
    fun `decodes a snake_case type as its camelCase equivalent`() {
        // Defensive: the backend's contract is camelCase (dataViz), but
        // decoding must not break if a snake_case variant ever appears.
        val block = decode(
            """{"id":"d2","type":"data_viz","content":{"format":"table","source":"| a | b |"}}""",
        )
        assertEquals(SmartBlockType.DATA_VIZ, block.type)
    }

    @Test
    fun `decodes masteryMap nodes`() {
        val block = decode(
            """
            {
              "id": "m1",
              "type": "masteryMap",
              "content": {
                "title": "Algebra I",
                "nodes": [
                  {"node_id": "n1", "title": "Linear equations", "status": "completed", "mastery_level": 0.92},
                  {"node_id": "n2", "title": "Quadratics", "status": "locked"}
                ]
              }
            }
            """.trimIndent(),
        )
        val content = block.content as SmartBlockContent.MasteryMap
        assertEquals("Algebra I", content.payload.title)
        assertEquals(2, content.payload.nodes.size)
        assertEquals("completed", content.payload.nodes[0].status)
        assertEquals(0.92, content.payload.nodes[0].masteryLevel!!, 1e-9)
        assertNull(content.payload.nodes[1].masteryLevel)
    }

    @Test
    fun `an unrecognized type decodes to Unknown rather than throwing`() {
        val block = decode(
            """{"id":"u1","type":"holographicProjection","content":{"anything":"goes here"}}""",
        )
        assertEquals(SmartBlockType.UNKNOWN, block.type)
        assertTrue(block.content is SmartBlockContent.Unknown)
    }

    @Test
    fun `a field whose JSON type cannot coerce to its declared type falls back to Unknown, not a crash`() {
        // correct_index as a string Gson can't parse as Int throws
        // JsonSyntaxException mid-decode (verified directly against gson
        // 2.11.0, the version this project pins) — the whole point of
        // wrapping every per-type decode in try/catch is that this must
        // fail closed to Unknown, never take the rest of the message down.
        val block = decode(
            """{"id":"q2","type":"quiz","content":{"question":"hi","correct_index":"not a number"}}""",
        )
        assertEquals(SmartBlockType.QUIZ, block.type)
        assertTrue(block.content is SmartBlockContent.Unknown)
    }

    @Test
    fun `missing id and schema_version fall back to sensible defaults`() {
        val block = decode("""{"type":"text","content":{"text":"hi"}}""")
        assertTrue(block.id.isNotBlank())
        assertEquals(1, block.schemaVersion)
    }
}
