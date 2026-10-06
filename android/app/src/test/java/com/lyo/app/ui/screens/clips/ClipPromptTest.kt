package com.lyo.app.ui.screens.clips

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the app says when a learner finishes something.
 *
 * This copy is shown on three platforms and the length it promises is
 * enforced by the recorder, so the strings and the number are a contract, not
 * decoration. `ClipPromptTests.swift` and `teach-it.test.mjs` assert the same
 * things.
 */
class ClipPromptTest {

    @Test
    fun `a known topic is named in the invitation`() {
        assertEquals(
            "You just finished Organic Chemistry. Teach it in 60 seconds?",
            ClipPrompt.invitation("Organic Chemistry"),
        )
    }

    @Test
    fun `an unknown topic is not invented`() {
        // A prompt that confidently names the wrong course is worse than one
        // that names none.
        val generic = "Teach what you just learned in 60 seconds?"
        assertEquals(generic, ClipPrompt.invitation(null))
        assertEquals(generic, ClipPrompt.invitation(""))
        assertEquals(generic, ClipPrompt.invitation("   "))
    }

    @Test
    fun `the draft title is left empty when the topic is unknown`() {
        // A title the learner did not write gets published under their name.
        assertEquals("What I learned about Spanish B1", ClipPrompt.draftTitle("Spanish B1"))
        assertNull(ClipPrompt.draftTitle(null))
        assertNull(ClipPrompt.draftTitle("  "))
    }

    @Test
    fun `the draft subject is the trimmed topic or nothing`() {
        assertEquals("Statistics", ClipPrompt.draftSubject("  Statistics  "))
        assertNull(ClipPrompt.draftSubject(""))
    }

    @Test
    fun `the promised length is the one the recorder enforces`() {
        assertEquals(60, ClipPrompt.QUICK_TAKE_SECONDS)
        assertTrue(ClipPrompt.invitation("Algebra").contains("60 seconds"))
        assertEquals("Teach it", ClipPrompt.CALL_TO_ACTION)
    }
}
