package com.lyo.app.data.classroom

import okhttp3.Request
import org.junit.Assert.*
import org.junit.Test

class ClassroomConnectionUrlTest {
    @Test fun secureStagingRequestCanBeConstructedBeforeWebSocketUpgrade() {
        val url = classroomConnectionUrl("https://staging.example/").newBuilder()
            .addQueryParameter("topic", "Fractions & ratios / café")
            .addQueryParameter("token", "test-token")
            .build()
        val request = Request.Builder().url(url).build()
        assertEquals("https", request.url.scheme)
        assertEquals("/api/v1/classroom/ws/connect", request.url.encodedPath)
        assertEquals("Fractions & ratios / café", request.url.queryParameter("topic"))
        assertEquals("test-token", request.url.queryParameter("token"))
    }

    @Test fun localHttpAndTrailingSlashAreSupported() {
        assertEquals("http://localhost:8080/api/v1/classroom/ws/connect",
            classroomConnectionUrl("http://localhost:8080").toString())
        assertEquals(classroomConnectionUrl("https://staging.example"),
            classroomConnectionUrl("https://staging.example/"))
    }
}
