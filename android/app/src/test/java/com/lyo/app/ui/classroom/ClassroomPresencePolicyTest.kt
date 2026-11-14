package com.lyo.app.ui.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassroomPresencePolicyTest {
    @Test
    fun `working student receives the full canvas when nobody is speaking`() {
        val presence = ClassroomPresencePolicy.decide(
            speaker = null,
            learnerWorking = true,
            paused = false,
            supportCue = false,
            celebrationCue = false,
            captionsEnabled = true,
        )
        assertEquals(ClassroomPresence(false, false, false), presence)
    }

    @Test
    fun `teacher enters for the explanation and caption is optional`() {
        val speaking = ClassroomPresencePolicy.decide("Teacher", true, false, false, false, true)
        assertTrue(speaking.teacher)
        assertFalse(speaking.companion)
        assertTrue(speaking.caption)
        val captionsOff = ClassroomPresencePolicy.decide("Teacher", false, false, false, false, false)
        assertTrue(captionsOff.teacher)
        assertFalse(captionsOff.caption)
    }

    @Test
    fun `Lyo appears for a help cue and celebration then recedes`() {
        assertTrue(ClassroomPresencePolicy.decide(null, false, false, true, false, true).companion)
        assertTrue(ClassroomPresencePolicy.decide(null, false, false, false, true, true).companion)
        assertFalse(ClassroomPresencePolicy.decide(null, false, false, false, false, true).companion)
        assertTrue(ClassroomPresencePolicy.decide("Lyo", false, false, false, false, true).companion)
        assertFalse(ClassroomPresencePolicy.decide("Lyo", false, false, false, false, true).teacher)
    }

    @Test
    fun `pausing hides stale speaking character`() {
        val paused = ClassroomPresencePolicy.decide("Teacher", false, true, false, false, true)
        assertFalse(paused.teacher)
        assertFalse(paused.caption)
    }

    @Test
    fun `lesson duration is deliberately thirty minutes by default`() {
        assertEquals(30, ClassroomLessonDuration.default)
        assertEquals(30, ClassroomLessonDuration.normalize(10))
        assertEquals(45, ClassroomLessonDuration.normalize(45))
        assertEquals(listOf(15, 30, 45), ClassroomLessonDuration.choices)
    }
}
