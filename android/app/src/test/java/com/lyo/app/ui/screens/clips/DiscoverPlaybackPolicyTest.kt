package com.lyo.app.ui.screens.clips

import org.junit.Assert.*
import org.junit.Test

class DiscoverPlaybackPolicyTest {
    @Test fun swipeAndBackgroundCannotResumeOldOwner() {
        val playing = DiscoverPlaybackIntent(true, true, false, false)
        assertTrue(playing.shouldPlay)
        val background = playing.copy(foreground = false)
        assertFalse(background.shouldPlay)
        val manuallyPaused = background.copy(userPaused = true)
        assertFalse(manuallyPaused.copy(foreground = true).shouldPlay)
        val scrubbing = playing.copy(scrubbing = true)
        assertFalse(scrubbing.shouldPlay)
        assertFalse(scrubbing.copy(selected = false, scrubbing = false).shouldPlay)
        assertTrue(playing.copy(selected = true).shouldPlay)
    }

    @Test fun staleEndEventDoesNotMoveSelectionAndLatePageCanAdvance() {
        assertNull(nextDiscoverPage(3, 2, 6))
        assertNull(nextDiscoverPage(2, 2, 3))
        assertEquals(3, nextDiscoverPage(2, 2, 4))
        assertNull(nextDiscoverPage(0, -1, 4))
    }
}
