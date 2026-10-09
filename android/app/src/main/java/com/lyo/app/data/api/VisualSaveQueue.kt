package com.lyo.app.data.api

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Saves belong to the conversation, and survive leaving the composable. */
class VisualSaveQueue(
    private val scope: CoroutineScope,
    private val save: suspend (VisualUpdateRequest) -> VisualUpdateResponse,
) {
    private data class Pending(
        val request: VisualUpdateRequest,
        val onSaved: (SmartBlock) -> Unit,
        val onFailure: () -> Unit,
    )
    private val pending = mutableMapOf<Pair<String, String>, Pending>()
    private val jobs = mutableMapOf<Pair<String, String>, Job>()

    // Called on Main; requests for one visual are coalesced and serialized.
    fun enqueue(request: VisualUpdateRequest, onSaved: (SmartBlock) -> Unit, onFailure: () -> Unit) {
        val key = request.conversationId to request.blockId
        pending[key] = Pending(request.copy(values = request.values.toMap()), onSaved, onFailure)
        if (jobs[key] != null) return
        jobs[key] = scope.launch {
            try {
                delay(300)
                while (true) {
                    val update = pending.remove(key) ?: break
                    try {
                        val result = save(update.request)
                        update.onSaved(result.block)
                    } catch (cancelled: CancellationException) {
                        pending.putIfAbsent(key, update)
                        throw cancelled
                    } catch (_: Exception) {
                        pending.putIfAbsent(key, update)
                        update.onFailure()
                        break
                    }
                    if (pending.containsKey(key)) delay(300)
                }
            } finally {
                jobs.remove(key)
            }
        }
    }
}

object ChatVisualSaves {
    val queue = VisualSaveQueue(CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)) {
        ApiClient.api.updateChatVisual(it)
    }
}
