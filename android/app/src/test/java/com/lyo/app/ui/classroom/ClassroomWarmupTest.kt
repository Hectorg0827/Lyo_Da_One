package com.lyo.app.ui.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The waiting-room activity never claims a grade or requires server data. */
class ClassroomWarmupTest {
    @Test
    fun `science opens with a fair test challenge`() {
        val prompt = warmupFor("Science")
        assertEquals(2, prompt.choices.size)
        assertEquals("Only the amount of water", prompt.choices[prompt.correctIndex])
        assertTrue(prompt.explanation.contains("one variable"))
    }

    @Test
    fun `unknown topic still has a safe general reasoning activity`() {
        val prompt = warmupFor("Music theory")
        assertEquals(2, prompt.choices.size)
        assertEquals(0, prompt.correctIndex)
        assertTrue(prompt.explanation.contains("understanding"))
    }

    @Test
    fun `history and mathematics have stable prompts`() {
        assertEquals(0, warmupFor("World History").correctIndex)
        assertEquals(0, warmupFor("Fractions").correctIndex)
    }
}
