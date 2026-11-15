package com.lyo.app.ui.screens.classroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassroomVoiceRoutePolicyTest {
    @Test
    fun `first failed generation pins device narration for remainder of lesson`() {
        val policy = ClassroomVoiceRoutePolicy()
        assertEquals(ClassroomVoiceRoute.UNDECIDED, policy.route)
        assertTrue(policy.sharedSpeechFailed())
        assertEquals(ClassroomVoiceRoute.DEVICE, policy.route)
        assertTrue(policy.useDevice)
        assertTrue(policy.sharedSpeechFailed())
    }

    @Test
    fun `a generated teacher never silently switches to device tts`() {
        val policy = ClassroomVoiceRoutePolicy()
        policy.sharedPlaybackBegan()
        assertEquals(ClassroomVoiceRoute.SHARED, policy.route)
        assertFalse(policy.sharedSpeechFailed())
        assertFalse(policy.useDevice)
        assertEquals(ClassroomVoiceRoute.SHARED, policy.route)
    }
}
