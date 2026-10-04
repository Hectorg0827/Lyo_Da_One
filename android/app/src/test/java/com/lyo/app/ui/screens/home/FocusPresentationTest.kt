package com.lyo.app.ui.screens.home

import com.lyo.app.data.api.StackItemDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The decisions Home makes about a learner's saved courses, driven directly
 * rather than through a composable — the same reason iOS has
 * `FocusPresentationTests` and web has `focus-presentation.test.mjs`.
 *
 * The rule being defended: a figure the app does not have is not a zero.
 */
class FocusPresentationTest {

    private fun course(
        title: String = "A course",
        description: String? = null,
        status: String = "in_progress",
        progress: Float = 0.4f,
    ) = StackItemDto(
        id = 1,
        title = title,
        description = description,
        itemType = "course",
        status = status,
        progress = progress,
        contentId = "c-1",
    )

    @Test
    fun `a measured fraction becomes a percentage`() {
        assertEquals(62, FocusPresentation.percentFor(course(progress = 0.62f)))
    }

    @Test
    fun `out of range figures are clamped`() {
        assertEquals(100, FocusPresentation.percentFor(course(progress = 1.8f)))
        assertEquals(0, FocusPresentation.percentFor(course(progress = -0.4f)))
    }

    @Test
    fun `a figure that is not a number is unknown rather than zero`() {
        // An absent number must not be drawn as an empty bar, which would
        // assert the learner is at the start of the course.
        assertEquals(
            FocusPresentation.Progress.Unknown,
            FocusPresentation.progressFor(course(progress = Float.NaN)),
        )
        assertNull(FocusPresentation.percentFor(course(progress = Float.NaN)))
    }

    @Test
    fun `completion follows the server status and an unmeasured course is not finished`() {
        assertTrue(FocusPresentation.isFinished(course(status = "completed", progress = 0.2f)))
        assertTrue(FocusPresentation.isFinished(course(status = "in_progress", progress = 1f)))
        assertFalse(FocusPresentation.isFinished(course(status = "in_progress", progress = 0.99f)))
        assertFalse(FocusPresentation.isFinished(course(status = "unknown", progress = Float.NaN)))
    }

    @Test
    fun `the action reflects where the learner is`() {
        assertEquals(FocusPresentation.Action.Start, FocusPresentation.actionFor(course(status = "not_started", progress = 0f)))
        assertEquals(FocusPresentation.Action.Resume, FocusPresentation.actionFor(course(status = "in_progress")))
        assertEquals(FocusPresentation.Action.Resume, FocusPresentation.actionFor(course(status = "paused")))
        assertEquals(FocusPresentation.Action.Review, FocusPresentation.actionFor(course(status = "completed", progress = 1f)))
    }

    @Test
    fun `an unmeasured course offers Start without asserting zero`() {
        val item = course(status = "unknown", progress = Float.NaN)
        assertEquals(FocusPresentation.Action.Start, FocusPresentation.actionFor(item))
        assertEquals(FocusPresentation.Progress.Unknown, FocusPresentation.progressFor(item))
    }

    @Test
    fun `the description the backend sends wins and is trimmed`() {
        assertEquals(
            FocusPresentation.Blurb.Description("Vector spaces before matrices."),
            FocusPresentation.blurbFor(course(description = "  Vector spaces before matrices.\n")),
        )
    }

    @Test
    fun `a blank description falls through to where the course stands`() {
        assertEquals(
            FocusPresentation.Blurb.Status("Paused"),
            FocusPresentation.blurbFor(course(description = "   ", status = "paused")),
        )
    }

    @Test
    fun `with neither a description nor a known status the card says nothing`() {
        assertEquals(
            FocusPresentation.Blurb.None,
            FocusPresentation.blurbFor(course(description = null, status = "weird")),
        )
    }

    @Test
    fun `each filter catches what it says`() {
        val started = course(status = "in_progress", progress = 0.5f)
        val fresh = course(status = "not_started", progress = 0f)
        val done = course(status = "completed", progress = 1f)
        val all = listOf(started, fresh, done)

        assertTrue(FocusPresentation.matches(started, FocusPresentation.Filter.InProgress))
        assertTrue(FocusPresentation.matches(fresh, FocusPresentation.Filter.NotStarted))
        assertTrue(FocusPresentation.matches(done, FocusPresentation.Filter.Finished))
        assertFalse(FocusPresentation.matches(done, FocusPresentation.Filter.InProgress))
        assertEquals(3, FocusPresentation.countFor(all, FocusPresentation.Filter.All))
        assertEquals(1, FocusPresentation.countFor(all, FocusPresentation.Filter.Finished))
    }

    @Test
    fun `subject keywords pick the matching motif`() {
        assertEquals(FocusPresentation.Motif.Lattice, FocusPresentation.motifFor("Organic Chemistry: Reaction Mechanisms"))
        assertEquals(FocusPresentation.Motif.Speech, FocusPresentation.motifFor("Spanish B1 Conversation"))
        assertEquals(FocusPresentation.Motif.Curve, FocusPresentation.motifFor("Introduction to Statistics"))
        assertEquals(FocusPresentation.Motif.Staff, FocusPresentation.motifFor("Music Theory Basics"))
        assertEquals(FocusPresentation.Motif.Grid, FocusPresentation.motifFor("Linear Algebra Done Right"))
        assertEquals(FocusPresentation.Motif.Lattice, FocusPresentation.motifFor("ORGANIC CHEMISTRY"))
    }

    @Test
    fun `the artwork is the same every launch`() {
        assertEquals(
            FocusPresentation.motifFor("Beekeeping for beginners"),
            FocusPresentation.motifFor("Beekeeping for beginners"),
        )
        assertEquals(FocusPresentation.stableHash("one"), FocusPresentation.stableHash("one"))
        assertTrue(FocusPresentation.stableHash("one") != FocusPresentation.stableHash("two"))
    }

    @Test
    fun `all three platforms choose the same motif for the same course`() {
        // Golden values shared with iOS `FocusArtworkTests` and web
        // `focus-presentation.test.mjs`: UInt64 FNV-1a over the lowercased
        // title, indexed into the motif order. If any platform's hash or
        // motif order changes, the same course starts looking different on
        // each of them, and this fails.
        val shared = mapOf(
            "Beekeeping for beginners" to FocusPresentation.Motif.Grid,
            "Woodworking" to FocusPresentation.Motif.Speech,
            "Chess openings" to FocusPresentation.Motif.Lattice,
            "Ancient Rome" to FocusPresentation.Motif.Curve,
            "" to FocusPresentation.Motif.Orbit,
        )
        for ((title, motif) in shared) {
            assertEquals("motif drifted for \"$title\"", motif, FocusPresentation.motifFor(title))
        }
    }

    // ── The deck ──────────────────────────────────────────────────────────
    //
    // Three platforms draw the collapsed deck from the same table, so these
    // values are a cross-platform contract: the matching Swift and JavaScript
    // suites assert the same numbers.

    @Test
    fun `a single course has no deck to open`() {
        assertTrue(FocusPresentation.deckLayers(1).isEmpty())
        assertEquals(null, FocusPresentation.deckMoreLabel(1))
        assertTrue(FocusPresentation.deckLayers(0).isEmpty())
        assertEquals(null, FocusPresentation.deckMoreLabel(0))
    }

    @Test
    fun `one card is not a deck to open`() {
        // A filter can narrow an open deck to one course. The screen asks
        // this on every composition, so the deck closes itself instead of
        // leaving a lone narrowed card in a LazyRow with no way back.
        assertFalse(FocusPresentation.deckCanOpen(0))
        assertFalse(FocusPresentation.deckCanOpen(1))
        assertTrue(FocusPresentation.deckCanOpen(2))
        assertTrue(FocusPresentation.deckCanOpen(40))
    }

    @Test
    fun `openability agrees with the layers and the label`() {
        // The three answers have to agree: something to open, something
        // drawn behind the top card, and something for the control to say.
        for (count in 0..6) {
            val canOpen = FocusPresentation.deckCanOpen(count)
            assertEquals(canOpen, FocusPresentation.deckLayers(count).isNotEmpty())
            assertEquals(canOpen, FocusPresentation.deckMoreLabel(count) != null)
        }
    }

    @Test
    fun `two courses draw one peek card, three draw two`() {
        assertEquals(
            listOf(FocusPresentation.DeckLayer(1, 11f, 0.95f, 0.72f)),
            FocusPresentation.deckLayers(2),
        )
        assertEquals(
            listOf(
                FocusPresentation.DeckLayer(1, 11f, 0.95f, 0.72f),
                FocusPresentation.DeckLayer(2, 20f, 0.9f, 0.46f),
            ),
            FocusPresentation.deckLayers(3),
        )
    }

    @Test
    fun `the deck stops at two peek cards however many courses are saved`() {
        assertEquals(2, FocusPresentation.deckLayers(4).size)
        assertEquals(2, FocusPresentation.deckLayers(40).size)
        assertEquals(2, FocusPresentation.DECK_PEEK_LIMIT)
    }

    @Test
    fun `the label counts every hidden course, not just the ones drawn`() {
        // A deck drawing two layers over twelve courses still says eleven are
        // waiting: the figure belongs to the learner's library, not the art.
        assertEquals("1 more course", FocusPresentation.deckMoreLabel(2))
        assertEquals("2 more courses", FocusPresentation.deckMoreLabel(3))
        assertEquals("11 more courses", FocusPresentation.deckMoreLabel(12))
    }

    @Test
    fun `an opened card leaves the next one showing`() {
        // The opened deck scrolls sideways, so a card the full width of the
        // screen would hide every course after the first behind a swipe
        // nothing signals.
        assertEquals(34f, FocusPresentation.DECK_NEXT_CARD_PEEK, 0.001f)
        assertEquals(12f, FocusPresentation.DECK_CARD_GAP, 0.001f)
        assertEquals(344f, FocusPresentation.deckCardWidth(390f), 0.001f)
        assertEquals(384f, FocusPresentation.deckCardWidth(430f), 0.001f)
    }

    @Test
    fun `the leftover room is exactly the peek`() {
        // The next card starts one gap after this one ends, so exactly the
        // peek is left over. This is the relationship the figures hold.
        val container = 412f
        val card = FocusPresentation.deckCardWidth(container)
        assertEquals(
            FocusPresentation.DECK_NEXT_CARD_PEEK,
            container - (card + FocusPresentation.DECK_CARD_GAP),
            0.001f,
        )
    }

    @Test
    fun `a container too narrow for a card gives no card`() {
        assertEquals(0f, FocusPresentation.deckCardWidth(0f), 0.001f)
        assertEquals(0f, FocusPresentation.deckCardWidth(-20f), 0.001f)
        assertEquals(0f, FocusPresentation.deckCardWidth(30f), 0.001f)
    }

    @Test
    fun `the stagger starts at zero, steps, and then stops`() {
        assertEquals(0, FocusPresentation.deckStaggerMilliseconds(0))
        assertEquals(0, FocusPresentation.deckStaggerMilliseconds(-3))
        assertEquals(35, FocusPresentation.deckStaggerMilliseconds(1))
        assertEquals(105, FocusPresentation.deckStaggerMilliseconds(3))
        assertEquals(280, FocusPresentation.deckStaggerMilliseconds(8))
        // Capped: forty saved courses must not mean a 1.4s wait for the list.
        assertEquals(280, FocusPresentation.deckStaggerMilliseconds(40))
    }
}
