package com.lyo.app.ui.screens.classroom

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.util.Base64
import com.google.gson.JsonParser
import com.lyo.app.BuildConfig
import com.lyo.app.data.api.ApiClient
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.util.Locale

/**
 * Plays the same backend-rendered teacher audio as Web and iOS.
 * Android TextToSpeech is a locale-aware emergency fallback only.
 */
internal class ClassroomVoicePlayer(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var playbackJob: Job? = null
    private var activeCall: Call? = null
    private var player: MediaPlayer? = null
    private var audioFile: File? = null
    private var generation = 0
    private var enabled = true
    private val deviceTts = TextToSpeech(appContext) { }

    fun setEnabled(value: Boolean) {
        enabled = value
        if (!value) stop()
    }

    fun play(text: String, language: String) {
        stop()
        if (!enabled || text.isBlank()) return
        val requestedGeneration = generation
        playbackJob = scope.launch {
            try {
                val file = fetchSharedVoice(text, language)
                if (requestedGeneration != generation || !enabled) {
                    file.delete()
                    return@launch
                }
                playFile(file, requestedGeneration)
            } catch (_: CancellationException) {
                // A learner action or new scene owns the floor now.
            } catch (_: Exception) {
                if (requestedGeneration == generation && enabled) {
                    playLocalizedDeviceFallback(text, language)
                }
            }
        }
    }

    fun stop() {
        generation += 1
        activeCall?.cancel()
        activeCall = null
        playbackJob?.cancel()
        playbackJob = null
        player?.setOnCompletionListener(null)
        player?.setOnErrorListener(null)
        player?.stopSafely()
        player?.release()
        player = null
        audioFile?.delete()
        audioFile = null
        deviceTts.stop()
    }

    fun close() {
        stop()
        deviceTts.shutdown()
        scope.cancel()
    }

    private suspend fun fetchSharedVoice(text: String, language: String): File =
        withContext(Dispatchers.IO) {
            val body = ApiClient.gson.toJson(
                mapOf(
                    "text" to text,
                    "voice" to "nova",
                    "format" to "mp3",
                    "speed" to 0.98,
                    "content_type" to "explanation",
                    "language" to language,
                ),
            ).toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url(BuildConfig.API_BASE_URL.trimEnd('/') + "/api/v1/tts/synthesize")
                .post(body)
                .build()
            val call = ApiClient.okHttp.newCall(request)
            activeCall = call
            call.execute().use { response ->
                if (!response.isSuccessful) {
                    error("Shared voice returned ${response.code}")
                }
                val root = JsonParser.parseString(response.body?.string().orEmpty()).asJsonObject
                val encoded = root.get("audio_base64")?.asString
                    ?: error("Shared voice returned no audio")
                val bytes = Base64.decode(encoded, Base64.DEFAULT)
                File.createTempFile("lyo_classroom_", ".mp3", appContext.cacheDir)
                    .apply { writeBytes(bytes) }
            }.also {
                activeCall = null
            }
        }

    private fun playFile(file: File, requestedGeneration: Int) {
        audioFile = file
        val nextPlayer = MediaPlayer().apply {
            setDataSource(appContext, Uri.fromFile(file))
            setOnCompletionListener {
                if (requestedGeneration == generation) releaseCurrentPlayer()
            }
            setOnErrorListener { _, _, _ ->
                releaseCurrentPlayer()
                true
            }
            prepare()
            start()
        }
        player = nextPlayer
    }

    private fun releaseCurrentPlayer() {
        player?.release()
        player = null
        audioFile?.delete()
        audioFile = null
    }

    private fun playLocalizedDeviceFallback(text: String, language: String) {
        val tag = if (language.equals("auto", ignoreCase = true)) {
            when {
                Regex("[¿¡ñáéíóúü]", RegexOption.IGNORE_CASE).containsMatchIn(text) -> "es-US"
                else -> Locale.getDefault().toLanguageTag()
            }
        } else {
            language
        }
        deviceTts.language = Locale.forLanguageTag(tag)
        deviceTts.setSpeechRate(0.98f)
        deviceTts.speak(
            text,
            TextToSpeech.QUEUE_FLUSH,
            null,
            "lyo-classroom-${generation}",
        )
    }
}

private fun MediaPlayer.stopSafely() {
    runCatching { stop() }
}
