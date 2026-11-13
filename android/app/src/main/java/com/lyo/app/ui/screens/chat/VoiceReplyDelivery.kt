package com.lyo.app.ui.screens.chat

/** One server reply must be spoken once, including replies without segments. */
internal class VoiceReplyDelivery {
    private var delivered = false
    private var suppressed = false

    fun accepted() { delivered = true }
    fun suppressFallback() { suppressed = true }
    fun shouldSpeakFallback(completed: Boolean): Boolean = completed && !delivered && !suppressed
}
