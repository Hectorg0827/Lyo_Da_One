'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { AudioLines, MicOff, Volume2 } from 'lucide-react';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
import {
  createTranscriptAccumulator,
  normalizeSpeechLang,
  tidyTranscript,
} from '@/lib/speech-transcript.mjs';
import {
  createVoiceQualitySessionId,
  detectLanguageFamily,
  reportVoiceQuality,
  setActiveVoiceQualityContext,
  voiceQualityNow,
} from '@/lib/voice-quality';
import {
  createSpeechRecognition,
  isLikelyPlaybackEcho,
  splitSpeechChunks,
  subscribeVoiceStreamEvents,
  voiceEndOfTurnDelayMs,
  type SpeechRecognitionLike,
  type VoiceStreamEvent,
} from '@/lib/conversational-voice';

type VoicePhase = 'idle' | 'listening' | 'thinking' | 'speaking' | 'error';

type QueuedVoiceSegment = {
  text: string;
  sequence: number;
  messageId: string;
  controller: AbortController;
  audio: Promise<Blob | null>;
};

const BARGE_IN_GRACE_MS = 350;
const BARGE_IN_RMS_THRESHOLD = 0.085;
const BARGE_IN_FRAMES = 5;
/**
 * How long a turn already waiting to be sent is held back once the microphone
 * hears the learner again, before the first word of that new speech arrives.
 * Long enough for a result to land and re-arm the turn with the fuller
 * sentence; short enough that speech which never resolves still gets sent.
 */
const RESUMED_SPEECH_GRACE_MS = 1500;

function latestAssistantMessage() {
  const state = useChatStore.getState();
  const conversation = state.getActiveConversation();
  return [...(conversation?.messages ?? [])].reverse().find((message) =>
    message.role === 'assistant' && Boolean(message.content?.trim())
  );
}

export default function ConversationalVoiceLayer() {
  const active = useChatStore((state) => state.voiceSessionActive);
  const isGenerating = useChatStore((state) => state.isGenerating);
  const setVoiceSessionActive = useChatStore((state) => state.setVoiceSessionActive);
  const sendMessage = useChatStore((state) => state.sendMessage);
  const interruptGeneration = useChatStore((state) => state.interruptGeneration);
  const activeConversationId = useChatStore((state) => state.activeConversationId);

  const [phase, setPhase] = useState<VoicePhase>('idle');
  const [liveTranscript, setLiveTranscript] = useState('');
  const [errorDetail, setErrorDetail] = useState('');
  const [micSilent, setMicSilent] = useState(false);
  // Opening the chat with ?voicedebug=1 shows what the speech engine is
  // actually reporting. "Listening" alone cannot distinguish a microphone
  // that never reaches us from one we are simply not speaking into.
  const [debugEnabled] = useState(() => (
    typeof window !== 'undefined'
    && new URLSearchParams(window.location.search).get('voicedebug') === '1'
  ));
  const [debugLog, setDebugLog] = useState<string[]>([]);

  const phaseRef = useRef<VoicePhase>('idle');
  const activeRef = useRef(false);
  const activeConversationIdRef = useRef<string | null>(activeConversationId);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingTurnTextRef = useRef('');
  const transcriptRef = useRef(createTranscriptAccumulator());
  const lastSpokenTextRef = useRef('');
  const awaitingAssistantRef = useRef(false);
  const lastSpokenMessageIdRef = useRef<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const ttsAbortRef = useRef<AbortController | null>(null);
  const ttsPrefetchAbortRef = useRef<AbortController | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const speakingStartedAtRef = useRef(0);
  const loudFramesRef = useRef(0);
  const voiceSegmentQueueRef = useRef<QueuedVoiceSegment[]>([]);
  const voiceSegmentDrainActiveRef = useRef(false);
  const voiceTurnClosedRef = useRef(false);
  const voiceSegmentsReceivedRef = useRef(false);
  const spokenVoiceSegmentKeysRef = useRef<Set<string>>(new Set());
  const interruptedPreviousTurnRef = useRef(false);
  const heardAnythingRef = useRef(false);
  const debugEnabledRef = useRef(false);
  debugEnabledRef.current = debugEnabled;

  const note = useCallback((entry: string) => {
    if (!debugEnabledRef.current) return;
    const stamp = new Date().toLocaleTimeString([], { hour12: false });
    setDebugLog((log) => [...log.slice(-7), `${stamp} ${entry}`]);
  }, []);

  /**
   * Release the volume monitor's microphone capture.
   *
   * The recognizer competes with any other capture on the page for the
   * microphone — on Android it is the platform speech service that opens the
   * mic, and it cannot while this page already holds it. So the capture is
   * held only while Lyo is speaking, and handed straight back afterwards.
   */
  const releaseMicMonitor = useCallback(() => {
    loudFramesRef.current = 0;
    analyserRef.current = null;
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    mediaStreamRef.current = null;
    const context = audioContextRef.current;
    audioContextRef.current = null;
    void context?.close().catch(() => undefined);
  }, []);

  /**
   * Listen to the microphone's volume for the duration of playback, so a
   * learner talking over Lyo is noticed even before their words resolve.
   *
   * Entirely optional: when the capture is refused, barge-in still happens on
   * the words the recognizer returns.
   */
  const acquireMicMonitor = useCallback(async () => {
    if (mediaStreamRef.current) return;
    if (typeof navigator === 'undefined' || !navigator.mediaDevices?.getUserMedia) return;
    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
    } catch {
      return;
    }
    // Playback may have finished while permission was being granted.
    if (!activeRef.current || phaseRef.current !== 'speaking') {
      stream.getTracks().forEach((track) => track.stop());
      return;
    }
    mediaStreamRef.current = stream;
    const Context = window.AudioContext
      || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Context) return;
    try {
      const context = new Context();
      // Mobile browsers hand back a suspended context outside a tap.
      void context.resume().catch(() => undefined);
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.2;
      source.connect(analyser);
      audioContextRef.current = context;
      analyserRef.current = analyser;
    } catch {
      // Volume barge-in unavailable; the words still interrupt.
    }
  }, []);

  // Live quality instrumentation. These refs never hold transcript/audio in
  // telemetry; only local timestamps and coarse labels leave the device.
  const voiceQualitySessionIdRef = useRef(createVoiceQualitySessionId());
  const sessionStartedAtRef = useRef(0);
  const currentTurnIdRef = useRef<string | null>(null);
  const micSpeechStartedAtRef = useRef(0);
  const lastRecognitionActivityAtRef = useRef(0);
  const turnSubmittedAtRef = useRef(0);
  const firstVoiceSegmentAtRef = useRef(0);
  const firstAudioReportedRef = useRef(false);
  const lastAssistantAudioEndedAtRef = useRef(0);
  const lastLanguageFamilyRef = useRef<'en' | 'es' | 'mixed' | 'unknown'>('unknown');
  const pendingRmsBargeAtRef = useRef(0);
  const pendingRmsBargeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const recognizerRestartCountRef = useRef(0);
  const echoReportedForPlaybackRef = useRef(false);

  const qualityContext = useCallback((turnId?: string) => ({
    sessionId: voiceQualitySessionIdRef.current,
    turnId: turnId ?? currentTurnIdRef.current ?? undefined,
    conversationId: activeConversationIdRef.current ?? undefined,
    locale: typeof navigator !== 'undefined' ? (navigator.language || 'auto') : 'auto',
    scenario: 'live_conversation',
  }), []);

  useEffect(() => {
    activeConversationIdRef.current = activeConversationId;
  }, [activeConversationId]);

  const changePhase = useCallback((next: VoicePhase) => {
    const previous = phaseRef.current;
    phaseRef.current = next;
    setPhase(next);
    if (next === 'speaking') {
      if (previous !== 'speaking') void acquireMicMonitor();
    } else if (previous === 'speaking') {
      releaseMicMonitor();
    }
  }, [acquireMicMonitor, releaseMicMonitor]);

  /**
   * Abandon the turn the learner has stopped speaking but not yet sent.
   *
   * Deliberately separate from stopping the recognizer. A recognizer ends
   * itself after every pause and is replaced moments later, which is the same
   * pause the end-of-turn timer is counting out — so tearing the timer down
   * with the recognizer meant the replacement always arrived first and the
   * turn was never sent. Only finishing, speaking over, or leaving the turn
   * cancels it.
   */
  const cancelPendingTurn = useCallback(() => {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
    pendingTurnTextRef.current = '';
  }, []);

  const stopRecognition = useCallback(() => {
    try { recognitionRef.current?.stop(); } catch { /* already stopped */ }
    recognitionRef.current = null;
  }, []);

  const stopSpeech = useCallback(() => {
    ttsAbortRef.current?.abort();
    ttsPrefetchAbortRef.current?.abort();
    ttsAbortRef.current = null;
    ttsPrefetchAbortRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }
    if (typeof window !== 'undefined') window.speechSynthesis?.cancel();
    voiceSegmentQueueRef.current.forEach((segment) => segment.controller.abort());
    voiceSegmentQueueRef.current = [];
    voiceSegmentDrainActiveRef.current = false;
  }, []);

  const sendVoiceTurn = useCallback(async (raw: string) => {
    const transcript = raw.trim();
    transcriptRef.current.reset();
    setLiveTranscript('');
    if (!transcript || !activeRef.current) return;

    const now = voiceQualityNow();
    const turnId = currentTurnIdRef.current || crypto.randomUUID();
    currentTurnIdRef.current = turnId;
    setActiveVoiceQualityContext(qualityContext(turnId));

    if (isLikelyPlaybackEcho(transcript, lastSpokenTextRef.current)) {
      if (!echoReportedForPlaybackRef.current) {
        echoReportedForPlaybackRef.current = true;
        reportVoiceQuality(qualityContext(turnId), 'echo_rejected', {
          phase: phaseRef.current,
          heard_chars: Math.min(500, transcript.length),
          method: 'semantic_final',
        });
      }
      changePhase('listening');
      return;
    }

    if (pendingRmsBargeTimerRef.current) {
      clearTimeout(pendingRmsBargeTimerRef.current);
      pendingRmsBargeTimerRef.current = null;
    }
    if (pendingRmsBargeAtRef.current > 0) {
      reportVoiceQuality(qualityContext(turnId), 'barge_in_confirmed', {
        confirm_ms: Math.max(0, Math.round(now - pendingRmsBargeAtRef.current)),
        method: 'rms_then_speech',
      });
      pendingRmsBargeAtRef.current = 0;
    }

    stopSpeech();
    cancelPendingTurn();
    stopRecognition();
    const interruptedPreviousTurn = interruptedPreviousTurnRef.current
      || phaseRef.current === 'speaking'
      || useChatStore.getState().isGenerating;
    if (useChatStore.getState().isGenerating) interruptGeneration();

    const languageFamily = detectLanguageFamily(transcript);
    const previousLanguageFamily = lastLanguageFamilyRef.current;
    const languageSwitched = (
      previousLanguageFamily !== 'unknown'
      && languageFamily !== 'unknown'
      && previousLanguageFamily !== languageFamily
    );
    if (languageFamily !== 'unknown') lastLanguageFamilyRef.current = languageFamily;

    turnSubmittedAtRef.current = now;
    firstVoiceSegmentAtRef.current = 0;
    firstAudioReportedRef.current = false;
    const endpointWaitMs = lastRecognitionActivityAtRef.current > 0
      ? Math.max(0, Math.round(now - lastRecognitionActivityAtRef.current))
      : -1;
    const micToSubmitMs = micSpeechStartedAtRef.current > 0
      ? Math.max(0, Math.round(now - micSpeechStartedAtRef.current))
      : -1;

    reportVoiceQuality(qualityContext(turnId), 'turn_submitted', {
      endpoint_wait_ms: endpointWaitMs,
      mic_to_submit_ms: micToSubmitMs,
      interrupted_previous_turn: interruptedPreviousTurn,
      language_family: languageFamily,
      language_switched: languageSwitched,
      rapid_turn: lastAssistantAudioEndedAtRef.current > 0
        ? now - lastAssistantAudioEndedAtRef.current < 1200
        : false,
    });

    // Echo suppression is turn-local. Once a genuine learner utterance is
    // accepted, forget prior assistant speech before collecting the next reply.
    lastSpokenTextRef.current = '';
    lastSpokenMessageIdRef.current = null;
    awaitingAssistantRef.current = true;
    voiceSegmentQueueRef.current = [];
    voiceSegmentDrainActiveRef.current = false;
    voiceTurnClosedRef.current = false;
    voiceSegmentsReceivedRef.current = false;
    spokenVoiceSegmentKeysRef.current.clear();
    note(`sending "${transcript.slice(0, 40)}"`);
    changePhase('thinking');
    interruptedPreviousTurnRef.current = false;
    await sendMessage(transcript, [], {
      voiceSession: true,
      voiceInterruptedPreviousTurn: interruptedPreviousTurn,
      voiceTurnId: turnId,
      voiceLocale: navigator.language || 'auto',
    });
  }, [
    cancelPendingTurn,
    changePhase,
    interruptGeneration,
    note,
    qualityContext,
    sendMessage,
    stopRecognition,
    stopSpeech,
  ]);

  /**
   * Arm the turn the learner has stopped speaking, to be sent once the pause
   * outlasts `delayMs`. Re-arming replaces any turn already waiting.
   */
  const armTurnTimer = useCallback((text: string, delayMs: number) => {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    pendingTurnTextRef.current = text;
    silenceTimerRef.current = setTimeout(() => {
      silenceTimerRef.current = null;
      pendingTurnTextRef.current = '';
      void sendVoiceTurn(text);
    }, delayMs);
  }, [sendVoiceTurn]);

  const startRecognition = useCallback((allowWhileSpeaking = false) => {
    if (!activeRef.current || (phaseRef.current === 'speaking' && !allowWhileSpeaking)) return;
    stopRecognition();
    const recognition = createSpeechRecognition();
    if (!recognition) {
      changePhase('error');
      return;
    }
    recognitionRef.current = recognition;
    recognition.lang = normalizeSpeechLang(navigator.language);
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.maxAlternatives = 3;
    // This recognizer continues the turn the previous one was collecting, so
    // the transcript keeps its words but forgets its result positions.
    transcriptRef.current.carryOver();

    recognition.onstart = () => note(`start lang=${recognition.lang}`);
    recognition.onaudiostart = () => note('audio in');
    recognition.onspeechend = () => note('speech ended');
    // The engine heard words but could not transcribe them. That is not a
    // failure of the session — keep listening rather than going quiet.
    recognition.onnomatch = () => note('no match (heard, not understood)');

    recognition.onspeechstart = () => {
      if (recognitionRef.current !== recognition || !activeRef.current) return;
      note('speech detected');
      // The learner is talking again, so the pause this turn was waiting on is
      // over before it ever expired — sending now would cut their sentence in
      // half. Hold it back rather than drop it: a result re-arms it with the
      // fuller sentence, and speech that never resolves still gets sent.
      if (silenceTimerRef.current && pendingTurnTextRef.current) {
        armTurnTimer(pendingTurnTextRef.current, RESUMED_SPEECH_GRACE_MS);
      }
      const now = voiceQualityNow();
      // Do not rotate a submitted assistant turn merely because the
      // microphone heard something: speaker echo can fire speech-start before
      // semantic recognition rejects it. A new ID is created here only for an
      // idle/listening turn; genuine barge-in rotates after non-echo text is
      // confirmed below.
      if (!currentTurnIdRef.current) {
        currentTurnIdRef.current = crypto.randomUUID();
        turnSubmittedAtRef.current = 0;
        firstVoiceSegmentAtRef.current = 0;
        firstAudioReportedRef.current = false;
        setActiveVoiceQualityContext(qualityContext());
      }
      micSpeechStartedAtRef.current = now;
      lastRecognitionActivityAtRef.current = now;
      const floorGap = lastAssistantAudioEndedAtRef.current > 0
        ? Math.max(0, Math.round(now - lastAssistantAudioEndedAtRef.current))
        : -1;
      reportVoiceQuality(qualityContext(), 'mic_speech_started', {
        floor_gap_ms: floorGap,
        while_speaking: phaseRef.current === 'speaking',
        while_generating: useChatStore.getState().isGenerating,
      });
    };

    recognition.onresult = (event) => {
      // A stopped recognizer may still dispatch queued callbacks after a new
      // shadow recognizer has already taken ownership. Ignore those stale
      // callbacks so two recognition sessions can never contribute to one turn.
      if (recognitionRef.current !== recognition) return;
      const state = transcriptRef.current.push(event);
      const combined = tidyTranscript(state.combined);
      note(`result n=${event.results?.length ?? 0} "${combined.slice(0, 40)}"`);
      if (!combined) return;
      heardAnythingRef.current = true;
      setMicSilent(false);
      lastRecognitionActivityAtRef.current = voiceQualityNow();
      if (!currentTurnIdRef.current) currentTurnIdRef.current = crypto.randomUUID();

      // An RMS-triggered interruption is only considered real once speech
      // recognition produces a non-echo utterance. This separates genuine
      // barge-in from speaker bleed/noise in live-device telemetry.
      if (
        pendingRmsBargeAtRef.current > 0
        && !isLikelyPlaybackEcho(combined, lastSpokenTextRef.current)
      ) {
        if (pendingRmsBargeTimerRef.current) {
          clearTimeout(pendingRmsBargeTimerRef.current);
          pendingRmsBargeTimerRef.current = null;
        }
        reportVoiceQuality(qualityContext(), 'barge_in_confirmed', {
          confirm_ms: Math.max(
            0,
            Math.round(voiceQualityNow() - pendingRmsBargeAtRef.current),
          ),
          method: 'rms_then_recognition',
        });
        pendingRmsBargeAtRef.current = 0;

        // RMS interruption was attributed to the assistant turn. Now that
        // non-echo speech is confirmed, start a fresh canonical learner turn.
        currentTurnIdRef.current = crypto.randomUUID();
        turnSubmittedAtRef.current = 0;
        firstVoiceSegmentAtRef.current = 0;
        firstAudioReportedRef.current = false;
        setActiveVoiceQualityContext(qualityContext());
      }

      // During playback, keep a shadow recognizer armed. Acoustic echo
      // cancellation handles most speaker bleed; semantic echo rejection is
      // the second line of defence. A non-echo utterance owns the floor
      // immediately, so the first word is not lost while a new recognizer is
      // being started after RMS barge-in.
      if (phaseRef.current === 'speaking') {
        // Do not keep a playback echo. Otherwise the next genuine barge-in
        // would be concatenated with Lyo's own words.
        if (isLikelyPlaybackEcho(combined, lastSpokenTextRef.current)) {
          transcriptRef.current.reset();
          if (!echoReportedForPlaybackRef.current) {
            echoReportedForPlaybackRef.current = true;
            reportVoiceQuality(qualityContext(), 'echo_rejected', {
              phase: 'speaking',
              heard_chars: Math.min(500, combined.length),
              method: 'semantic_partial',
            });
          }
          return;
        }
        const detectedAt = voiceQualityNow();
        if (pendingRmsBargeTimerRef.current) {
          clearTimeout(pendingRmsBargeTimerRef.current);
          pendingRmsBargeTimerRef.current = null;
        }
        pendingRmsBargeAtRef.current = 0;
        reportVoiceQuality(qualityContext(), 'barge_in', {
          method: 'semantic',
          speaking_elapsed_ms: speakingStartedAtRef.current > 0
            ? Math.max(0, Math.round(detectedAt - speakingStartedAtRef.current))
            : -1,
          generation_active: useChatStore.getState().isGenerating,
        });
        reportVoiceQuality(qualityContext(), 'assistant_turn_interrupted', {
          method: 'semantic',
        });
        lastAssistantAudioEndedAtRef.current = detectedAt;

        // The interruption belongs to the assistant turn that was cut off;
        // the recognized learner utterance starts a new canonical turn.
        currentTurnIdRef.current = crypto.randomUUID();
        turnSubmittedAtRef.current = 0;
        firstVoiceSegmentAtRef.current = 0;
        firstAudioReportedRef.current = false;
        setActiveVoiceQualityContext(qualityContext());
        interruptedPreviousTurnRef.current = true;
        stopSpeech();
        if (useChatStore.getState().isGenerating) interruptGeneration();
        changePhase('listening');
      }

      setLiveTranscript(combined);
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      const endpointDelayMs = voiceEndOfTurnDelayMs(combined);
      armTurnTimer(combined, endpointDelayMs);
    };
    recognition.onerror = (event) => {
      if (recognitionRef.current !== recognition || !activeRef.current) return;
      note(`error ${event?.error ?? 'unknown'}`);
      // A pause with no words in it is not a failure; onend starts us again.
      if (event?.error === 'no-speech' || event?.error === 'aborted') return;
      setErrorDetail(
        event?.error === 'not-allowed' || event?.error === 'service-not-allowed'
          ? 'Microphone access is blocked for this site. Allow it in your browser settings.'
          : event?.error === 'audio-capture'
            ? 'No microphone was found.'
            : event?.error === 'network'
              ? 'Speech recognition could not reach the network.'
              : 'Voice unavailable.',
      );
      reportVoiceQuality(qualityContext(), 'recognition_error', {
        code: event?.error || 'unknown',
      });
      changePhase('error');
    };
    recognition.onend = () => {
      note('ended');
      // stopRecognition() deliberately clears ownership before starting the
      // shadow recognizer. The old recognizer's delayed onend must not clear or
      // restart the new one.
      if (recognitionRef.current !== recognition) return;
      recognitionRef.current = null;
      if (!activeRef.current) return;
      recognizerRestartCountRef.current += 1;
      reportVoiceQuality(qualityContext(), 'recognizer_restarted', {
        restart_count: recognizerRestartCountRef.current,
        phase: phaseRef.current,
      });
      if (phaseRef.current === 'speaking') {
        window.setTimeout(() => startRecognition(true), 80);
      } else if (phaseRef.current === 'listening') {
        window.setTimeout(() => startRecognition(false), 120);
      }
    };
    try {
      recognition.start();
      if (!allowWhileSpeaking) changePhase('listening');
    } catch {
      changePhase('error');
    }
  }, [
    armTurnTimer,
    changePhase,
    interruptGeneration,
    note,
    qualityContext,
    sendVoiceTurn,
    stopRecognition,
    stopSpeech,
  ]);

  const markFirstAudio = useCallback((transport: 'server_tts' | 'device_tts') => {
    if (firstAudioReportedRef.current || !currentTurnIdRef.current) return;
    firstAudioReportedRef.current = true;
    const now = voiceQualityNow();
    reportVoiceQuality(qualityContext(), 'first_audio', {
      mic_to_audio_ms: micSpeechStartedAtRef.current > 0
        ? Math.max(0, Math.round(now - micSpeechStartedAtRef.current))
        : -1,
      submit_to_audio_ms: turnSubmittedAtRef.current > 0
        ? Math.max(0, Math.round(now - turnSubmittedAtRef.current))
        : -1,
      segment_to_audio_ms: firstVoiceSegmentAtRef.current > 0
        ? Math.max(0, Math.round(now - firstVoiceSegmentAtRef.current))
        : -1,
      transport,
    });
  }, [qualityContext]);

  const playBlob = useCallback((blob: Blob) => new Promise<void>((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    let settled = false;
    const cleanup = () => {
      URL.revokeObjectURL(url);
      if (audioRef.current === audio) audioRef.current = null;
    };
    audioRef.current = audio;
    audio.onplaying = () => markFirstAudio('server_tts');
    audio.onended = () => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve();
    };
    audio.onerror = () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error('Audio playback failed'));
    };
    void audio.play().catch((error) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(error);
    });
  }), [markFirstAudio]);

  const browserSpeechFallback = useCallback((text: string) => new Promise<void>((resolve) => {
    if (typeof window === 'undefined' || !window.speechSynthesis) { resolve(); return; }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = navigator.language || 'en-US';
    utterance.rate = 1.02;
    utterance.onstart = () => markFirstAudio('device_tts');
    utterance.onend = () => resolve();
    utterance.onerror = () => resolve();
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(utterance);
  }), [markFirstAudio]);

  const closeVoiceTurn = useCallback((outcome: 'completed' | 'incomplete' | 'fallback') => {
    const now = voiceQualityNow();
    if (currentTurnIdRef.current) {
      reportVoiceQuality(qualityContext(), 'assistant_turn_complete', {
        outcome,
        audio_started: firstAudioReportedRef.current,
        submit_to_complete_ms: turnSubmittedAtRef.current > 0
          ? Math.max(0, Math.round(now - turnSubmittedAtRef.current))
          : -1,
      });
    }
    lastAssistantAudioEndedAtRef.current = now;
    currentTurnIdRef.current = null;
    setActiveVoiceQualityContext(qualityContext(undefined));
    micSpeechStartedAtRef.current = 0;
    lastRecognitionActivityAtRef.current = 0;
    turnSubmittedAtRef.current = 0;
    firstVoiceSegmentAtRef.current = 0;
    firstAudioReportedRef.current = false;
  }, [qualityContext]);

  const finishSegmentTurnIfReady = useCallback(() => {
    if (
      !activeRef.current
      || !voiceTurnClosedRef.current
      || voiceSegmentDrainActiveRef.current
      || voiceSegmentQueueRef.current.length > 0
    ) return;
    awaitingAssistantRef.current = false;
    closeVoiceTurn(voiceSegmentsReceivedRef.current ? 'completed' : 'incomplete');
    changePhase('listening');
    startRecognition();
  }, [changePhase, closeVoiceTurn, startRecognition]);

  const drainVoiceSegments = useCallback(async () => {
    if (voiceSegmentDrainActiveRef.current || !activeRef.current) return;
    voiceSegmentDrainActiveRef.current = true;
    echoReportedForPlaybackRef.current = false;
    echoReportedForPlaybackRef.current = false;
    cancelPendingTurn();
    stopRecognition();
    changePhase('speaking');
    speakingStartedAtRef.current = performance.now();
    startRecognition(true);

    try {
      while (activeRef.current && voiceSegmentQueueRef.current.length > 0) {
        const segment = voiceSegmentQueueRef.current.shift();
        if (!segment) break;
        const spoken = segment.text.trim();
        if (!spoken) continue;

        lastSpokenTextRef.current = (lastSpokenTextRef.current + ' ' + spoken).trim();
        lastSpokenMessageIdRef.current = segment.messageId;

        try {
          ttsAbortRef.current = segment.controller;
          const blob = await segment.audio;
          if (!blob) throw new Error('Segment synthesis failed');
          await playBlob(blob);
        } catch {
          if (!activeRef.current || phaseRef.current !== 'speaking') break;
          await browserSpeechFallback(spoken);
        } finally {
          ttsAbortRef.current = null;
        }
      }
    } finally {
      voiceSegmentDrainActiveRef.current = false;
      finishSegmentTurnIfReady();
    }
  }, [
    browserSpeechFallback,
    cancelPendingTurn,
    changePhase,
    finishSegmentTurnIfReady,
    playBlob,
    stopRecognition,
  ]);

  const handleVoiceStreamEvent = useCallback((event: VoiceStreamEvent) => {
    if (!activeRef.current) return;

    if (event.type === 'voice_text_segment') {
      voiceSegmentsReceivedRef.current = true;
      awaitingAssistantRef.current = true;
      if (!firstVoiceSegmentAtRef.current) {
        const now = voiceQualityNow();
        firstVoiceSegmentAtRef.current = now;
        reportVoiceQuality(qualityContext(), 'first_voice_segment', {
          submit_to_segment_ms: turnSubmittedAtRef.current > 0
            ? Math.max(0, Math.round(now - turnSubmittedAtRef.current))
            : -1,
          mic_to_segment_ms: micSpeechStartedAtRef.current > 0
            ? Math.max(0, Math.round(now - micSpeechStartedAtRef.current))
            : -1,
          sequence: event.sequence,
        });
      }
      const segmentKey = event.messageId + ':' + event.sequence;
      if (spokenVoiceSegmentKeysRef.current.has(segmentKey)) return;
      if (
        voiceSegmentQueueRef.current.some(
          (item) => item.messageId === event.messageId && item.sequence === event.sequence,
        )
      ) return;
      spokenVoiceSegmentKeysRef.current.add(segmentKey);
      const controller = new AbortController();
      const audio = api.tts.synthesizeStream(event.text, {
        language: navigator.language || 'auto',
        speed: 1.02,
        signal: controller.signal,
      }).catch(() => null);
      voiceSegmentQueueRef.current.push({
        text: event.text,
        sequence: event.sequence,
        messageId: event.messageId,
        controller,
        audio,
      });
      voiceSegmentQueueRef.current.sort((a, b) => a.sequence - b.sequence);
      void drainVoiceSegments();
      return;
    }

    if (event.type === 'voice_ready') {
      voiceTurnClosedRef.current = true;
      if (
        !voiceSegmentsReceivedRef.current
        && event.speak
        && event.text.trim()
      ) {
        voiceSegmentsReceivedRef.current = true;
        const fallbackKey = event.messageId + ':ready';
        if (!spokenVoiceSegmentKeysRef.current.has(fallbackKey)) {
          spokenVoiceSegmentKeysRef.current.add(fallbackKey);
          const controller = new AbortController();
          const audio = api.tts.synthesizeStream(event.text, {
            language: navigator.language || 'auto',
            speed: 1.02,
            signal: controller.signal,
          }).catch(() => null);
          voiceSegmentQueueRef.current.push({
            text: event.text,
            sequence: Number.MAX_SAFE_INTEGER,
            messageId: event.messageId,
            controller,
            audio,
          });
          void drainVoiceSegments();
          return;
        }
      }
      finishSegmentTurnIfReady();
      return;
    }

    if (event.type === 'voice_incomplete') {
      voiceTurnClosedRef.current = true;
      finishSegmentTurnIfReady();
    }
  }, [drainVoiceSegments, finishSegmentTurnIfReady, qualityContext]);

  useEffect(() => subscribeVoiceStreamEvents(handleVoiceStreamEvent), [handleVoiceStreamEvent]);
  const speakAssistant = useCallback(async (messageId: string, text: string) => {
    const chunks = splitSpeechChunks(text);
    if (!chunks.length || !activeRef.current) return;
    cancelPendingTurn();
    stopRecognition();
    changePhase('speaking');
    speakingStartedAtRef.current = performance.now();
    startRecognition(true);
    lastSpokenTextRef.current = text;
    lastSpokenMessageIdRef.current = messageId;

    try {
      let next: { promise: Promise<Blob>; controller: AbortController } | null = null;
      for (let index = 0; index < chunks.length && activeRef.current; index++) {
        const current = next ?? (() => {
          const controller = new AbortController();
          return {
            controller,
            promise: api.tts.synthesizeStream(chunks[index], {
              language: navigator.language || 'auto',
              speed: 1.02,
              signal: controller.signal,
            }),
          };
        })();
        ttsAbortRef.current = current.controller;
        ttsPrefetchAbortRef.current = null;

        if (index + 1 < chunks.length) {
          const controller = new AbortController();
          next = {
            controller,
            promise: api.tts.synthesizeStream(chunks[index + 1], {
              language: navigator.language || 'auto',
              speed: 1.02,
              signal: controller.signal,
            }),
          };
          ttsPrefetchAbortRef.current = controller;
        } else {
          next = null;
        }

        await playBlob(await current.promise);
      }
    } catch {
      if (activeRef.current && phaseRef.current === 'speaking') {
        await browserSpeechFallback(splitSpeechChunks(text, 800).join(' '));
      }
    } finally {
      ttsAbortRef.current = null;
      ttsPrefetchAbortRef.current = null;
      if (activeRef.current && phaseRef.current === 'speaking') {
        closeVoiceTurn('fallback');
        changePhase('listening');
        startRecognition();
      }
    }
  }, [
    browserSpeechFallback,
    cancelPendingTurn,
    changePhase,
    closeVoiceTurn,
    playBlob,
    startRecognition,
    stopRecognition,
  ]);

  const bargeIn = useCallback(() => {
    if (!activeRef.current || phaseRef.current !== 'speaking') return;
    const detectedAt = voiceQualityNow();
    reportVoiceQuality(qualityContext(), 'barge_in', {
      method: 'rms',
      speaking_elapsed_ms: speakingStartedAtRef.current > 0
        ? Math.max(0, Math.round(detectedAt - speakingStartedAtRef.current))
        : -1,
      generation_active: useChatStore.getState().isGenerating,
    });
    reportVoiceQuality(qualityContext(), 'assistant_turn_interrupted', {
      method: 'rms',
    });
    lastAssistantAudioEndedAtRef.current = detectedAt;
    pendingRmsBargeAtRef.current = detectedAt;
    if (pendingRmsBargeTimerRef.current) clearTimeout(pendingRmsBargeTimerRef.current);
    pendingRmsBargeTimerRef.current = setTimeout(() => {
      if (!pendingRmsBargeAtRef.current) return;
      reportVoiceQuality(qualityContext(), 'false_barge_in', {
        method: 'rms_without_non_echo_speech',
        confirm_window_ms: 1800,
      });
      pendingRmsBargeAtRef.current = 0;
      pendingRmsBargeTimerRef.current = null;
    }, 1800);

    interruptedPreviousTurnRef.current = true;
    stopSpeech();
    if (useChatStore.getState().isGenerating) interruptGeneration();
    loudFramesRef.current = 0;
    transcriptRef.current.reset();
    setLiveTranscript('');
    changePhase('listening');
    startRecognition();
  }, [changePhase, interruptGeneration, qualityContext, startRecognition, stopSpeech]);

  useEffect(() => {
    if (active) {
      voiceQualitySessionIdRef.current = createVoiceQualitySessionId();
      sessionStartedAtRef.current = voiceQualityNow();
      recognizerRestartCountRef.current = 0;
      lastLanguageFamilyRef.current = 'unknown';
      setActiveVoiceQualityContext(qualityContext());
      reportVoiceQuality(qualityContext(), 'session_started', {
        user_agent_mobile: typeof navigator !== 'undefined'
          ? /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent)
          : false,
      });
      return;
    }

    if (sessionStartedAtRef.current > 0) {
      const now = voiceQualityNow();
      reportVoiceQuality(qualityContext(), 'session_ended', {
        duration_ms: Math.max(0, Math.round(now - sessionStartedAtRef.current)),
        recognizer_restarts: recognizerRestartCountRef.current,
      });
    }
    sessionStartedAtRef.current = 0;
    setActiveVoiceQualityContext(null);
  // Session identity changes only when Live Conversation is toggled. The
  // conversation ID may be promoted local -> server mid-session and must not
  // split quality telemetry into a second session.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  useEffect(() => {
    if (active) setActiveVoiceQualityContext(qualityContext());
  }, [active, activeConversationId, qualityContext]);

  useEffect(() => {
    if (!active) return;
    activeRef.current = true;
    heardAnythingRef.current = false;
    setMicSilent(false);
    setErrorDetail('');
    if (!createSpeechRecognition()) {
      setErrorDetail('This browser cannot listen. Try Chrome, Edge or Safari.');
      changePhase('error');
      return;
    }
    // Start listening straight away. The recognizer asks for the microphone
    // itself, so nothing else may hold it open first.
    startRecognition();
  }, [active, changePhase, startRecognition]);

  useEffect(() => {
    activeRef.current = active;
    if (active) return;
    awaitingAssistantRef.current = false;
    cancelPendingTurn();
    stopRecognition();
    stopSpeech();
    releaseMicMonitor();
    if (animationFrameRef.current != null) cancelAnimationFrame(animationFrameRef.current);
    animationFrameRef.current = null;
    if (pendingRmsBargeTimerRef.current) {
      clearTimeout(pendingRmsBargeTimerRef.current);
      pendingRmsBargeTimerRef.current = null;
    }
    pendingRmsBargeAtRef.current = 0;
    changePhase('idle');
    setLiveTranscript('');
    setMicSilent(false);
    setErrorDetail('');
  }, [active, cancelPendingTurn, changePhase, releaseMicMonitor, stopRecognition, stopSpeech]);

  useEffect(() => {
    if (!active) return;
    const tick = () => {
      const analyser = analyserRef.current;
      if (analyser && phaseRef.current === 'speaking' && performance.now() - speakingStartedAtRef.current > BARGE_IN_GRACE_MS) {
        const samples = new Uint8Array(analyser.fftSize);
        analyser.getByteTimeDomainData(samples);
        let sum = 0;
        for (let i = 0; i < samples.length; i++) {
          const normalized = (samples[i] - 128) / 128;
          sum += normalized * normalized;
        }
        const rms = Math.sqrt(sum / samples.length);
        loudFramesRef.current = rms > BARGE_IN_RMS_THRESHOLD ? loudFramesRef.current + 1 : 0;
        if (loudFramesRef.current >= BARGE_IN_FRAMES) bargeIn();
      } else loudFramesRef.current = 0;
      animationFrameRef.current = requestAnimationFrame(tick);
    };
    animationFrameRef.current = requestAnimationFrame(tick);
    return () => {
      if (animationFrameRef.current != null) cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    };
  }, [active, bargeIn]);

  useEffect(() => {
    if (!active || isGenerating || !awaitingAssistantRef.current) return;
    const latest = latestAssistantMessage();
    if (!latest || !latest.content.trim()) return;
    if (voiceSegmentsReceivedRef.current) {
      voiceTurnClosedRef.current = true;
      finishSegmentTurnIfReady();
      return;
    }
    if (latest.id === lastSpokenMessageIdRef.current) return;
    awaitingAssistantRef.current = false;
    void speakAssistant(latest.id, latest.content);
  }, [active, activeConversationId, finishSegmentTurnIfReady, isGenerating, speakAssistant]);

  // Listening is otherwise indistinguishable from a microphone that is not
  // reaching us at all. Say so rather than sitting on "Listening…" forever.
  useEffect(() => {
    if (!active || phase !== 'listening' || heardAnythingRef.current) return;
    const timer = window.setTimeout(() => {
      if (activeRef.current && !heardAnythingRef.current) setMicSilent(true);
    }, 12000);
    return () => window.clearTimeout(timer);
  }, [active, phase]);

  const endSession = () => setVoiceSessionActive(false);

  if (!active) return null;

  const label = phase === 'listening'
    ? (liveTranscript
        || (micSilent
          ? 'Not hearing anything yet — check this site’s microphone permission.'
          : 'Listening…'))
    : phase === 'thinking'
      ? 'Lyo is thinking…'
      : phase === 'speaking'
        ? 'Lyo is speaking — start talking to interrupt'
        : phase === 'error'
          ? (errorDetail || 'Voice unavailable')
          : 'Voice ready';

  return (
    <div className="max-w-3xl mx-auto mb-2 rounded-2xl border border-lyo-500/25 bg-lyo-500/10 px-3 py-2.5">
      <div className="flex items-center gap-3">
        <div className={cn(
          'w-9 h-9 rounded-full flex items-center justify-center shrink-0',
          phase === 'speaking' ? 'bg-lyo-500/20 text-lyo-200' : 'bg-white/10 text-white/80'
        )}>
          {phase === 'speaking' ? <Volume2 className="w-4 h-4" /> : phase === 'error' ? <MicOff className="w-4 h-4" /> : <AudioLines className="w-4 h-4" />}
        </div>
        <div className="min-w-0 flex-1">
          <div className="text-xs font-semibold text-white/85">Live conversation</div>
          <div className={cn('text-xs text-white/55', !debugEnabled && 'truncate')}>{label}</div>
        </div>
        <button
          type="button"
          onClick={endSession}
          className="px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/15 text-xs text-white/75 shrink-0"
        >
          End
        </button>
      </div>
      {debugEnabled && (
        <pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap rounded-xl bg-black/50 px-2.5 py-2 font-mono text-[10px] leading-snug text-white/60">
          {debugLog.length ? debugLog.join('\n') : 'waiting for the speech engine…'}
        </pre>
      )}
    </div>
  );
}
