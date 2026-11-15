package com.lyo.app.ui.screens.classroom

import org.junit.Assert.assertEquals
import org.junit.Test

class ClassroomVoiceTimeoutPolicyTest {
    @Test fun `staging allows uncached generated speech beyond eight seconds`() {
        assertEquals(15L, ClassroomVoiceTimeoutPolicy.fullMp3TimeoutSeconds("staging"))
        assertEquals(15L, ClassroomVoiceTimeoutPolicy.fullMp3TimeoutSeconds("STAGING"))
    }

    @Test fun `production and unknown environments retain original call deadline`() {
        assertEquals(8L, ClassroomVoiceTimeoutPolicy.fullMp3TimeoutSeconds("production"))
        assertEquals(8L, ClassroomVoiceTimeoutPolicy.fullMp3TimeoutSeconds("custom"))
        assertEquals(8L, ClassroomVoiceTimeoutPolicy.fullMp3TimeoutSeconds(""))
    }
}
