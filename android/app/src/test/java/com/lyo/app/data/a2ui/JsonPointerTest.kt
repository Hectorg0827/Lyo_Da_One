package com.lyo.app.data.a2ui

import com.google.gson.JsonArray
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * RFC 6901 resolve/set coverage for JsonPointer.kt — the data-binding
 * mechanism every A2uiValue.PathRef and every ClassroomBridge data-model
 * write goes through. A wrong pointer segment here silently renders "nothing"
 * (per the file's own resilience-over-crash design), so it's easy for a
 * regression to hide until someone notices a blank chip/panel on screen —
 * exactly the kind of thing a real compile can't catch (JsonPointer.kt
 * compiled clean under kotlinc this session; these tests check behavior,
 * not just types).
 */
class JsonPointerTest {

    // ---- resolvePointer ----

    @Test
    fun `resolves a nested object path`() {
        val root = JsonObject().apply {
            add("board", JsonObject().apply {
                add("elements", JsonObject().apply {
                    add("panel_1", JsonObject().apply { addProperty("text", "hello") })
                })
            })
        }
        val resolved = root.resolvePointer("/board/elements/panel_1/text")
        assertEquals(JsonPrimitive("hello"), resolved)
    }

    @Test
    fun `resolves an array index segment`() {
        val root = JsonObject().apply {
            add("items", JsonArray().apply { add("a"); add("b"); add("c") })
        }
        assertEquals(JsonPrimitive("b"), root.resolvePointer("/items/1"))
    }

    @Test
    fun `root pointer forms return the element itself`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        assertEquals(root, root.resolvePointer(""))
        assertEquals(root, root.resolvePointer("/"))
    }

    @Test
    fun `missing key returns null instead of throwing`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        assertNull(root.resolvePointer("/does/not/exist"))
    }

    @Test
    fun `out-of-range array index returns null instead of throwing`() {
        val root = JsonObject().apply { add("items", JsonArray().apply { add("a") }) }
        assertNull(root.resolvePointer("/items/5"))
        assertNull(root.resolvePointer("/items/-1"))
    }

    @Test
    fun `non-numeric segment against an array returns null instead of throwing`() {
        val root = JsonObject().apply { add("items", JsonArray().apply { add("a") }) }
        assertNull(root.resolvePointer("/items/notAnIndex"))
    }

    @Test
    fun `descending into a primitive returns null instead of throwing`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        assertNull(root.resolvePointer("/x/y"))
    }

    @Test
    fun `unescapes tilde and slash per RFC 6901`() {
        // "~1" -> "/", "~0" -> "~" — a key literally named "a/b" is encoded
        // as "a~1b" in the pointer; "a~b" is encoded as "a~0b".
        val root = JsonObject().apply {
            add("a/b", JsonPrimitive("slash-key"))
            add("a~b", JsonPrimitive("tilde-key"))
        }
        assertEquals(JsonPrimitive("slash-key"), root.resolvePointer("/a~1b"))
        assertEquals(JsonPrimitive("tilde-key"), root.resolvePointer("/a~0b"))
    }

    // ---- setPointer ----

    @Test
    fun `setPointer creates intermediate objects as needed`() {
        val root = JsonObject()
        root.setPointer("/board/elements/panel_1/text", JsonPrimitive("hi"))
        assertEquals(JsonPrimitive("hi"), root.resolvePointer("/board/elements/panel_1/text"))
    }

    @Test
    fun `setPointer reuses an existing intermediate object rather than clobbering siblings`() {
        val root = JsonObject()
        root.setPointer("/board/elements/panel_1/text", JsonPrimitive("hi"))
        root.setPointer("/board/elements/panel_1/open", JsonPrimitive(true))
        assertEquals(JsonPrimitive("hi"), root.resolvePointer("/board/elements/panel_1/text"))
        assertEquals(JsonPrimitive(true), root.resolvePointer("/board/elements/panel_1/open"))
    }

    @Test
    fun `setPointer with a null value deletes the key`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        root.setPointer("/x", null)
        assertTrue(root.resolvePointer("/x") == null || root.get("x") == null)
        assertNull(root.get("x"))
    }

    @Test
    fun `setPointer with JsonNull also deletes the key (upsert semantics)`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        root.setPointer("/x", JsonNull.INSTANCE)
        assertNull(root.get("x"))
    }

    @Test
    fun `setPointer with an empty pointer is a no-op`() {
        val root = JsonObject().apply { addProperty("x", 1) }
        root.setPointer("", JsonPrimitive("ignored"))
        assertEquals(JsonPrimitive(1), root.get("x"))
        assertEquals(1, root.entrySet().size)
    }

    @Test
    fun `setPointer overwrites a non-object intermediate rather than crashing`() {
        // If a prior write left a primitive at a path segment that later
        // needs to become an object, setPointer must replace it, not throw.
        val root = JsonObject().apply { addProperty("board", "not-an-object-yet") }
        root.setPointer("/board/elements/panel_1/text", JsonPrimitive("hi"))
        assertEquals(JsonPrimitive("hi"), root.resolvePointer("/board/elements/panel_1/text"))
    }
}
