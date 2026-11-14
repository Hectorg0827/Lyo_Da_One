package com.lyo.app.ui.classroom

import androidx.compose.ui.test.assertDoesNotExist
import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyo.app.ui.screens.chat.LiveVoiceConversationScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Real emulator Compose smoke for a QA-only visual readout, not actual audio latency. */
@RunWith(AndroidJUnit4::class)
class LiveVoiceQaUiTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun qaTimingAndItsHumanSignoffWarningAreVisibleInLiveVoice() {
        compose.setContent {
            LiveVoiceConversationScreen(
                listening = true,
                thinking = false,
                speaking = false,
                userCaption = "",
                assistantCaption = "",
                thinkingNudge = "",
                messages = emptyList(),
                error = null,
                onEnd = {},
                qaReadout = "Test build timing · p50 1.0 s · p95 1.8 s · 20 of 20 turns" +
                    " · speed-only PASS (human QA still required)",
            )
        }
        compose.onNodeWithText("Test build timing", substring = true).assertExists()
        compose.onNodeWithText("human QA still required", substring = true).assertExists()
    }

    @Test
    fun noSyntheticLatencyNumbersAreShownBeforeAnActualVoiceSample() {
        compose.setContent {
            LiveVoiceConversationScreen(
                listening = true,
                thinking = false,
                speaking = false,
                userCaption = "",
                assistantCaption = "",
                thinkingNudge = "",
                messages = emptyList(),
                error = null,
                onEnd = {},
                qaReadout = null,
            )
        }
        compose.onNodeWithText("Test build timing", substring = true).assertDoesNotExist()
    }
}
