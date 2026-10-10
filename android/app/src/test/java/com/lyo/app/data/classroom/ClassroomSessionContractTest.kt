package com.lyo.app.data.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import com.google.gson.Gson

/**
 * The rules that decide whether a class starts or resumes, and when a wait
 * stops claiming the next step is coming.
 *
 * Asserted on every platform against the same numbers and the same copy — see
 * `web/src/lib/classroom-contract.test.mjs`, iOS's
 * `ClassroomSessionContractTests`, and the parity gate that holds the three
 * together.
 */
class ClassroomSessionContractTest {
    @Test
    fun `guided completion metadata marks the matching seat finished`() {
        val start = ClassroomSessionContract.sessionStart("fractions", null)
        ClassroomSessionStore.save(
            ClassroomSavedSession(start.sessionId, System.currentTimeMillis(), start.generation), "fractions",
        )
        val metadata = Gson().fromJson("{\"course_complete\":true}", ClassroomSceneMetadata::class.java)
        assertTrue(metadata.course_complete)
        ClassroomSessionStore.markFinished(start.sessionId, "fractions")
        assertFalse(ClassroomSessionContract.canResume(ClassroomSessionStore.saved("fractions")))
        assertFalse(Gson().fromJson("{}", ClassroomSceneMetadata::class.java).course_complete)
    }


    @Before
    fun reset() {
        ClassroomSessionStore.clearForTests()
    }

    // ── Starting a class, and starting it over ────────────────────────────

    @Test
    fun `first class sends the id every client always sent`() {
        val start = ClassroomSessionContract.sessionStart("course-7", null)
        assertEquals("course-7", start.sessionId)
        assertEquals(1, start.generation)
        assertFalse(start.resumed)
    }

    @Test
    fun `opening the same topic again is a new class`() {
        val first = ClassroomSessionContract.sessionStart("Minecraft", null)
        val second = ClassroomSessionContract.sessionStart(
            "Minecraft",
            ClassroomSavedSession(first.sessionId, System.currentTimeMillis(), first.generation),
        )
        assertNotEquals(first.sessionId, second.sessionId)
        assertEquals(2, second.generation)
        assertFalse(second.resumed)

        val third = ClassroomSessionContract.sessionStart(
            "Minecraft",
            ClassroomSavedSession(second.sessionId, System.currentTimeMillis(), second.generation),
        )
        assertNotEquals(second.sessionId, third.sessionId)
    }

    @Test
    fun `resuming is honoured only when the learner asks for it`() {
        val saved = ClassroomSavedSession("course-7~2", System.currentTimeMillis(), 2)
        val resumed = ClassroomSessionContract.sessionStart("course-7", saved, resume = true)
        assertEquals("course-7~2", resumed.sessionId)
        assertTrue(resumed.resumed)

        val fresh = ClassroomSessionContract.sessionStart("course-7", saved)
        assertEquals("course-7~3", fresh.sessionId)
        assertFalse(fresh.resumed)
    }

    @Test
    fun `a class too old to remember sitting is started not resumed`() {
        val now = System.currentTimeMillis()
        val stale = ClassroomSavedSession(
            "course-7~2",
            now - ClassroomSessionContract.RESUME_WINDOW_MS - 1,
            2,
        )
        assertFalse(ClassroomSessionContract.canResume(stale, now))
        val start = ClassroomSessionContract.sessionStart("course-7", stale, resume = true, now = now)
        assertFalse(start.resumed)
        assertEquals("course-7~3", start.sessionId)
    }

    @Test
    fun `free topic entries find their own history`() {
        assertEquals(
            "Minecraft",
            ClassroomSessionContract.courseKey("GENERATE:Minecraft", "Minecraft"),
        )
        assertEquals("Minecraft", ClassroomSessionContract.courseKey(null, "Minecraft"))
        assertEquals("general", ClassroomSessionContract.courseKey(null, null))
        assertEquals(
            "lyo_classroom_session:course-7",
            ClassroomSessionContract.storageKey("course-7"),
        )
    }

    @Test
    fun `the store round trips a seat without leaking between courses`() {
        assertNull(ClassroomSessionStore.saved("course-7"))
        val seat = ClassroomSavedSession("course-7~2", 1_700_000_000_000L, 2)
        ClassroomSessionStore.save(seat, "course-7")
        assertEquals(seat, ClassroomSessionStore.saved("course-7"))
        assertNull(ClassroomSessionStore.saved("course-9"))
    }

    // ── The lesson has a beginning ────────────────────────────────────────

    @Test
    fun `the opening names the lesson that was actually requested`() {
        val opening = ClassroomSessionContract.opening(
            topic = "Minecraft",
            objective = "Survive a first night",
            durationMinutes = 20,
            difficulty = "beginner",
            mode = "solo",
        )
        assertEquals("Today: Minecraft", opening.title)
        assertEquals("Survive a first night", opening.objective)
        assertEquals(listOf("20 min", "beginner level"), opening.facts)
        assertFalse(opening.resumed)
        assertTrue(opening.note.contains("stop Lyo at any time"))
    }

    @Test
    fun `a resumed class says so instead of pretending to start`() {
        val opening = ClassroomSessionContract.opening(
            topic = "Minecraft",
            objective = null,
            durationMinutes = null,
            difficulty = null,
            mode = null,
            resumed = true,
        )
        assertEquals("Back to Minecraft", opening.title)
        assertEquals("Understand and apply Minecraft", opening.objective)
        assertEquals(listOf("10 min"), opening.facts)
    }

    @Test
    fun `the length shown is the length the server will be told`() {
        val opening = ClassroomSessionContract.opening(
            topic = "Fractions",
            objective = null,
            durationMinutes = 999,
            difficulty = null,
            mode = "challenge",
        )
        assertEquals(listOf("60 min", "challenge mode"), opening.facts)
    }

    // ── A step that never arrives ─────────────────────────────────────────

    @Test
    fun `the stall thresholds give a slow step time before it is broken`() {
        assertTrue(ClassroomSessionContract.STALL_NOTICE_MS > 0)
        assertTrue(
            ClassroomSessionContract.STALL_RECOVERY_MS >
                ClassroomSessionContract.STALL_NOTICE_MS,
        )
        assertTrue(ClassroomSessionContract.STALL_RECOVERY.contains("not a wrong answer"))
    }
}
