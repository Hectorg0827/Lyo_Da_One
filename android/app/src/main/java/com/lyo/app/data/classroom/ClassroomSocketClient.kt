package com.lyo.app.data.classroom

import com.lyo.app.BuildConfig
import com.lyo.app.data.TokenManager
import com.lyo.app.data.api.ApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

/**
 * The AI Classroom real-time client — Android counterpart of web's
 * `buildClassroomWsUrl`/classroom-store.ts connection logic and iOS's
 * `LivingClassroomService`. Structurally mirrors
 * data/sync/SyncClient.kt (same heartbeat + exponential-backoff-reconnect
 * shape) rather than the SSE-based ChatStreamClient, since the classroom
 * needs a persistent bidirectional socket, not a one-shot request/response
 * stream.
 *
 * Connects to LyoBackendJune's `/api/v1/classroom/ws/connect` endpoint. The
 * connection URL itself carries the full session/topic/mode/duration
 * context — there is no separate hello/handshake message after opening the
 * socket, matching the web contract exactly (see
 * web/src/lib/classroom-contract.mjs `buildClassroomWsUrl`).
 */
enum class ClassroomConnectionState { IDLE, CONNECTING, CONNECTED, RECONNECTING, AUTH_REQUIRED }

object ClassroomSocketClient {

    private const val RECONNECT_BASE_MS = 2_000L
    private const val RECONNECT_MAX_MS = 60_000L

    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var socket: WebSocket? = null
    private var reconnectJob: Job? = null
    private var reconnectAttempt = 0
    @Volatile private var shouldRun = false
    private var pendingConnection: ConnectionParams? = null

    private val _events = MutableSharedFlow<ClassroomServerEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<ClassroomServerEvent> = _events
    private val _connectionState = MutableStateFlow(ClassroomConnectionState.IDLE)
    val connectionState: StateFlow<ClassroomConnectionState> = _connectionState

    private data class ConnectionParams(
        val sessionId: String,
        val topic: String,
        val mode: String,
        val durationMinutes: Int,
        val reducedMotion: Boolean,
        val objective: String?,
        val difficulty: String?,
        val courseId: String?,
        val reviewConceptId: String?,
    )

    /**
     * Opens (or restarts, if a different lesson) the classroom connection.
     * `sessionId` defaults to `topic` when blank, mirroring the web
     * contract's `connection.sessionId || connection.topic` fallback.
     */
    fun connect(
        topic: String,
        sessionId: String = topic,
        mode: String = "solo",
        durationMinutes: Int = 10,
        reducedMotion: Boolean = false,
        objective: String? = null,
        difficulty: String? = null,
        courseId: String? = null,
        reviewConceptId: String? = null,
    ) {
        pendingConnection = ConnectionParams(
            sessionId = sessionId.ifBlank { topic },
            topic = topic,
            mode = if (mode in VALID_MODES) mode else "solo",
            durationMinutes = max(3, min(60, durationMinutes)),
            reducedMotion = reducedMotion,
            objective = objective,
            difficulty = difficulty?.takeIf { it in VALID_DIFFICULTIES },
            courseId = courseId?.takeIf { it.isNotBlank() },
            reviewConceptId = reviewConceptId?.takeIf { it.isNotBlank() },
        )
        shouldRun = true
        reconnectAttempt = 0
        teardownSocketOnly()
        _connectionState.value = ClassroomConnectionState.CONNECTING
        open()
    }

    fun disconnect() {
        shouldRun = false
        pendingConnection = null
        teardown()
        _connectionState.value = ClassroomConnectionState.IDLE
    }

    fun send(envelope: UserActionEnvelope): Boolean =
        socket?.send(ApiClient.gson.toJson(envelope)) == true

    @Synchronized
    private fun open() {
        if (!shouldRun || socket != null) return
        val params = pendingConnection ?: return
        val token = TokenManager.accessToken
        if (token == null) {
            _connectionState.value = ClassroomConnectionState.AUTH_REQUIRED
            _events.tryEmit(
                ClassroomServerEvent.ErrorEvent(
                    "Sign in to start a secure AI classroom.",
                    fatal = true,
                ),
            )
            return
        }

        // OkHttp upgrades this HTTP request to a WebSocket itself. HttpUrl
        // rejects ws/wss schemes before a network request can be made.
        val urlBuilder = classroomConnectionUrl(BuildConfig.API_BASE_URL).newBuilder()
            .addQueryParameter("session_id", params.sessionId)
            .addQueryParameter("client_contract_version", "2")
            .addQueryParameter("topic", params.topic)
            .addQueryParameter("mode", params.mode)
            .addQueryParameter("duration_minutes", params.durationMinutes.toString())
            .addQueryParameter("language", "auto")
            .addQueryParameter("reduced_motion", params.reducedMotion.toString())
            .addQueryParameter("token", token)
        params.courseId?.let { urlBuilder.addQueryParameter("course_id", it) }
        params.reviewConceptId?.let { urlBuilder.addQueryParameter("review_concept_id", it) }
        params.objective?.let { urlBuilder.addQueryParameter("objective", it) }
        params.difficulty?.let { urlBuilder.addQueryParameter("difficulty", it) }

        val request = Request.Builder()
            .url(urlBuilder.build())
            // Belt-and-suspenders alongside the query token, matching iOS's
            // LivingClassroomService (it sends both).
            .header("Authorization", "Bearer $token")
            .build()

        socket = client.newWebSocket(
            request,
            object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: okhttp3.Response) {
                    synchronized(this@ClassroomSocketClient) {
                        if (socket !== webSocket || !shouldRun) return
                        reconnectAttempt = 0
                        _connectionState.value = ClassroomConnectionState.CONNECTED
                    }
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    if (socket !== webSocket || !shouldRun) return
                    val event = parseServerEvent(text) ?: return
                    _events.tryEmit(event)
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: okhttp3.Response?) {
                    onSocketClosed(webSocket)
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    onSocketClosed(webSocket)
                }
            },
        )
    }

    @Synchronized
    private fun onSocketClosed(closedSocket: WebSocket) {
        // A former session's close callback may arrive after a new lesson
        // starts. It must never erase the replacement socket or reconnect
        // the wrong learner seat.
        if (socket !== closedSocket) return
        socket = null
        if (shouldRun && reconnectJob == null) {
            _connectionState.value = ClassroomConnectionState.RECONNECTING
            val delayMs = min(RECONNECT_BASE_MS shl reconnectAttempt.coerceAtMost(5), RECONNECT_MAX_MS)
            reconnectAttempt = (reconnectAttempt + 1).coerceAtMost(6)
            reconnectJob = scope.launch {
                delay(delayMs)
                synchronized(this@ClassroomSocketClient) { reconnectJob = null }
                open()
            }
        }
    }

    /** Reopen the same server seat, never automatically resubmit an answer. */
    @Synchronized
    fun reconnectNow() {
        if (!shouldRun || socket != null) return
        reconnectJob?.cancel()
        reconnectJob = null
        _connectionState.value = ClassroomConnectionState.RECONNECTING
        open()
    }

    /** Closes the live socket without touching reconnect state — used when
     *  `connect()` is called again for a new lesson while one is already open. */
    @Synchronized
    private fun teardownSocketOnly() {
        reconnectJob?.cancel()
        reconnectJob = null
        socket?.close(1000, "reconnecting for new lesson")
        socket = null
    }

    @Synchronized
    private fun teardown() {
        reconnectJob?.cancel()
        reconnectJob = null
        socket?.close(1000, "client disconnect")
        socket = null
        reconnectAttempt = 0
    }
}

private val VALID_MODES = setOf("solo", "classroom", "challenge", "review")
private val VALID_DIFFICULTIES = setOf("beginner", "intermediate", "advanced")

/** ISO-8601 timestamp for outgoing UserActionEnvelope.timestamp, UTC, matching
 *  `new Date().toISOString()` on web and `ISO8601DateFormatter()` on iOS. */
fun isoTimestampNow(): String {
    val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    format.timeZone = TimeZone.getTimeZone("UTC")
    return format.format(Date())
}
