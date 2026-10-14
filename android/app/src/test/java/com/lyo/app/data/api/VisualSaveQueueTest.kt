package com.lyo.app.data.api

import com.google.gson.JsonPrimitive
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class VisualSaveQueueTest {
    private fun request(value: Int, conversation: String = "conv-1") = VisualUpdateRequest(
        conversation, "pie-1", mapOf("parts" to JsonPrimitive(4), "value" to JsonPrimitive(value)),
    )
    private fun response() = VisualUpdateResponse(SmartBlock(
        "pie-1", 1, SmartBlockType.TEXT, null, SmartBlockContent.Text(TextBlockPayload("Saved")), null,
    ))

    @Test
    fun `rapid changes coalesce and newer edits wait for the in flight save`() = runTest {
        val calls = mutableListOf<VisualUpdateRequest>()
        val replies = mutableListOf<CompletableDeferred<VisualUpdateResponse>>()
        val queue = VisualSaveQueue(backgroundScope) {
            calls += it
            CompletableDeferred<VisualUpdateResponse>().also { reply -> replies += reply }.await()
        }
        queue.enqueue(request(1), {}, {})
        queue.enqueue(request(2), {}, {})
        runCurrent(); advanceTimeBy(300); runCurrent()
        assertEquals(listOf(2), calls.map { it.values.getValue("value").asInt })
        queue.enqueue(request(1), {}, {})
        queue.enqueue(request(3), {}, {})
        advanceTimeBy(300); runCurrent()
        assertEquals(1, calls.size)
        replies[0].complete(response()); runCurrent()
        advanceTimeBy(300); runCurrent()
        assertEquals(listOf(2, 3), calls.map { it.values.getValue("value").asInt })
        replies[1].complete(response()); runCurrent()
    }

    @Test
    fun `leaving the screen before debounce does not cancel its diagram save`() = runTest {
        val calls = mutableListOf<VisualUpdateRequest>()
        val queue = VisualSaveQueue(backgroundScope) { calls += it; response() }
        val screen = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
        screen.launch { queue.enqueue(request(1), {}, {}) }
        runCurrent()
        screen.cancel()
        advanceTimeBy(300); runCurrent()
        assertEquals(1, calls.size)
        assertEquals("conv-1", calls.single().conversationId)
    }

    @Test
    fun `failed save is retried with the latest values and reports recovery`() = runTest {
        var fail = true
        var failed = false
        val calls = mutableListOf<VisualUpdateRequest>()
        val queue = VisualSaveQueue(backgroundScope) {
            calls += it
            if (fail) throw IOException("offline")
            response()
        }
        queue.enqueue(request(1), { failed = false }, { failed = true })
        runCurrent(); advanceTimeBy(300); runCurrent()
        assertTrue(failed)
        fail = false
        queue.enqueue(request(3), { failed = false }, { failed = true })
        runCurrent(); advanceTimeBy(300); runCurrent()
        assertFalse(failed)
        assertEquals(listOf(1, 3), calls.map { it.values.getValue("value").asInt })
    }

    @Test
    fun `different conversations never share a pending edit even with the same block id`() = runTest {
        val calls = mutableListOf<VisualUpdateRequest>()
        val queue = VisualSaveQueue(backgroundScope) { calls += it; response() }
        queue.enqueue(request(1, "conv-1"), {}, {})
        queue.enqueue(request(3, "conv-2"), {}, {})
        runCurrent(); advanceTimeBy(300); runCurrent()
        assertEquals(setOf("conv-1" to 1, "conv-2" to 3), calls.map {
            it.conversationId to it.values.getValue("value").asInt
        }.toSet())
    }
}
