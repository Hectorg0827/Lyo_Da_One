package com.lyo.app.ui.screens.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceTurnSafetyTest {
    @Test fun echoIsNotTreatedAsNewSpeech() {
        assertTrue(VoiceTurnSafety.isLikelyEcho(
            "gravity attracts matter", "Gravity attracts matter in the universe."
        ))
        assertFalse(VoiceTurnSafety.shouldSubmitFinal(
            "gravity attracts matter", "Gravity attracts matter in the universe.",
            assistantAudible = true, confirmedDuringPlayback = true,
        ))
    }

    @Test fun noisyOneOffResultDoesNotInterruptTheAssistant() {
        assertFalse(VoiceTurnSafety.shouldSubmitFinal(
            "some unrelated words", "The planets revolve around the sun.",
            assistantAudible = true, confirmedDuringPlayback = false,
        ))
    }

    @Test fun stableRealSpeechCanInterrupt() {
        val first = VoiceTurnSafety.confirmationCount("", 0, "Wait I have")
        val second = VoiceTurnSafety.confirmationCount("Wait I have", first, "Wait I have a question")
        assertEquals(1, first)
        assertEquals(2, second)
        assertTrue(VoiceTurnSafety.shouldSubmitFinal(
            "Wait I have a question", "The planets revolve around the sun.",
            assistantAudible = true, confirmedDuringPlayback = second >= 2,
        ))
    }

    @Test fun oneWordOrUnrelatedPartialsAreNotConfirmedBargeIns() {
        assertEquals(0, VoiceTurnSafety.confirmationCount("", 0, "hey"))
        assertEquals(1, VoiceTurnSafety.confirmationCount("Wait I have", 1, "another sentence"))
    }

    @Test fun normalListeningAcceptsNewQuestions() {
        assertTrue(VoiceTurnSafety.shouldSubmitFinal(
            "¿Puedes explicarlo en español?", "",
            assistantAudible = false, confirmedDuringPlayback = false,
        ))
    }

    @Test fun spokenThoughtsGetShortPunctuationPauses() {
        assertEquals(170L, VoiceTurnSafety.pauseAfterSegmentMs("Really?"))
        assertEquals(170L, VoiceTurnSafety.pauseAfterSegmentMs("You got it!”"))
        assertEquals(125L, VoiceTurnSafety.pauseAfterSegmentMs("Exactly."))
        assertEquals(80L, VoiceTurnSafety.pauseAfterSegmentMs("Well,"))
        assertEquals(80L, VoiceTurnSafety.pauseAfterSegmentMs("First:"))
        assertEquals(0L, VoiceTurnSafety.pauseAfterSegmentMs("and then"))
        assertEquals(0L, VoiceTurnSafety.pauseAfterSegmentMs(" "))
    }
}
