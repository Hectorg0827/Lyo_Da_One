package com.lyo.app.ui.screens.chat

import com.lyo.app.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
        }
    }
}
