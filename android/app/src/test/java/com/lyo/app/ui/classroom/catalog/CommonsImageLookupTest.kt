package com.lyo.app.ui.classroom.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommonsImageLookupTest {
    @Test fun acceptsOnlyRealCommonsHttpsImages() {
        assertEquals(
            "https://upload.wikimedia.org/wikipedia/commons/a/a3/test.png",
            safeCommonsImageUrl("https://upload.wikimedia.org/wikipedia/commons/a/a3/test.png"),
        )
        assertNull(safeCommonsImageUrl("https://upload.wikimedia.org.evil.example/test.png"))
        assertNull(safeCommonsImageUrl("http://upload.wikimedia.org/test.png"))
        assertNull(safeCommonsImageUrl("https://evil.test/"))
    }

    @Test fun readsValidatedImageAndTitleFromCommonsResponse() {
        val result = parseCommonsClassroomImage(
            """{"query":{"pages":{"1":{"title":"File:Neuron.png","imageinfo":[{"thumburl":"https://upload.wikimedia.org/test.png"}]}}}}""",
        )
        assertEquals("https://upload.wikimedia.org/test.png", result?.url)
        assertEquals("Neuron.png", result?.attribution)
    }

    @Test fun rejectsUnknownImageHostFromCommonsResult() {
        val result = parseCommonsClassroomImage(
            """{"query":{"pages":{"1":{"title":"File:Bad.png","imageinfo":[{"thumburl":"https://attacker.example/evil.png"}]}}}}""",
        )
        assertNull(result)
    }
}
