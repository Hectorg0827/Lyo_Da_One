package com.lyo.app.ui.screens.chat

import kotlinx.coroutines.CancellationException

/** Intentional cancellation must leave the conversational floor with the learner. */
internal suspend fun <T> runChatRequest(block: suspend () -> T): Result<T> = try {
    Result.success(block())
} catch (cancellation: CancellationException) {
    throw cancellation
} catch (error: Exception) {
    Result.failure(error)
}
