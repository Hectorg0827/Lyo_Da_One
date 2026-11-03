package com.lyo.app.data.classroom

import okhttp3.Request
import org.junit.Assert.assertEquals
import org.junit.Test

/** Regression tests for the Samsung classroom startup crash (wss:// in HttpUrl). */
class ClassroomSocketUrlTest {

    @Test
    fun secureApiBaseUsesHttpsForOkHttpWebSocketHandshake() {
        val url = classroomSocketHttpUrl("https://lyojourneystagingbackend-staging.up.railway.app/")

        assertEquals("https", url.scheme)
        assertEquals("lyojourneystagingbackend-staging.up.railway.app", url.host)
        assertEquals("/api/v1/classroom/ws/connect", url.encodedPath)
        assertEquals(url, Request.Builder().url(url).build().url)
    }

    @Test
    fun websocketSchemeIsNormalizedBeforeHttpUrlParsing() {
        val url = classroomSocketHttpUrl("wss://lyojourneystagingbackend-staging.up.railway.app/")

        assertEquals("https", url.scheme)
        assertEquals("/api/v1/classroom/ws/connect", url.encodedPath)
        assertEquals(url, Request.Builder().url(url).build().url)
    }

    @Test
    fun localInsecureWebsocketUsesHttpHandshake() {
        val url = classroomSocketHttpUrl("ws://10.0.2.2:8000/")

        assertEquals("http", url.scheme)
        assertEquals("10.0.2.2", url.host)
        assertEquals(8000, url.port)
    }

    @Test
    fun websocketQueryParametersAreEncodedByHttpUrlBuilder() {
        val url = classroomSocketHttpUrl("https://api.example.org/")
            .newBuilder()
            .addQueryParameter("session_id", "session/1")
            .addQueryParameter("token", "a&b?+ c")
            .build()

        assertEquals("session/1", url.queryParameter("session_id"))
        assertEquals("a&b?+ c", url.queryParameter("token"))
        assertEquals("https", Request.Builder().url(url).build().url.scheme)
    }
}
