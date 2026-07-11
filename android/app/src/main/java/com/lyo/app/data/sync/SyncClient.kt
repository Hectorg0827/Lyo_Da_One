package com.lyo.app.data.sync

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyo.app.BuildConfig
import com.lyo.app.data.TokenManager
import com.lyo.app.data.api.ApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit
import kotlin.math.min

/** One event from the cross-device sync channel. */
data class SyncEvent(
    val eventType: String,
    val payload: JsonObject,
)

/**
 * Cross-device sync client for the backend's Multi-Device Sync service
 * (LyoBackendJune lyo_app/routers/sync.py) — the Android counterpart of
 * the web client's lib/sync.ts and iOS's SyncService.swift.
 *
 * Connects a websocket to /api/v1/sync/ws so this device receives
 * real-time events when the same account acts on another platform.
 */
object SyncClient {

    private const val HEARTBEAT_MS = 30_000L
    private const val RECONNECT_BASE_MS = 2_000L
    private const val RECONNECT_MAX_MS = 60_000L

    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var socket: WebSocket? = null
    private var heartbeatJob: Job? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempt = 0
    @Volatile private var shouldRun = false

    /** This device's id, assigned by the server on connect. */
    @Volatile var deviceId: String? = null
        private set

    private val _events = MutableSharedFlow<SyncEvent>(extraBufferCapacity = 64)

    /** Collect from Compose/ViewModels to react to cross-device activity. */
    val events: SharedFlow<SyncEvent> = _events

    /** Start (or restart) the sync connection. Safe to call repeatedly. */
    fun connect() {
        shouldRun = true
        open()
    }

    /** Stop syncing (e.g. on logout). */
    fun disconnect() {
        shouldRun = false
        teardown()
    }

    /** Tell other devices this one is (or stopped) typing. */
    fun sendTyping(isTyping: Boolean) {
        socket?.send(
            ApiClient.gson.toJson(mapOf("type" to "typing", "is_typing" to isTyping))
        )
    }

    @Synchronized
    private fun open() {
        if (!shouldRun || socket != null) return
        val token = TokenManager.accessToken
        if (token == null) {
            // Auth state can flip before the token is persisted; retry with
            // backoff instead of staying offline until the next login.
            onSocketClosed()
            return
        }

        val wsBase = BuildConfig.API_BASE_URL
            .replaceFirst("https://", "wss://")
            .replaceFirst("http://", "ws://")
            .trimEnd('/')
        val url = "$wsBase/api/v1/sync/ws" +
            "?token=$token&device_type=mobile_android&device_name=LYO%20Android"

        socket = client.newWebSocket(
            Request.Builder().url(url).build(),
            object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: okhttp3.Response) {
                    reconnectAttempt = 0
                    heartbeatJob?.cancel()
                    heartbeatJob = scope.launch {
                        while (isActive) {
                            delay(HEARTBEAT_MS)
                            webSocket.send("""{"type":"heartbeat"}""")
                        }
                    }
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    val json = try {
                        JsonParser.parseString(text).asJsonObject
                    } catch (e: Exception) {
                        return
                    }
                    val type = json.get("event_type")?.asString ?: return
                    if (type == "connected") {
                        deviceId = json.get("device_id")?.asString
                    }
                    _events.tryEmit(SyncEvent(type, json))
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: okhttp3.Response?) {
                    onSocketClosed()
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    onSocketClosed()
                }
            }
        )
    }

    @Synchronized
    private fun onSocketClosed() {
        heartbeatJob?.cancel()
        heartbeatJob = null
        socket = null
        deviceId = null
        if (shouldRun && reconnectJob == null) {
            val delayMs = min(RECONNECT_BASE_MS shl reconnectAttempt, RECONNECT_MAX_MS)
            reconnectAttempt += 1
            reconnectJob = scope.launch {
                delay(delayMs)
                synchronized(this@SyncClient) { reconnectJob = null }
                open()
            }
        }
    }

    @Synchronized
    private fun teardown() {
        heartbeatJob?.cancel()
        heartbeatJob = null
        reconnectJob?.cancel()
        reconnectJob = null
        socket?.close(1000, "client disconnect")
        socket = null
        deviceId = null
    }
}
