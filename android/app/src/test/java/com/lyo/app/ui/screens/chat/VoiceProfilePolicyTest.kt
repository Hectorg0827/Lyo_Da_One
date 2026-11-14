package com.lyo.app.ui.screens.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceProfilePolicyTest {
    @Test fun regionChangesDoNotSelectAnotherVoice() {
        assertEquals("en", VoiceProfilePolicy.languageKey("en-US"))
        assertEquals("en", VoiceProfilePolicy.languageKey("en-GB"))
        assertFalse(VoiceProfilePolicy.shouldChangeLanguage(
            VoiceProfilePolicy.languageKey("en-US"),
            VoiceProfilePolicy.languageKey("en-GB")
        ))
    }

    @Test fun actualLanguageChangeCanSelectItsPinnedVoice() {
        assertTrue(VoiceProfilePolicy.shouldChangeLanguage(
            VoiceProfilePolicy.languageKey("en-US"),
            VoiceProfilePolicy.languageKey("es-DO")
        ))
        assertTrue(VoiceProfilePolicy.shouldChangeLanguage(
            VoiceProfilePolicy.languageKey("es-DO"),
            VoiceProfilePolicy.languageKey("en-US")
        ))
    }

    @Test fun emptyOrSameLanguageDoesNotForceVoiceReselection() {
        assertFalse(VoiceProfilePolicy.shouldChangeLanguage("en", ""))
        assertFalse(VoiceProfilePolicy.shouldChangeLanguage("es", "es"))
    }
}
