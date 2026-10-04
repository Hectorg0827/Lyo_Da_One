package com.lyo.app.ui.screens.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import java.util.UUID

enum class ChatVoiceState {
    OFF,
    LISTENING,
    THINKING,
    SPEAKING,
    ERROR,
}

/**
 * Android presentation layer for canonical Chat.
 *
 * Microphone -> Android STT -> the same /lyo2/chat/stream request with
 * response_channel=voice -> the same InteractionContract/memory/tools ->
 * this controller speaks the returned text. It never owns an AI session.
 */
class ChatVoiceController(context: Context) {
    var onStateChanged: (ChatVoiceState) -> Unit = {}
    var onTranscript: (String) -> Unit = {}
    var onFinalUtterance: (String) -> Unit = {}
    var onBargeIn: () -> Unit = {}

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var active = false
    private var waitingForResponse = false
    private var state = ChatVoiceState.OFF

    init {
        textToSpeech = TextToSpeech(appContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                textToSpeech?.language = Locale.getDefault()
                textToSpeech?.setSpeechRate(0.98f)
            }
        }
        textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                mainHandler.post {
                    if (active) startListening() else updateState(ChatVoiceState.OFF)
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    if (active) startListening() else updateState(ChatVoiceState.ERROR)
                }
            }
        })
    }

    fun start() {
        active = true
        waitingForResponse = false
        startListening()
    }

    fun stop() {
        active = false
        waitingForResponse = false
        recognizer?.cancel()
        textToSpeech?.stop()
        onTranscript("")
        updateState(ChatVoiceState.OFF)
    }

    /**
     * Learner takes the floor while Lyo is speaking or thinking.
     * The screen cancels only the in-flight canonical stream through onBargeIn.
     */
    fun bargeIn() {
        active = true
        waitingForResponse = false
        textToSpeech?.stop()
        recognizer?.cancel()
        onBargeIn()
        startListening()
    }

    fun responseReady(rawText: String) {
        waitingForResponse = false
        val spoken = sanitizeForSpeech(rawText)
        if (!active) return
        if (spoken.isBlank()) {
            startListening()
            return
        }
        if (!ttsReady) {
            updateState(ChatVoiceState.ERROR)
            startListening()
            return
        }

        recognizer?.cancel()
        updateState(ChatVoiceState.SPEAKING)
        textToSpeech?.speak(
            spoken,
            TextToSpeech.QUEUE_FLUSH,
            null,
            "chat-voice-" + UUID.randomUUID().toString(),
        )
    }

    private fun startListening() {
        if (!active || waitingForResponse) return
        if (!SpeechRecognizer.isRecognitionAvailable(appContext)) {
            updateState(ChatVoiceState.ERROR)
            return
        }

        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(appContext).also { speech ->
            speech.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    updateState(ChatVoiceState.LISTENING)
                    onTranscript("")
                }

                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onPartialResults(partialResults: Bundle?) {
                    val text = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        .orEmpty()
                    if (text.isNotEmpty()) onTranscript(text)
                }

                override fun onResults(results: Bundle?) {
                    val text = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        .orEmpty()
                    if (text.isBlank()) {
                        if (active) mainHandler.postDelayed({ startListening() }, 180)
                        return
                    }
                    waitingForResponse = true
                    updateState(ChatVoiceState.THINKING)
                    onTranscript(text)
                    onFinalUtterance(text)
                }

                override fun onError(error: Int) {
                    val benign = error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
                        error == SpeechRecognizer.ERROR_CLIENT
                    if (active && !waitingForResponse && benign) {
                        mainHandler.postDelayed({ startListening() }, 220)
                    } else if (!benign) {
                        updateState(ChatVoiceState.ERROR)
                    }
                }
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 850L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 650L)
            }

            try {
                speech.startListening(intent)
            } catch (_: SecurityException) {
                updateState(ChatVoiceState.ERROR)
            }
        }
    }

    private fun updateState(next: ChatVoiceState) {
        state = next
        onStateChanged(next)
    }

    fun release() {
        active = false
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        updateState(ChatVoiceState.OFF)
    }

    companion object {
        fun sanitizeForSpeech(text: String): String = text
            .replace(Regex("【[^】]+】"), "")
            .replace(Regex("\\[([^]]+)]\\([^)]+\\)"), "$1")
            .replace(Regex("[*_#>|]"), "")
            .replace(Regex("\\s+"), " ")
            .trim()
    }
}
