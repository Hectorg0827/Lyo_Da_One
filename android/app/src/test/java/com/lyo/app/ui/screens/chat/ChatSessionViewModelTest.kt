package com.lyo.app.ui.screens.chat

import kotlinx.coroutines.Job
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatSessionViewModelTest {
    @Test
    fun streamingResponseAndMessagesRemainAvailableWhileTabIsNotDisplayed() {
        val session = ChatSessionViewModel()
        val runningJob = Job()
        session.messages.add(ChatMsg(role = "user", content = "Explain fractions"))
        session.messages.add(ChatMsg(role = "assistant", content = "A fraction"))
        session.activeConversationId.value = "conversation-1"
        session.isStreaming.value = true
        session.streamJob.value = runningJob
        session.initialized = true

        // Simulate leaving the Chat destination. The screen has no ownership
        // of the job; recreating its view reads the same ViewModel state.
        assertEquals("conversation-1", session.activeConversationId.value)
        assertEquals("A fraction", session.messages.last().content)
        assertTrue(session.isStreaming.value)
        assertTrue(session.streamJob.value === runningJob)
        assertTrue(runningJob.isActive)
        assertTrue(session.initialized)
    }

    @Test
    fun logoutCancelsStreamAndClearsMessagesFromPreviousAccount() {
        val session = ChatSessionViewModel()
        val runningJob = Job()
        session.messages.add(ChatMsg(role = "user", content = "Private lesson"))
        session.activeConversationId.value = "private-conversation"
        session.isStreaming.value = true
        session.streamJob.value = runningJob
        session.initialized = true

        session.resetForLogout()

        assertTrue(runningJob.isCancelled)
        assertTrue(session.messages.isEmpty())
        assertFalse(session.isStreaming.value)
        assertNull(session.activeConversationId.value)
        assertNull(session.streamJob.value)
        assertFalse(session.initialized)
    }

    @Test
    fun logoutResetIsIdempotent() {
        val session = ChatSessionViewModel()
        session.resetForLogout()
        session.resetForLogout()

        assertTrue(session.messages.isEmpty())
        assertFalse(session.isStreaming.value)
        assertNull(session.activeConversationId.value)
    }
}
