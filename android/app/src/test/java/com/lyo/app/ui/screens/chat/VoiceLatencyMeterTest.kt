package com.lyo.app.ui.screens.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VoiceLatencyMeterTest {
    @Test
    fun measuresSpeechRecognitionNetworkAndFirstAudibleResponseSeparately() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        meter.speechBegan()
        now = 200
        meter.speechEnded()
        now = 350
        meter.recognitionFinal()
        now = 375
        meter.submitted()
        now = 450
        meter.firstText()
        now = 520
        meter.firstVoicePayload()
        now = 600
        val sample = requireNotNull(meter.firstAudio())
        assertEquals(150L, sample.endOfSpeechToFinalMs)
        assertEquals(25L, sample.finalToSubmitMs)
        assertEquals(75L, sample.submitToFirstTextMs)
        assertEquals(145L, sample.submitToFirstVoicePayloadMs)
        assertEquals(225L, sample.submitToFirstAudioMs)
        assertEquals(400L, sample.endOfSpeechToFirstAudioMs)
        assertEquals(225L, sample.p50FirstAudioMs)
        assertEquals(225L, sample.p95FirstAudioMs)
        assertEquals(1, sample.completedAudioTurns)
        assertNull(meter.firstAudio()) // duplicate TTS callbacks must not inflate latency statistics
    }

    @Test
    fun firstAudibleOutputWithoutAsrOrTextStillHasValidStageTiming() {
        var now = 1000L
        val meter = VoiceLatencyMeter { now }
        meter.submitted()
        now = 1500
        val sample = requireNotNull(meter.firstAudio())
        assertNull(sample.endOfSpeechToFinalMs)
        assertNull(sample.finalToSubmitMs)
        assertNull(sample.submitToFirstTextMs)
        assertNull(sample.submitToFirstVoicePayloadMs)
        assertNull(sample.endOfSpeechToFirstAudioMs)
        assertEquals(500L, sample.submitToFirstAudioMs)
    }

    @Test
    fun rollingP50AndP95BoundToLatestTwentyTurns() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        var latest: VoiceLatencyObservation? = null
        for (index in 1..21) {
            now += 10
            meter.submitted()
            now += index * 100L
            latest = meter.firstAudio()
        }
        requireNotNull(latest)
        assertEquals(20, latest.completedAudioTurns)
        // Last twenty samples are 200,300,...,2100; nearest-rank p50=1100 p95=2000.
        assertEquals(1100L, latest.p50FirstAudioMs)
        assertEquals(2000L, latest.p95FirstAudioMs)
    }

    @Test
    fun missingSpeechOutputNeverCreatesFalseLatencySample() {
        val meter = VoiceLatencyMeter { 10L }
        assertNull(meter.firstAudio())
        meter.submitted()
        // The screen will record a missing-TTS case separately in QA;
        // no sample is counted until speech genuinely starts.
    }

    @Test
    fun readoutShowsTheNumbersAcceptanceNeedsInPlainSeconds() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        meter.speechBegan()
        meter.speechEnded()
        now = 300
        meter.recognitionFinal()
        meter.submitted()
        now = 1500
        val sample = requireNotNull(meter.firstAudio())
        assertEquals(
            "Test build timing · last 1.2 s · pause 1.5 s · p50 1.2 s · p95 1.2 s · 1 of 20 turns",
            voiceLatencyReadout(sample),
        )
    }
    @Test
    fun speedGateNeverClaimsPassBeforeTwentyAudibleSamples() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        var sample: VoiceLatencyObservation? = null
        for (i in 1..19) {
            now += 10
            meter.submitted()
            now += 500
            sample = meter.firstAudio()
        }
        assertEquals(VoiceSpeedGate.COLLECTING, voiceSpeedGate(requireNotNull(sample)))
    }

    @Test
    fun speedGatePassesOnlyMeasuredTwentyTurnP50AndP95() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        var sample: VoiceLatencyObservation? = null
        repeat(20) {
            now += 10
            meter.submitted()
            now += 1000
            sample = meter.firstAudio()
        }
        assertEquals(VoiceSpeedGate.PASS, voiceSpeedGate(requireNotNull(sample)))
        assertEquals(20, sample?.completedAudioTurns)
        org.junit.Assert.assertTrue(voiceLatencyReadout(requireNotNull(sample)).contains("speed-only PASS"))
        org.junit.Assert.assertTrue(voiceLatencyReadout(requireNotNull(sample)).contains("human QA still required"))
    }

    @Test
    fun slowTailFailsEvenIfMedianIsFast() {
        var now = 0L
        val meter = VoiceLatencyMeter { now }
        var sample: VoiceLatencyObservation? = null
        repeat(20) { i ->
            now += 10
            meter.submitted()
            now += if (i == 19) 2500 else 900
            sample = meter.firstAudio()
        }
        assertEquals(900L, sample?.p50FirstAudioMs)
        assertEquals(2500L, sample?.p95FirstAudioMs)
        assertEquals(VoiceSpeedGate.FAIL, voiceSpeedGate(requireNotNull(sample)))
        org.junit.Assert.assertTrue(voiceLatencyReadout(requireNotNull(sample)).contains("speed-only FAIL"))
    }

}
