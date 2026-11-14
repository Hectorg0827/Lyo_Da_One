package com.lyo.app.ui.screens.chat

import android.os.SystemClock
import kotlin.math.ceil

/**
 * Local, content-free timing for live voice. No transcripts, account data,
 * conversation IDs or remote analytics are recorded. Debug builds may print
 * numerical durations to Logcat for authenticated staging acceptance.
 */
internal data class VoiceLatencyObservation(
    val endOfSpeechToFinalMs: Long?,
    val finalToSubmitMs: Long?,
    val submitToFirstTextMs: Long?,
    val submitToFirstVoicePayloadMs: Long?,
    val submitToFirstAudioMs: Long,
    val endOfSpeechToFirstAudioMs: Long?,
    val p50FirstAudioMs: Long,
    val p95FirstAudioMs: Long,
    val completedAudioTurns: Int,
)

/**
 * Captures a single recognition/response pipeline and keeps a bounded rolling
 * sample for p50/p95. The provided monotonic clock is injectable for JVM tests.
 */
internal class VoiceLatencyMeter(
    private val elapsedRealtimeMs: () -> Long = { SystemClock.elapsedRealtime() },
) {
    private var speechEndedAt: Long? = null
    private var recognizedAt: Long? = null
    private var submittedAt: Long? = null
    private var firstTextAt: Long? = null
    private var firstVoicePayloadAt: Long? = null
    private var firstAudioAt: Long? = null
    private val firstAudioSamples = ArrayDeque<Long>()

    fun speechBegan() {
        speechEndedAt = null
        recognizedAt = null
    }

    fun speechEnded() {
        speechEndedAt = elapsedRealtimeMs()
    }

    fun recognitionFinal() {
        recognizedAt = elapsedRealtimeMs()
    }

    fun submitted() {
        submittedAt = elapsedRealtimeMs()
        firstTextAt = null
        firstVoicePayloadAt = null
        firstAudioAt = null
    }

    fun firstText() {
        if (submittedAt != null && firstTextAt == null) firstTextAt = elapsedRealtimeMs()
    }

    fun firstVoicePayload() {
        if (submittedAt != null && firstVoicePayloadAt == null) firstVoicePayloadAt = elapsedRealtimeMs()
    }

    fun firstAudio(): VoiceLatencyObservation? {
        val submitted = submittedAt ?: return null
        if (firstAudioAt != null) return null
        val audio = elapsedRealtimeMs()
        if (audio < submitted) return null
        firstAudioAt = audio
        val delayMs = audio - submitted
        firstAudioSamples.addLast(delayMs)
        if (firstAudioSamples.size > 20) firstAudioSamples.removeFirst()
        return VoiceLatencyObservation(
            endOfSpeechToFinalMs = diff(recognizedAt, speechEndedAt),
            finalToSubmitMs = diff(submittedAt, recognizedAt),
            submitToFirstTextMs = diff(firstTextAt, submitted),
            submitToFirstVoicePayloadMs = diff(firstVoicePayloadAt, submitted),
            submitToFirstAudioMs = delayMs,
            endOfSpeechToFirstAudioMs = diff(audio, speechEndedAt),
            p50FirstAudioMs = percentile(firstAudioSamples, 0.50),
            p95FirstAudioMs = percentile(firstAudioSamples, 0.95),
            completedAudioTurns = firstAudioSamples.size,
        )
    }

    private fun diff(later: Long?, earlier: Long?): Long? =
        if (later != null && earlier != null && later >= earlier) later - earlier else null

    private fun percentile(values: Collection<Long>, percentile: Double): Long {
        val ordered = values.sorted()
        val index = (ceil(ordered.size * percentile).toInt() - 1).coerceIn(0, ordered.lastIndex)
        return ordered[index]
    }
}

/** First-audio speed is evaluated only after twenty ACTUALLY AUDIBLE turns.
 * This is not a release signoff: missed audio, interruptions and physical
 * device experience require separate independent QA.
 */
internal enum class VoiceSpeedGate { COLLECTING, PASS, FAIL }

internal fun voiceSpeedGate(sample: VoiceLatencyObservation): VoiceSpeedGate = when {
    sample.completedAudioTurns < 20 -> VoiceSpeedGate.COLLECTING
    sample.p50FirstAudioMs <= 1100 && sample.p95FirstAudioMs <= 2000 -> VoiceSpeedGate.PASS
    else -> VoiceSpeedGate.FAIL
}

/**
 * A plain-language readout for test builds, so acceptance on a real phone
 * needs no computer or developer tools. Never shown in the production app.
 * "Pause" is what the learner feels: end of their speech to Lyo's first sound.
 */
internal fun voiceLatencyReadout(sample: VoiceLatencyObservation): String {
    fun seconds(ms: Long) = "%.1f s".format(java.util.Locale.US, ms / 1000.0)
    val pause = sample.endOfSpeechToFirstAudioMs?.let { " · pause ${seconds(it)}" } ?: ""
    val speedStatus = when (voiceSpeedGate(sample)) {
        VoiceSpeedGate.COLLECTING -> ""
        VoiceSpeedGate.PASS -> " · speed-only PASS (human QA still required)"
        VoiceSpeedGate.FAIL -> " · speed-only FAIL (target p50 1.1 s / p95 2.0 s)"
    }
    return "Test build timing · last ${seconds(sample.submitToFirstAudioMs)}$pause" +
        " · p50 ${seconds(sample.p50FirstAudioMs)} · p95 ${seconds(sample.p95FirstAudioMs)}" +
        " · ${sample.completedAudioTurns} of 20 turns" + speedStatus
}
