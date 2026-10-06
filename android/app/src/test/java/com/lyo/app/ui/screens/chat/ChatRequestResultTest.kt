package com.lyo.app.ui.screens.chat

import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatRequestResultTest {
    @Test
    fun cancelledStreamDoesNotRenderAnErrorOrSpeakOverBargeIn() = runBlocking {
        val streamStarted = CompletableDeferred<Unit>()
        var assistantText = "Partial canonical answer"
        val floor = mutableListOf<String>()
        val turn = launch {
            runChatRequest {
                streamStarted.complete(Unit)
                awaitCancellation()
            }.onFailure {
                assistantText = "Stream failed"
            }
            floor.add("speak")
        }

        streamStarted.await()
        turn.cancel()
        floor.add("listen")
        turn.join()

        assertTrue(turn.isCancelled)
        assertEquals("Partial canonical answer", assistantText)
        assertEquals(listOf("listen"), floor)
    }

    @Test
    fun cancelledConversationCreationDoesNotReportASaveFailure() = runBlocking {
        val requestStarted = CompletableDeferred<Unit>()
        val outcomes = mutableListOf<String>()
        val turn = launch {
            runChatRequest {
                requestStarted.complete(Unit)
                awaitCancellation()
            }.getOrElse {
                outcomes.add("save failure")
                return@launch
            }
            outcomes.add("start stream")
        }

        requestStarted.await()
        turn.cancel()
        turn.join()

        assertTrue(turn.isCancelled)
        assertTrue(outcomes.isEmpty())
    }

    @Test
    fun genuineStreamFailureStillReachesTheErrorHandler() = runBlocking {
        val failure = IOException("Connection lost")
        var reported: Throwable? = null

        val result = runChatRequest<String> { throw failure }.onFailure { reported = it }

        assertTrue(result.isFailure)
        assertSame(failure, reported)
    }

    @Test
    fun successfulCanonicalRequestRetainsItsResult() = runBlocking {
        assertEquals("canonical answer", runChatRequest { "canonical answer" }.getOrThrow())
    }
}
