package com.lyo.app.ui.screens.classroom

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A request-contract test, not proof of audible streaming. No learner token,
 * audio bytes, backend call, or network request is used by this test.
 */
@OptIn(UnstableApi::class)
@RunWith(AndroidJUnit4::class)
class ClassroomProgressiveTtsSpecTest {
    @Test
    fun voicePromptIsSentAsPostBodyNotAsUrlQuery() {
        val uri = Uri.parse("https://example.test/api/v1/tts/synthesize/stream")
        val requestBytes = """{"text":"private practice question","voice":"onyx"}"""
            .toByteArray(Charsets.UTF_8)
        val spec = classroomVoicePostSpec(DataSpec(uri), requestBytes)
        assertEquals(DataSpec.HTTP_METHOD_POST, spec.httpMethod)
        assertEquals(uri, spec.uri)
        assertArrayEquals(requestBytes, spec.httpBody)
        assertFalse(spec.uri.toString().contains("private practice question"))
    }

    @Test
    fun streamingSourceDoesNotRequireAnyNewPublicGetEndpoint() {
        val spec = classroomVoicePostSpec(
            DataSpec(Uri.parse("https://example.test/api/v1/tts/synthesize/stream")),
            "{}".toByteArray(),
        )
        assertEquals(DataSpec.HTTP_METHOD_POST, spec.httpMethod)
        assertEquals("/api/v1/tts/synthesize/stream", spec.uri.path)
    }
}
