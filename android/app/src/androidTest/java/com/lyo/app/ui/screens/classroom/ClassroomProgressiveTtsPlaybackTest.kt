package com.lyo.app.ui.screens.classroom

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import android.content.Context
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.PI
import kotlin.math.sin

/**
 * Real Media3 progressive playback + authenticated POST against a LOCAL
 * simulated server, not the connected classroom or an external provider.
 * The fixture is generated WAV so this does not certify Kokoro MP3 timbre.
 */
@RunWith(AndroidJUnit4::class)
class ClassroomProgressiveTtsPlaybackTest {
    private fun toneWav(): ByteArray {
        val sampleRate = 8_000
        val sampleCount = sampleRate
        return ByteBuffer.allocate(44 + sampleCount * 2)
            .order(ByteOrder.LITTLE_ENDIAN)
            .apply {
                put("RIFF".toByteArray(Charsets.US_ASCII))
                putInt(36 + sampleCount * 2)
                put("WAVE".toByteArray(Charsets.US_ASCII))
                put("fmt ".toByteArray(Charsets.US_ASCII))
                putInt(16)
                putShort(1.toShort())
                putShort(1.toShort())
                putInt(sampleRate)
                putInt(sampleRate * 2)
                putShort(2.toShort())
                putShort(16.toShort())
                put("data".toByteArray(Charsets.US_ASCII))
                putInt(sampleCount * 2)
                repeat(sampleCount) { i ->
                    val amplitude = (sin(2 * PI * 440.0 * i / sampleRate) * 3500).toInt()
                    putShort(amplitude.toShort())
                }
            }.array()
    }

    @Test
    fun streamedFixtureStartsAndCompletesUsingPrivatePostBody() {
        val server = MockWebServer()
        server.start()
        val started = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val error = AtomicReference<Boolean?>(null)
        val context = ApplicationProvider.getApplicationContext<Context>()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val stream = AtomicReference<ClassroomProgressiveTtsStream?>(null)
        val json = """{"text":"fixture only","voice":"onyx","format":"mp3"}"""
        try {
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "audio/wav")
                    .setBody(Buffer().write(toneWav()))
                    .throttleBody(512, 15, TimeUnit.MILLISECONDS),
            )
            // MockWebServer.url() resolves the local server hostname and must
            // not run on Android's UI thread (StrictMode reverse DNS guard).
            val localFixtureUrl = server.url("/api/v1/tts/synthesize/stream").toString()
            instrumentation.runOnMainSync {
                stream.set(
                    ClassroomProgressiveTtsStream(
                        context = context,
                        url = localFixtureUrl,
                        requestJson = json,
                        token = "local-only-test-token",
                        onAudioStarted = { started.countDown() },
                        onFinished = { finished.countDown() },
                        onFailure = { error.set(it); finished.countDown() },
                        allowDebugLoopbackHttp = true,
                    ),
                )
            }
            val request = server.takeRequest(10, TimeUnit.SECONDS)
            assertNotNull("Local audio request never reached the fixture server", request)
            assertEquals("POST", request!!.method)
            assertEquals("/api/v1/tts/synthesize/stream", request.path)
            assertEquals("Bearer local-only-test-token", request.getHeader("Authorization"))
            assertEquals("application/json", request.getHeader("Content-Type"))
            assertEquals(json, request.body.readUtf8())
            assertFalse(request.path!!.contains("fixture only"))
            assertTrue("Media3 did not start progressive playback", started.await(20, TimeUnit.SECONDS))
            assertTrue("Media3 did not reach end of stream", finished.await(20, TimeUnit.SECONDS))
            assertNull("Media3 reported a playback error", error.get())
        } finally {
            instrumentation.runOnMainSync { stream.getAndSet(null)?.release() }
            server.shutdown()
        }
    }

    @Test
    fun insecureExternalEndpointsAreRejectedEvenInDebugTests() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = ApplicationProvider.getApplicationContext<Context>()
        val failure = AtomicReference<Throwable?>(null)
        instrumentation.runOnMainSync {
            try {
                ClassroomProgressiveTtsStream(
                    context = context,
                    url = "http://example.com/api/v1/tts/synthesize/stream",
                    requestJson = "{}",
                    token = "fake-test-token",
                    onAudioStarted = {},
                    onFinished = {},
                    onFailure = {},
                    allowDebugLoopbackHttp = true,
                )
            } catch (exc: Throwable) {
                failure.set(exc)
            }
        }
        assertTrue("HTTP must not be accepted for external providers", failure.get() is IllegalArgumentException)
    }
}
