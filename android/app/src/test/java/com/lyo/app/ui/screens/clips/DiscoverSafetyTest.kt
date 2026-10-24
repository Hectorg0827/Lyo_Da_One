package com.lyo.app.ui.screens.clips

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Report and Block on Discover. Mirrored by web `discover-report.test.mjs`
 * and iOS `DiscoverSafetyTests.swift`: a learner has to get the same choices
 * and the same outcome on every platform.
 */
class DiscoverSafetyTest {

    // LyoBackendJune lyo_app/community/models.py ReportReason; anything else is a 422.
    private val apiReasons = setOf(
        "spam", "harassment", "hate_speech", "violence", "sexual_content",
        "misinformation", "impersonation", "copyright", "inappropriate", "other",
    )

    @Test
    fun `every reason is one the API stores, each offered once`() {
        val reasons = DiscoverSafety.REPORT_REASONS
        reasons.forEach { assertTrue("API refuses ${it.value}", it.value in apiReasons) }
        assertEquals(reasons.size, reasons.map { it.value }.toSet().size)
        assertEquals(reasons.size, reasons.map { it.label }.toSet().size)
        assertEquals("other", reasons.last().value)
        assertEquals(1000, DiscoverSafety.NOTE_LIMIT)
    }

    @Test
    fun `own videos cannot be reported, and an unknown owner leaves it to the server`() {
        assertFalse(DiscoverSafety.canReport("42", "42"))
        assertTrue(DiscoverSafety.canReport("42", "7"))
        assertTrue(DiscoverSafety.canReport(null, "7"))
        assertTrue(DiscoverSafety.canReport("42", null))
    }

    @Test
    fun `Block is offered on someone else's video, never your own or a library video`() {
        assertTrue(DiscoverSafety.canBlock("42", "7", isLibrary = false))
        assertFalse(DiscoverSafety.canBlock("42", "42", isLibrary = false))
        assertFalse("blocking the library account would empty Discover", DiscoverSafety.canBlock("42", "7", isLibrary = true))
        assertFalse(DiscoverSafety.canBlock(null, "7", isLibrary = false))
        assertFalse("an unknown viewer might be the owner", DiscoverSafety.canBlock("42", null, isLibrary = false))
    }

    @Test
    fun `a report, a repeat or a vanished video leaves the feed but a failure does not`() {
        assertEquals(DiscoverSafety.Outcome(true, "Thanks. We'll review this video."), DiscoverSafety.reportOutcome(201))
        assertTrue(DiscoverSafety.reportOutcome(200).succeeded)
        assertTrue(DiscoverSafety.reportOutcome(404).succeeded)
        listOf(0, 400, 401, 422, 500, 503).forEach { assertFalse("status $it", DiscoverSafety.reportOutcome(it).succeeded) }
    }

    @Test
    fun `a block succeeds once the server stores it`() {
        assertEquals(
            DiscoverSafety.Outcome(true, "Blocked Sam. You won't see each other's videos or comments."),
            DiscoverSafety.blockOutcome(201, "Sam"),
        )
        assertTrue(DiscoverSafety.blockOutcome(200, "Sam").succeeded)
        assertEquals(DiscoverSafety.Outcome(false, "This account no longer exists."), DiscoverSafety.blockOutcome(404, "Sam"))
        listOf(0, 400, 401, 422, 500).forEach { assertFalse(DiscoverSafety.blockOutcome(it, "Sam").succeeded) }
    }

    @Test
    fun `after removals the next page also asks for the one before`() {
        assertEquals(listOf(2), DiscoverSafety.pagesToFetch(2, 0, 20))
        assertEquals(listOf(1, 2), DiscoverSafety.pagesToFetch(2, 1, 20))
        assertEquals(listOf(2, 3), DiscoverSafety.pagesToFetch(3, 20, 20))
        assertEquals(listOf(1, 2, 3), DiscoverSafety.pagesToFetch(3, 21, 20))
        assertEquals(listOf(1, 2), DiscoverSafety.pagesToFetch(2, 45, 20))
    }
}
