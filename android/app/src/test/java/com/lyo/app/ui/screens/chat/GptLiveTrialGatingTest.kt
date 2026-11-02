package com.lyo.app.ui.screens.chat

import com.lyo.app.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** No test here talks to a paid OpenAI endpoint. */
class GptLiveTrialGatingTest {
    @Test
    fun trialFeatureCannotBeVisibleInProductionEnvironment() {
        if (BuildConfig.API_ENVIRONMENT != "staging") {
            assertFalse(BuildConfig.GPT_LIVE_TRIAL_UI)
        }
    }

    @Test
    fun trialBuildMustPointAtExplicitStagingApi() {
        if (BuildConfig.GPT_LIVE_TRIAL_UI) {
            assertEquals("staging", BuildConfig.API_ENVIRONMENT)
            assertEquals(
                "lyovoicelabbackend-staging.up.railway.app",
                java.net.URI(BuildConfig.VOICE_LAB_BASE_URL).host,
            )
            assertNotEquals(BuildConfig.API_BASE_URL, BuildConfig.VOICE_LAB_BASE_URL)
            assertTrue(java.net.URI(BuildConfig.API_BASE_URL).host.endsWith("-staging.up.railway.app"))
        }
    }
    @Test
    fun voiceLabAddressIsAbsentWhenTrialUiIsOff() {
        if (!BuildConfig.GPT_LIVE_TRIAL_UI) {
            assertFalse(BuildConfig.VOICE_LAB_BASE_URL.isNotEmpty())
        }
    }
}
