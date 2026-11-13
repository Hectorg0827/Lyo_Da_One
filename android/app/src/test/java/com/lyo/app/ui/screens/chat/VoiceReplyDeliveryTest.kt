package com.lyo.app.ui.screens.chat

import org.junit.Assert.*
import org.junit.Test

class VoiceReplyDeliveryTest {
    @Test fun acceptedReadyReplyIsNotStoppedAndReplayedOnDone() {
        val delivery = VoiceReplyDelivery()
        delivery.accepted()
        assertFalse(delivery.shouldSpeakFallback(true))
    }
    @Test fun acceptedSegmentIsNotReplayed() {
        val delivery = VoiceReplyDelivery()
        delivery.accepted()
        delivery.accepted()
        assertFalse(delivery.shouldSpeakFallback(true))
    }
    @Test fun failedTtsCanFallbackAfterCompletion() {
        val delivery = VoiceReplyDelivery()
        assertFalse(delivery.shouldSpeakFallback(false))
        assertTrue(delivery.shouldSpeakFallback(true))
    }
    @Test fun incompleteOrServerSuppressedReplyNeverFallsBack() {
        val delivery = VoiceReplyDelivery()
        delivery.suppressFallback()
        assertFalse(delivery.shouldSpeakFallback(true))
    }
    @Test fun nextTurnHasIndependentDeliveryState() {
        val previous = VoiceReplyDelivery()
        previous.accepted()
        assertTrue(VoiceReplyDelivery().shouldSpeakFallback(true))
    }
}
