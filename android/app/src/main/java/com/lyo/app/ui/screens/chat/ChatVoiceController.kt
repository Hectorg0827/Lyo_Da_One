package com.lyo.app.ui.screens.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.lyo.app.ui.screens.classroom.ClassroomVoicePlayer
import java.util.Locale

/**
 * Conversational speech transport for Chat.
 *
 * This class deliberately contains no AI logic. Final transcripts are handed
 * back to ChatScreen and sent through ChatStreamClient -> /lyo2/chat/stream,
 * where the canonical interaction contract owns intent and teaching behavior.
 * Spoken output is only a renderer using the same shared Lyo voice as Classroom.
 */
class ChatVoiceController(
    context: Context,
    private val onTranscript: (String, Boolean) -> Unit,
    private val onState: (State) -> Unit,
) {
    enum class State { OFF, LISTENING, THINKING, SPEAKING, ERROR }

    private val appContext = context.applicationContext
    private val voicePlayer = ClassroomVoicePlayer(appContext)
    private var recognizer: SpeechRecognizer? = null
    private var active = false
    private var interruptedPreviousTurn = false

    fun isActive(): Boolean = active

    fun start() {
        active = true
        startListening()
    }

    fun stop() {
        active = false
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        voicePlayer.stop()
        onState(State.OFF)
    }

    fun close() {
        stop()
        voicePlayer.close()
    }

    fun interrupt() {
        if (!active) return
        interruptedPreviousTurn = true
        voicePlayer.stop()
        startListening()
    }

    fun markThinking() {
        if (active) onState(State.THINKING)
    }

    fun speak(text: String, language: String = Locale.getDefault().toLanguageTag()) {
        if (!active || text.isBlank()) {
            if (active) startListening()
            return
        }
        recognizer?.cancel()
        onState(State.SPEAKING)
        voicePlayer.play(text, language) {
            if (active) startListening()
        }
    }

    fun failAndResume() {
        if (!active) return
        onState(State.ERROR)
        startListening()
    }

    fun startListening() {
        if (!active || !SpeechRecognizer.isRecognitionAvailable(appContext)) {
            if (active) onState(State.ERROR)
            return
        }
        recognizer?.cancel()
        recognizer?.destroy()

        val next = SpeechRecognizer.createSpeechRecognizer(appContext)
        recognizer = next
        next.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { onState(State.LISTENING) }
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit

            override fun onError(error: Int) {
                if (!active) return
                if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    startListening()
                } else {
                    onState(State.ERROR)
                }
            }

            override fun onResults(results: Bundle?) {
                if (!active) return
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                    ?.trim()
                    .orEmpty()
                if (text.isBlank()) {
                    startListening()
                    return
                }
                val interrupted = interruptedPreviousTurn
                interruptedPreviousTurn = false
                onState(State.THINKING)
                onTranscript(text, interrupted)
            }

            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        next.startListening(intent)
    }
}
