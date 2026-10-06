package com.lyo.app.ui.screens.clips

import com.lyo.app.data.api.ClipDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The scoreboard a creator reads to decide whether this is worth their time.
 *
 * Mirrored by `CreatorStatsTests.swift` and `creator-stats.test.mjs`: the
 * rule that a count the server did not send is not a zero has to hold on all
 * three, or one platform quietly understates someone's reach.
 */
class CreatorStatsTest {

    private fun clip(
        views: Int? = null,
        likes: Int? = null,
        comments: Int? = null,
        shares: Int? = null,
    ) = ClipDto(
        id = "c",
        title = "A clip",
        viewCount = views,
        likeCount = likes,
        commentCount = comments,
        shareCount = shares,
    )

    @Test
    fun `totals add up what every clip reported`() {
        val totals = CreatorStats.totals(
            listOf(
                clip(views = 100, likes = 5, comments = 2, shares = 1),
                clip(views = 40, likes = 3, comments = 0, shares = 4),
            ),
        )
        assertEquals(140, totals[CreatorStats.Metric.Views]?.value)
        assertEquals(8, totals[CreatorStats.Metric.Likes]?.value)
        assertEquals(2, totals[CreatorStats.Metric.Comments]?.value)
        assertEquals(5, totals[CreatorStats.Metric.Shares]?.value)
        for (metric in CreatorStats.Metric.entries) {
            assertTrue("$metric should be complete", totals[metric]?.isComplete == true)
        }
    }

    @Test
    fun `a count the server did not send is not a zero`() {
        // Summing a missing count as zero would understate the creator's
        // reach and look exactly like a real total.
        val total = CreatorStats.total(
            CreatorStats.Metric.Views,
            listOf(clip(views = 100), clip(views = null), clip()),
        )
        assertEquals(100, total.value)
        assertEquals(1, total.reporting)
        assertEquals(3, total.clips)
        assertFalse(total.isComplete)
        assertEquals("from 1 of 3 clips", total.coverageNote)
    }

    @Test
    fun `a real zero still counts as reported`() {
        // A clip genuinely watched zero times reported its figure; that is
        // not the same as a clip whose views are not being counted.
        val total = CreatorStats.total(CreatorStats.Metric.Views, listOf(clip(views = 0)))
        assertEquals(0, total.value)
        assertTrue(total.isReported)
        assertTrue(total.isComplete)
        assertNull(total.coverageNote)
    }

    @Test
    fun `nothing reported is not a zero either`() {
        val total = CreatorStats.total(CreatorStats.Metric.Views, listOf(clip(), clip()))
        assertFalse(total.isReported)
        assertFalse(total.isComplete)
        assertNull(total.coverageNote)
    }

    @Test
    fun `a complete total carries no qualifier`() {
        val total = CreatorStats.total(
            CreatorStats.Metric.Views,
            listOf(clip(views = 7), clip(views = 3)),
        )
        assertEquals(10, total.value)
        assertNull(total.coverageNote)
    }

    @Test
    fun `no clips is no stats not zeroes`() {
        val total = CreatorStats.total(CreatorStats.Metric.Views, emptyList())
        assertEquals(0, total.clips)
        assertFalse(total.isReported)
        assertFalse(total.isComplete)
    }
}
