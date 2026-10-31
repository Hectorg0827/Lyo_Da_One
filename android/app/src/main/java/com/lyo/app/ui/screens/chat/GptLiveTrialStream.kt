package com.lyo.app.ui.screens.chat

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.util.Base64
import com.google.gson.JsonParser
import com.lyo.app.BuildConfig
import com.lyo.app.data.TokenManager
import com.lyo.app.data.api.ApiClient
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

/**
 * Experimental continuous 24 kHz PCM16 full-duplex bridge.
 *
 * The legacy SpeechRecognizer/TTS pipeline stays untouched. This code is
 * compiled into production but cannot run unless a staging-only build flag
 * is enabled, and the backend also verifies separate server-side gates.
 * No OpenAI API credentials ever reach the device.
 */
internal class GptLiveTrialStream(
    private val context: Context,
    private val scope: CoroutineScope,
    private val callbacks: Callbacks,
) {
    data class Callbacks(
        val onReady: () -> Unit,
        val onTranscript: (String, String) -> Unit,
        val onEnded: (String) -> Unit,
        val onError: (String) -> Unit,
    )

    private val active = AtomicBoolean(false)
    private val outgoingAudio = LinkedBlockingQueue<ByteArray>(48)
    private var socket: WebSocket? = null
    private var recorder: AudioRecord? = null
    private var player: AudioTrack? = null
    private var echoCanceler: AcousticEchoCanceler? = null
    private var captureJob: Job? = null
    private var playbackJob: Job? = null
    private var connectJob: Job? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var previousAudioMode: Int? = null
    private var previousSpeakerphone: Boolean? = null

    fun start() {
        if (!active.compareAndSet(false, true)) return
        if (BuildConfig.API_ENVIRONMENT != "staging" || !BuildConfig.GPT_LIVE_TRIAL_UI) {
            fail("This voice trial is restricted to an approved staging APK.")
            return
        }
        connectJob = scope.launch(Dispatchers.IO) {
            try {
                val base = BuildConfig.API_BASE_URL.trimEnd('/')
                require(base.startsWith("https://")) { "A secure staging connection is required." }
                val bearer = TokenManager.accessToken
                    ?: error("Please sign in to LYO before starting the voice trial.")
                val request = Request.Builder()
                    .url("$base/api/v1/gpt-live-trial/ticket")
                    .header("Authorization", "Bearer $bearer")
                    .post("{}".toRequestBody("application/json".toMediaType()))
                    .build()
                val ticket = ApiClient.okHttp.newCall(request).execute().use { response ->
                    when (response.code) {
                        403 -> error("The trial is safely disabled until staging verification.")
                        429 -> error("The $10 trial budget has been reached.")
                    }
                    if (!response.isSuccessful) error("Trial unavailable (HTTP ${response.code}).")
                    val reply = JsonParser.parseString(response.body?.string().orEmpty()).asJsonObject
                    reply.get("ticket")?.asString?.takeIf { it.length >= 30 }
                        ?: error("Trial ticket was not issued.")
                }
                if (!active.get()) return@launch
                val websocketUrl = "wss://" + base.removePrefix("https://") +
                    "/api/v1/gpt-live-trial/stream"
                val websocketRequest = Request.Builder()
                    .url(websocketUrl)
                    .header("X-Lyo-Live-Ticket", ticket)
                    .build()
                socket = ApiClient.okHttp.newBuilder()
                    .readTimeout(0, TimeUnit.MILLISECONDS)
                    .build()
                    .newWebSocket(websocketRequest, object : WebSocketListener() {
                        override fun onMessage(webSocket: WebSocket, text: String) {
                            if (!active.get()) return
                            try {
                                val json = JsonParser.parseString(text).asJsonObject
                                when (json.get("type")?.asString) {
                                    "ready" -> {
                                        startAudio()
                                        callbacks.onReady()
                                    }
                                    "audio" -> {
                                        val encoded = json.get("audio")?.asString ?: return
                                        val audio = Base64.decode(encoded, Base64.DEFAULT)
                                        if (audio.size <= 96_000) {
                                            if (!outgoingAudio.offer(audio)) {
                                                // Drop the oldest packet to avoid an ever-growing
                                                // playback delay after the user interrupts Lyo.
                                                outgoingAudio.poll()
                                                outgoingAudio.offer(audio)
                                            }
                                        }
                                    }
                                    "transcript" -> {
                                        val role = json.get("role")?.asString.orEmpty()
                                        val delta = json.get("text")?.asString.orEmpty()
                                        if (role == "user" && delta.isNotBlank()) {
                                            // True barge-in: stop buffered outgoing speech as
                                            // soon as GPT-Live hears the learner.
                                            outgoingAudio.clear()
                                            runCatching {
                                                player?.pause()
                                                player?.flush()
                                                player?.play()
                                            }
                                        }
                                        if (delta.isNotBlank() && (role == "user" || role == "assistant")) {
                                            callbacks.onTranscript(role, delta)
                                        }
                                    }
                                    "ended" -> {
                                        callbacks.onEnded(json.get("reason")?.asString ?: "ended")
                                        stop()
                                    }
                                    "error" -> fail("Voice trial ended safely. Please try later.")
                                }
                            } catch (e: Exception) {
                                fail("Could not process a live audio event.")
                            }
                        }

                        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                            if (active.get()) fail("Voice connection was interrupted.")
                        }

                        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                            if (active.get()) {
                                callbacks.onEnded("connection_closed")
                                stop()
                            }
                        }
                    })
            } catch (e: Exception) {
                if (active.get()) fail(e.message ?: "Unable to start the trial.")
            }
        }
    }

    private fun startAudio() {
        if (!active.get() || recorder != null) return
        try {
            val recordMin = AudioRecord.getMinBufferSize(
                24_000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
            )
            val playMin = AudioTrack.getMinBufferSize(
                24_000, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
            )
            require(recordMin > 0 && playMin > 0) { "24 kHz live audio is unavailable on this phone." }
            previousAudioMode = audioManager.mode
            previousSpeakerphone = audioManager.isSpeakerphoneOn
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = true
            recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                24_000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(recordMin, 4_800),
            )
            require(recorder?.state == AudioRecord.STATE_INITIALIZED) { "Microphone initialization failed." }
            if (AcousticEchoCanceler.isAvailable()) {
                echoCanceler = AcousticEchoCanceler.create(recorder!!.audioSessionId)
                echoCanceler?.enabled = true
            }
            player = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(24_000)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(maxOf(playMin, 9_600))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            require(player?.state == AudioTrack.STATE_INITIALIZED) { "Speaker initialization failed." }
            player?.play()
            recorder?.startRecording()
            captureJob = scope.launch(Dispatchers.IO) {
                val chunk = ByteArray(1_920) // 40 ms of 24 kHz mono PCM16.
                while (active.get()) {
                    val n = recorder?.read(chunk, 0, chunk.size, AudioRecord.READ_BLOCKING) ?: break
                    if (n > 0 && n % 2 == 0 && (socket?.queueSize() ?: Long.MAX_VALUE) < 128_000L) {
                        val payload = Base64.encodeToString(chunk, 0, n, Base64.NO_WRAP)
                        if (socket?.send("{\"type\":\"audio\",\"audio\":\"$payload\"}") != true) break
                    } else if (n < 0) break
                }
            }
            playbackJob = scope.launch(Dispatchers.IO) {
                while (active.get()) {
                    val bytes = outgoingAudio.poll(80, TimeUnit.MILLISECONDS) ?: continue
                    player?.write(bytes, 0, bytes.size, AudioTrack.WRITE_BLOCKING)
                }
            }
        } catch (e: Exception) {
            fail(e.message ?: "Audio devices could not start.")
        }
    }

    private fun fail(message: String) {
        if (active.get()) {
            callbacks.onError(message)
            stop()
        }
    }

    fun stop() {
        if (!active.getAndSet(false)) return
        runCatching { socket?.send("{\"type\":\"end\"}") }
        runCatching { socket?.close(1000, "trial ended") }
        connectJob?.cancel()
        captureJob?.cancel()
        playbackJob?.cancel()
        outgoingAudio.clear()
        runCatching { recorder?.stop() }
        runCatching { player?.pause() }
        runCatching { player?.flush() }
        runCatching { echoCanceler?.release() }
        runCatching { recorder?.release() }
        runCatching { player?.release() }
        recorder = null
        player = null
        previousAudioMode?.let { runCatching { audioManager.mode = it } }
        previousSpeakerphone?.let { runCatching { audioManager.isSpeakerphoneOn = it } }
    }
}
