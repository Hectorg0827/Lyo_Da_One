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
import java.util.ArrayDeque
import java.util.Locale
import java.util.UUID

/**
 * Turn-taking controller for Chat voice.
 *
 * It deliberately owns no AI logic. Speech is transcribed into ordinary Chat
 * text, and server-provided voice_delivery segments are rendered with Android
 * TTS. The same conversation id, interaction contract, learner state and tools
 * therefore remain authoritative.
 */
class ConversationalVoiceController(
    context: Context,
    private val onUtterance: (String) -> Unit,
    private val onBargeIn: () -> Unit,
    private val onPhaseChanged: (Phase) -> Unit,
    private val onPartialTranscript: (String) -> Unit,
) : RecognitionListener {

    enum class Phase { IDLE, LISTENING, THINKING, SPEAKING }

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var active = false
    private var phase = Phase.IDLE
    private var currentPartial = ""
    private var currentSpokenText = ""
    private val speechQueue = ArrayDeque<String>()
    private var silenceCommit: Runnable? = null

    init {
        tts = TextToSpeech(appContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale.getDefault()
                tts?.setSpeechRate(0.98f)
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                handler.post { speakNextOrListen() }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                handler.post { speakNextOrListen() }
            }
        })
    }

    fun start() {
        if (active) return
        active = true
        setPhase(Phase.LISTENING)
        startRecognition()
    }

    fun stop() {
        active = false
        cancelSilenceCommit()
        speechQueue.clear()
        currentSpokenText = ""
        tts?.stop()
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        currentPartial = ""
        onPartialTranscript("")
        setPhase(Phase.IDLE)
    }

    fun destroy() {
        stop()
        tts?.shutdown()
        tts = null
    }

    fun resumeListening() {
        if (!active) return
        setPhase(Phase.LISTENING)
        startRecognition()
    }

    fun markThinking() {
        if (!active) return
        setPhase(Phase.THINKING)
        // Keep recognition alive: if the learner changes their mind while the
        // model is thinking, the next transcript cancels that canonical turn.
        startRecognition()
    }

    fun speak(segments: List<String>, language: String = "auto") {
        if (!active) return
        speechQueue.clear()
        segments.map(String::trim).filter(String::isNotBlank).forEach(speechQueue::addLast)
        if (speechQueue.isEmpty()) {
            setPhase(Phase.LISTENING)
            startRecognition()
            return
        }

        if (language != "auto") {
            runCatching { tts?.language = Locale.forLanguageTag(language) }
        }
        setPhase(Phase.SPEAKING)
        // Recognition remains armed during playback for barge-in. Android's
        // recognizer has no app-level AEC controls, so partial transcripts that
        // simply mirror Lyo's current spoken segment are ignored below.
        startRecognition()
        speakNextOrListen()
    }

    private fun speakNextOrListen() {
        if (!active) return
        val next = speechQueue.removeFirstOrNull()
        if (next == null) {
            currentSpokenText = ""
            setPhase(Phase.LISTENING)
            startRecognition()
            return
        }
        if (!ttsReady) {
            speechQueue.addFirst(next)
            handler.postDelayed({ speakNextOrListen() }, 80)
            return
        }
        currentSpokenText = next
        val utteranceId = "lyo-voice-" + UUID.randomUUID().toString()
        tts?.speak(next, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun setPhase(next: Phase) {
        if (phase == next) return
        phase = next
        onPhaseChanged(next)
    }

    private fun startRecognition() {
        if (!active || !SpeechRecognizer.isRecognitionAvailable(appContext)) return
        if (recognizer == null) {
            recognizer = SpeechRecognizer.createSpeechRecognizer(appContext).also {
                it.setRecognitionListener(this)
            }
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
        }
        runCatching { recognizer?.startListening(intent) }
    }

    private fun restartRecognitionSoon() {
        if (!active) return
        handler.postDelayed({ if (active) startRecognition() }, 120)
    }

    private fun cancelSilenceCommit() {
        silenceCommit?.let(handler::removeCallbacks)
        silenceCommit = null
    }

    private fun normalize(value: String): String =
        value.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9áéíóúüñ ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun looksLikeSpeakerEcho(transcript: String): Boolean {
        if (phase != Phase.SPEAKING || currentSpokenText.isBlank()) return false
        val heard = normalize(transcript)
        val spoken = normalize(currentSpokenText)
        if (heard.length < 4 || spoken.length < 4) return false
        return spoken.contains(heard) || heard.contains(spoken.take(minOf(spoken.length, 32)))
    }

    private fun acceptTranscript(text: String, final: Boolean) {
        val clean = text.trim()
        if (clean.length < 2 || looksLikeSpeakerEcho(clean)) return

        if (phase == Phase.SPEAKING) {
            tts?.stop()
            speechQueue.clear()
            currentSpokenText = ""
            onBargeIn()
        } else if (phase == Phase.THINKING) {
            onBargeIn()
        }

        setPhase(Phase.LISTENING)
        currentPartial = clean
        onPartialTranscript(clean)
        cancelSilenceCommit()

        val commit = Runnable {
            if (!active) return@Runnable
            val utterance = currentPartial.trim()
            if (utterance.length < 2) return@Runnable
            currentPartial = ""
            onPartialTranscript("")
            setPhase(Phase.THINKING)
            onUtterance(utterance)
        }
        silenceCommit = commit
        handler.postDelayed(commit, if (final) 120L else 650L)
    }

    override fun onReadyForSpeech(params: Bundle?) {
        if (active && phase == Phase.IDLE) setPhase(Phase.LISTENING)
    }

    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit

    override fun onError(error: Int) {
        if (!active) return
        restartRecognitionSoon()
    }

    override fun onResults(results: Bundle?) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        if (text.isNotBlank()) acceptTranscript(text, final = true)
        restartRecognitionSoon()
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val text = partialResults
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        if (text.isNotBlank()) acceptTranscript(text, final = false)
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit
}
