package com.lyo.app.ui.screens.chat

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.lyo.app.BuildConfig
import com.lyo.app.data.api.ApiClient
import java.io.File
import java.util.Collections
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Neural voice player for canonical Chat.
 *
 * This class does not own an AI path. It receives text already produced by
 * /api/v1/lyo2/chat/stream and only renders that text as audio. Each segment
 * begins synthesis as soon as it arrives, so later segments can prefetch while
 * the current segment is playing. Android TextToSpeech is an offline/device
 * fallback only.
 */
class ChatVoicePlayer(context: Context) {
    private data class QueuedSpeech(
        val text: String,
        val language: String,
        val utteranceId: String,
        val generation: Int,
        val audio: Deferred<File>,
        val onComplete: (() -> Unit)?,
    )

    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val queue = ArrayDeque<QueuedSpeech>()
    private val activeCalls = Collections.synchronizedSet(mutableSetOf<Call>())

    private var generation = 0
    private var drainJob: Job? = null
    private var player: MediaPlayer? = null
    private var audioFile: File? = null
    private var fallbackContinuation: CancellableContinuation<Unit>? = null
    private var fallbackUtteranceId: String? = null
    private var fallbackReady = false

    private val deviceTts = TextToSpeech(appContext) { status ->
        fallbackReady = status == TextToSpeech.SUCCESS
    }.apply {
        setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                finishFallback(utteranceId)
            }

            @Deprecated("Android callback")
            override fun onError(utteranceId: String?) {
                finishFallback(utteranceId)
            }
        })
    }

    fun enqueue(
        text: String,
        language: String,
        utteranceId: String,
        onComplete: (() -> Unit)? = null,
    ) {
        val spoken = text.trim()
        if (spoken.isEmpty()) {
            onComplete?.invoke()
            return
        }

        val requestedGeneration = generation
        // Synthesis starts now, not when this item reaches the front of the
        // playback queue. That overlaps network/TTS latency with prior audio.
        val audio = scope.async(Dispatchers.IO) {
            fetchSharedVoice(spoken, language, requestedGeneration)
        }
        queue.addLast(
            QueuedSpeech(
                text = spoken,
                language = language,
                utteranceId = utteranceId,
                generation = requestedGeneration,
                audio = audio,
                onComplete = onComplete,
            )
        )
        drainIfNeeded()
    }

    fun speak(
        text: String,
        language: String,
        utteranceId: String,
        onComplete: (() -> Unit)? = null,
    ) {
        stop()
        enqueue(text, language, utteranceId, onComplete)
    }

    fun stop() {
        generation += 1
        drainJob?.cancel()
        drainJob = null
        while (queue.isNotEmpty()) {
            queue.removeFirst().audio.cancel()
        }
        synchronized(activeCalls) {
            activeCalls.forEach { it.cancel() }
            activeCalls.clear()
        }
        releasePlayer()
        fallbackContinuation?.cancel()
        fallbackContinuation = null
        fallbackUtteranceId = null
        deviceTts.stop()
    }

    fun close() {
        stop()
        deviceTts.shutdown()
        scope.cancel()
    }

    private fun drainIfNeeded() {
        if (drainJob?.isActive == true) return
        drainJob = scope.launch {
            try {
                while (queue.isNotEmpty()) {
                    val item = queue.removeFirst()
                    if (item.generation != generation) {
                        item.audio.cancel()
                        continue
                    }
                    try {
                        val file = item.audio.await()
                        if (item.generation != generation) {
                            file.delete()
                            continue
                        }
                        playFile(file, item.generation)
                    } catch (_: CancellationException) {
                        break
                    } catch (_: Exception) {
                        if (item.generation == generation) {
                            playDeviceFallback(item)
                        }
                    } finally {
                        if (item.generation == generation) {
                            item.onComplete?.invoke()
                        }
                    }
                }
            } finally {
                drainJob = null
                if (queue.isNotEmpty()) drainIfNeeded()
            }
        }
    }

    private suspend fun fetchSharedVoice(
        text: String,
        language: String,
        requestedGeneration: Int,
    ): File = withContext(Dispatchers.IO) {
        if (requestedGeneration != generation) throw CancellationException()

        val body = ApiClient.gson.toJson(
            mapOf(
                "text" to text,
                "language" to language,
                "speed" to 1.02,
                "format" to "mp3",
            ),
        ).toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url(BuildConfig.API_BASE_URL.trimEnd('/') + "/api/v1/tts/synthesize/stream")
            .post(body)
            .build()
        val call = ApiClient.okHttp.newCall(request)
        activeCalls.add(call)
        try {
            if (requestedGeneration != generation) throw CancellationException()
            call.timeout().timeout(10, TimeUnit.SECONDS)
            call.execute().use { response ->
                if (!response.isSuccessful) {
                    error("Shared voice returned HTTP ${response.code}")
                }
                val bytes = response.body?.bytes() ?: error("Shared voice returned no audio")
                if (requestedGeneration != generation) throw CancellationException()
                File.createTempFile("lyo_chat_voice_", ".mp3", appContext.cacheDir).apply {
                    writeBytes(bytes)
                }
            }
        } finally {
            activeCalls.remove(call)
        }
    }

    private suspend fun playFile(file: File, requestedGeneration: Int) {
        audioFile = file
        try {
            suspendCancellableCoroutine<Unit> { continuation ->
                val nextPlayer = MediaPlayer().apply {
                    setDataSource(appContext, Uri.fromFile(file))
                    setOnPreparedListener {
                        if (requestedGeneration == generation && continuation.isActive) {
                            start()
                        } else {
                            release()
                        }
                    }
                    setOnCompletionListener {
                        if (continuation.isActive) continuation.resume(Unit)
                    }
                    setOnErrorListener { _, _, _ ->
                        if (continuation.isActive) continuation.resume(Unit)
                        true
                    }
                    prepareAsync()
                }
                player = nextPlayer
                continuation.invokeOnCancellation {
                    runCatching { nextPlayer.stop() }
                    nextPlayer.release()
                }
            }
        } finally {
            releasePlayer()
        }
    }

    private suspend fun playDeviceFallback(item: QueuedSpeech) {
        if (!fallbackReady || item.generation != generation) return
        val language = if (item.language.equals("auto", ignoreCase = true)) {
            Locale.getDefault()
        } else {
            Locale.forLanguageTag(item.language)
        }
        deviceTts.language = language
        deviceTts.setSpeechRate(1.02f)

        suspendCancellableCoroutine<Unit> { continuation ->
            fallbackContinuation = continuation
            fallbackUtteranceId = item.utteranceId
            continuation.invokeOnCancellation {
                if (fallbackUtteranceId == item.utteranceId) {
                    deviceTts.stop()
                    fallbackContinuation = null
                    fallbackUtteranceId = null
                }
            }
            val result = deviceTts.speak(
                item.text,
                TextToSpeech.QUEUE_FLUSH,
                null,
                item.utteranceId,
            )
            if (result == TextToSpeech.ERROR && continuation.isActive) {
                fallbackContinuation = null
                fallbackUtteranceId = null
                continuation.resume(Unit)
            }
        }
    }

    private fun finishFallback(utteranceId: String?) {
        scope.launch {
            if (utteranceId != fallbackUtteranceId) return@launch
            val continuation = fallbackContinuation
            fallbackContinuation = null
            fallbackUtteranceId = null
            if (continuation?.isActive == true) continuation.resume(Unit)
        }
    }

    private fun releasePlayer() {
        player?.setOnCompletionListener(null)
        player?.setOnErrorListener(null)
        runCatching { player?.stop() }
        player?.release()
        player = null
        audioFile?.delete()
        audioFile = null
    }
}
