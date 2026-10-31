'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { AudioLines, MessageSquareText, Mic, MicOff, Volume2, X } from 'lucide-react';
import MascotAvatar from './MascotAvatar';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
import {
  createTranscriptAccumulator,
  normalizeSpeechLang,
  tidyTranscript,
} from '@/lib/speech-transcript.mjs';
import { joinSpoken, spokenPrefix } from '@/lib/voice-reveal.mjs';
import { playVoiceBlob, speakVoiceFallback, unspokenRemainder, pauseAfterSpeechMs, waitForSpeechPause } from '@/lib/voice-playback.mjs';
import { prefersTapInterruption, shouldEndTurnOnSpeech } from '@/lib/voice-barge-in.mjs';
import type { MicMonitorState } from '@/lib/voice-barge-in.mjs';
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
 * How far above Lyo's own voice the microphone must rise to count as someone
 * talking over it.
 *
 * Playback bleeds back into the microphone from the speaker, and echo
 * cancellation does not remove all of it on a phone held in the hand. A fixed
 * threshold therefore hears Lyo as a learner interrupting, and Lyo cuts itself
 * off seconds after it starts. The floor below tracks that bleed while Lyo
 * speaks, so what counts as an interruption is "louder than Lyo currently is",
 * not "louder than a constant".
 */
const BARGE_IN_EXCESS = 2.2;
/** Volume playback drops to while a suspected interruption is unconfirmed. */
const DUCKED_VOLUME = 0.22;
/**
 * How long a turn already waiting to be sent is held back once the microphone
 * hears the learner again, before the first word of that new speech arrives.
 * Long enough for a result to land and re-arm the turn with the fuller
 * sentence; short enough that speech which never resolves still gets sent.
 */
const RESUMED_SPEECH_GRACE_MS = 1500;

export default function ConversationalVoiceLayer() {
  const active = useChatStore((state) => state.voiceSessionActive);
  const isGenerating = useChatStore((state) => state.isGenerating);
  const setVoiceSessionActive = useChatStore((state) => state.setVoiceSessionActive);
  const sendMessage = useChatStore((state) => state.sendMessage);
  const interruptGeneration = useChatStore((state) => state.interruptGeneration);
  const activeConversationId = useChatStore((state) => state.activeConversationId);

  const [interruptionMode, setInterruptionMode] = useState<'tap' | 'speech'>('tap');
  const tapOnlyRef = useRef(typeof navigator !== 'undefined' && prefersTapInterruption(navigator.userAgent));
  const responseAbortRef = useRef(new AbortController());
  const acceptedTurnIdRef = useRef<string | null>(null);
  const responseMessageIdRef = useRef<string | null>(null);
  const monitorGenerationRef = useRef(0);
  const monitorTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const recognitionRestartRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [phase, setPhase] = useState<VoicePhase>('idle');
  const [liveTranscript, setLiveTranscript] = useState('');
  const [showTranscript, setShowTranscript] = useState(false);
  const [preferredSpeechLanguage, setPreferredSpeechLanguage] = useState<'device' | 'en-US' | 'es-ES'>('device');
  const preferredSpeechLanguageRef = useRef<'device' | 'en-US' | 'es-ES'>('device');
  const speechLocale = useCallback(() => preferredSpeechLanguageRef.current === 'device'
    ? (typeof navigator !== 'undefined' ? navigator.language || 'en-US' : 'en-US')
    : preferredSpeechLanguageRef.current, []);
  const [thinkingNudge, setThinkingNudge] = useState('');
  const conversation = useChatStore((state) => state.conversations.find((item) => item.id === state.activeConversationId));
  const spokenText = useChatStore((state) => state.voiceSpokenText);
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
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const speakingStartedAtRef = useRef(0);
  const loudFramesRef = useRef(0);
  const bleedFloorRef = useRef(0);
  const spokenSoFarRef = useRef('');
  const duckedRef = useRef(false);
  // What the volume monitor can contribute to judging an interruption. It is
  // granted the microphone asynchronously, so 'pending' covers the opening of
  // playback — exactly when Lyo is most likely to hear itself.
  const micMonitorStateRef = useRef<MicMonitorState>('pending');
  const voiceSegmentQueueRef = useRef<QueuedVoiceSegment[]>([]);
  const voiceSegmentDrainActiveRef = useRef(false);
  const voiceTurnClosedRef = useRef(false);
  const voiceTurnOutcomeRef = useRef<'completed' | 'incomplete' | 'fallback'>('completed');
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
    monitorGenerationRef.current += 1;
    if (monitorTimeoutRef.current) clearTimeout(monitorTimeoutRef.current);
    monitorTimeoutRef.current = null;
    micMonitorStateRef.current = 'pending';
    setInterruptionMode('tap');
    loudFramesRef.current = 0;
    analyserRef.current = null;
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    mediaStreamRef.current = null;
    const context = audioContextRef.current;
    audioContextRef.current = null;
    void context?.close().catch(() => undefined);
  }, []);

  // Android uses one microphone owner at a time. Other browsers may use
  // monitored spoken interruption, but pending/failed capture is always tap-only.
  const acquireMicMonitor = useCallback(async () => {
    if (tapOnlyRef.current || mediaStreamRef.current) return;
    const generation = ++monitorGenerationRef.current;
    const current = () => generation === monitorGenerationRef.current
      && activeRef.current && phaseRef.current === 'speaking';
    micMonitorStateRef.current = 'pending';
    setInterruptionMode('tap');
    let stream: MediaStream | null = null;
    let context: AudioContext | null = null;
    // A permission prompt or suspended context must not hold the mic forever.
    const timeout = setTimeout(() => {
      if (!current()) return;
      releaseMicMonitor();
      micMonitorStateRef.current = 'unavailable';
      stream?.getTracks().forEach((track) => track.stop());
      void context?.close().catch(() => undefined);
    }, 2500);
    monitorTimeoutRef.current = timeout;
    try {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error('No capture');
      stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
      if (!current()) return;
      mediaStreamRef.current = stream;
      const Context = window.AudioContext
        || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Context) throw new Error('No audio context');
      context = new Context();
      audioContextRef.current = context;
      if (context.state === 'suspended') await context.resume();
      if (!current()) return;
      if (context.state !== 'running') throw new Error('Suspended audio context');
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.2;
      source.connect(analyser);
      mediaStreamRef.current = stream;
      audioContextRef.current = context;
      analyserRef.current = analyser;
      micMonitorStateRef.current = 'ready';
      setInterruptionMode('speech');
      context.onstatechange = () => {
        if (current() && context?.state !== 'running') {
          releaseMicMonitor();
          micMonitorStateRef.current = 'unavailable';
        }
      };
    } catch {
      if (current()) {
        releaseMicMonitor();
        micMonitorStateRef.current = 'unavailable';
      }
    } finally {
      clearTimeout(timeout);
      if (monitorTimeoutRef.current === timeout) monitorTimeoutRef.current = null;
      if (mediaStreamRef.current !== stream) stream?.getTracks().forEach((track) => track.stop());
      if (audioContextRef.current !== context) void context?.close().catch(() => undefined);
    }
  }, [releaseMicMonitor]);

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
    if (recognitionRestartRef.current) clearTimeout(recognitionRestartRef.current);
    recognitionRestartRef.current = null;
    const recognition = recognitionRef.current;
    recognitionRef.current = null;
    try { (recognition?.abort ?? recognition?.stop)?.call(recognition); } catch { /* already stopped */ }
  }, []);

  /**
   * Quieten playback without abandoning it, while a suspected interruption is
   * still unconfirmed. Quieter playback also bleeds less into the microphone,
   * which gives the recognizer a better chance of resolving what was said.
   */
  const duckPlayback = useCallback(() => {
    duckedRef.current = true;
    if (audioRef.current) audioRef.current.volume = DUCKED_VOLUME;
  }, []);

  const restorePlayback = useCallback(() => {
    duckedRef.current = false;
    if (audioRef.current) audioRef.current.volume = 1;
  }, []);

  const stopSpeech = useCallback(() => {
    responseAbortRef.current.abort();
    acceptedTurnIdRef.current = null;
    responseMessageIdRef.current = null;
    awaitingAssistantRef.current = false;
    if (pendingRmsBargeTimerRef.current) clearTimeout(pendingRmsBargeTimerRef.current);
    pendingRmsBargeTimerRef.current = null;
    pendingRmsBargeAtRef.current = 0;
    ttsAbortRef.current?.abort();
    ttsAbortRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }
    if (typeof window !== 'undefined') window.speechSynthesis?.cancel();
    voiceSegmentQueueRef.current.forEach((segment) => segment.controller.abort());
    voiceSegmentQueueRef.current = [];
    voiceSegmentDrainActiveRef.current = false;
    duckedRef.current = false;
  }, []);

  const sendVoiceTurn = useCallback(async (raw: string) => {
    const transcript = raw.trim();
    transcriptRef.current.reset();
    setLiveTranscript('');
    if (!transcript || !activeRef.current || phaseRef.current !== 'listening') return;

    const now = voiceQualityNow();
    const turnId = currentTurnIdRef.current || crypto.randomUUID();
    currentTurnIdRef.current = turnId;
    setActiveVoiceQualityContext(qualityContext(turnId));

    stopSpeech();
    cancelPendingTurn();
    stopRecognition();
    const interruptedPreviousTurn = interruptedPreviousTurnRef.current
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
    responseAbortRef.current = new AbortController();
    acceptedTurnIdRef.current = turnId;
    responseMessageIdRef.current = null;
    awaitingAssistantRef.current = true;
    voiceSegmentQueueRef.current = [];
    voiceSegmentDrainActiveRef.current = false;
    voiceTurnClosedRef.current = false;
    voiceTurnOutcomeRef.current = 'completed';
    voiceSegmentsReceivedRef.current = false;
    spokenVoiceSegmentKeysRef.current.clear();
    releaseSpoken();
    note(`sending "${transcript.slice(0, 40)}"`);
    changePhase('thinking');
    interruptedPreviousTurnRef.current = false;
    await sendMessage(transcript, [], {
      voiceSession: true,
      voiceInterruptedPreviousTurn: interruptedPreviousTurn,
      voiceTurnId: turnId,
      voiceLocale: speechLocale(),
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
    if (!activeRef.current) return;
    if (phaseRef.current === 'speaking' && (!allowWhileSpeaking || tapOnlyRef.current
      || micMonitorStateRef.current !== 'ready')) return;
    stopRecognition();
    const recognition = createSpeechRecognition();
    if (!recognition) {
      changePhase('error');
      return;
    }
    recognitionRef.current = recognition;
    recognition.lang = normalizeSpeechLang(speechLocale());
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
      if (recognitionRef.current !== recognition || !activeRef.current) return;
      const state = transcriptRef.current.push(event);
      const combined = tidyTranscript(state.combined);
      note(`result n=${event.results?.length ?? 0} "${combined.slice(0, 40)}"`);
      if (!combined) return;
      heardAnythingRef.current = true;
      setMicSilent(false);
      lastRecognitionActivityAtRef.current = voiceQualityNow();
      if (!currentTurnIdRef.current) currentTurnIdRef.current = crypto.randomUUID();

      const roseAboveLyo = pendingRmsBargeAtRef.current > 0;

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

        // Words that match nothing Lyo said are not proof of a learner: the
        // microphone hears Lyo through the speaker, and that bleed is
        // distorted enough that the engine regularly returns words from no
        // part of the answer. Ending the turn on those is Lyo interrupting
        // itself. A real interruption is also louder than Lyo currently is,
        // which is what the volume monitor arms — so both are required,
        // with a ready monitor corroborating the speech.
        if (!shouldEndTurnOnSpeech({
          isEcho: false,
          loudEnough: roseAboveLyo,
          monitorState: micMonitorStateRef.current,
        })) {
          note(`held: "${combined.slice(0, 24)}" not louder than Lyo`);
          transcriptRef.current.reset();
          return;
        }

        const detectedAt = voiceQualityNow();
        reportVoiceQuality(qualityContext(), 'barge_in_confirmed', {
          method: 'rms_then_recognition',
          confirm_ms: Math.round(detectedAt - pendingRmsBargeAtRef.current),
        });
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
          cancellation_reason: 'spoken_interruption',
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
        useChatStore.getState().setVoiceSpokenText(null);
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
      if (phaseRef.current === 'speaking') {
        stopRecognition();
        releaseMicMonitor();
        micMonitorStateRef.current = 'unavailable';
        return;
      }
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
        recognitionRestartRef.current = setTimeout(() => {
          recognitionRestartRef.current = null;
          if (phaseRef.current === 'speaking') startRecognition(true);
        }, 80);
      } else if (phaseRef.current === 'listening') {
        recognitionRestartRef.current = setTimeout(() => {
          recognitionRestartRef.current = null;
          if (phaseRef.current === 'listening') startRecognition(false);
        }, 120);
      }
    };
    try {
      recognition.start();
      if (!allowWhileSpeaking) changePhase('listening');
    } catch {
      if (allowWhileSpeaking) {
        stopRecognition();
        releaseMicMonitor();
        micMonitorStateRef.current = 'unavailable';
      } else changePhase('error');
    }
  }, [
    armTurnTimer,
    releaseMicMonitor,
    changePhase,
    interruptGeneration,
    note,
    qualityContext,
    sendVoiceTurn,
    stopRecognition,
    stopSpeech,
  ]);

  useEffect(() => {
    if (!active || phase !== 'speaking') return;
    if (interruptionMode === 'speech') startRecognition(true);
    else stopRecognition();
    reportVoiceQuality(qualityContext(), 'interruption_mode', { mode: interruptionMode });
  }, [active, phase, interruptionMode, startRecognition, stopRecognition, qualityContext]);

  const markFirstAudio = useCallback((transport: 'server_tts' | 'device_tts') => {
    if (!speakingStartedAtRef.current) speakingStartedAtRef.current = performance.now();
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

  const playBlob = useCallback((blob: Blob, signal: AbortSignal, onProgress?: (fraction: number) => void) =>
    playVoiceBlob(blob, {
      signal,
      volume: duckedRef.current ? DUCKED_VOLUME : 1,
      onAudio: (audio, owner) => {
        if (audio || audioRef.current === owner) audioRef.current = audio;
      },
      onStart: () => markFirstAudio('server_tts'),
      onProgress,
    }), [markFirstAudio]);

  const browserSpeechFallback = useCallback((text: string, signal: AbortSignal) =>
    speakVoiceFallback(text, {
      signal,
      language: speechLocale(),
      onStart: () => markFirstAudio('device_tts'),
    }), [markFirstAudio]);

  /**
   * Show an answer only as far as Lyo has read it.
   *
   * The written answer streams in far faster than it can be spoken, so without
   * this the whole reply is on screen before the first word is heard and there
   * is nothing to follow. Words of the segment being played are revealed in
   * step with the audio, on top of everything already said.
   */
  const revealSpoken = useCallback((messageId: string, segment: string, fraction: number) => {
    useChatStore.getState().setVoiceSpokenText({
      messageId,
      text: joinSpoken(spokenSoFarRef.current, spokenPrefix(segment, fraction)),
    });
  }, []);

  /** Fold a finished segment into what has been said, ready for the next. */
  const commitSpoken = useCallback((messageId: string, segment: string) => {
    spokenSoFarRef.current = joinSpoken(spokenSoFarRef.current, segment);
    useChatStore.getState().setVoiceSpokenText({
      messageId,
      text: spokenSoFarRef.current,
    });
  }, []);

  /** Release the clamp so the answer reads in full once the turn is over. */
  const releaseSpoken = useCallback(() => {
    spokenSoFarRef.current = '';
    useChatStore.getState().setVoiceSpokenText(null);
  }, []);

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
      || !awaitingAssistantRef.current
      || responseAbortRef.current.signal.aborted
      || !voiceTurnClosedRef.current
      || voiceSegmentDrainActiveRef.current
      || voiceSegmentQueueRef.current.length > 0
    ) return;
    awaitingAssistantRef.current = false;
    acceptedTurnIdRef.current = null;
    lastSpokenTextRef.current = '';
    transcriptRef.current.reset();
    if (pendingRmsBargeTimerRef.current) clearTimeout(pendingRmsBargeTimerRef.current);
    pendingRmsBargeTimerRef.current = null;
    pendingRmsBargeAtRef.current = 0;
    restorePlayback();
    closeVoiceTurn(voiceTurnOutcomeRef.current);
    releaseSpoken();
    changePhase('listening');
    startRecognition();
  }, [changePhase, closeVoiceTurn, releaseSpoken, restorePlayback, startRecognition]);

  const drainVoiceSegments = useCallback(async () => {
    if (voiceSegmentDrainActiveRef.current || !activeRef.current || responseAbortRef.current.signal.aborted) return;
    const owner = responseAbortRef.current;
    const current = () => activeRef.current && !owner.signal.aborted && responseAbortRef.current === owner;
    voiceSegmentDrainActiveRef.current = true;
    if (phaseRef.current !== 'speaking') {
      echoReportedForPlaybackRef.current = false;
      cancelPendingTurn();
      stopRecognition();
      transcriptRef.current.reset();
      speakingStartedAtRef.current = 0;
      changePhase('speaking');
    }
    try {
      while (current() && voiceSegmentQueueRef.current.length > 0) {
        const segment = voiceSegmentQueueRef.current.shift()!;
        const spoken = segment.text.trim();
        if (!spoken) continue;
        lastSpokenTextRef.current = (lastSpokenTextRef.current + ' ' + spoken).trim();
        lastSpokenMessageIdRef.current = segment.messageId;
        let progress = 0;
        try {
          ttsAbortRef.current = segment.controller;
          const blob = await segment.audio;
          if (!current()) return;
          if (!blob) throw new Error('Segment synthesis failed');
          await playBlob(blob, owner.signal, (fraction) => {
            progress = fraction;
            revealSpoken(segment.messageId, spoken, fraction);
          });
        } catch {
          if (!current()) return;
          const remainder = unspokenRemainder(spoken, progress);
          if (remainder) {
            if (voiceTurnOutcomeRef.current !== 'incomplete') voiceTurnOutcomeRef.current = 'fallback';
            await browserSpeechFallback(remainder, owner.signal);
          }
        }
        if (!current()) return;
        commitSpoken(segment.messageId, spoken);
        ttsAbortRef.current = null;
        // Clip boundaries otherwise sound abrupt; stop immediately on barge-in.
        if (current() && voiceSegmentQueueRef.current.length > 0) {
          await waitForSpeechPause(pauseAfterSpeechMs(spoken), { signal: owner.signal });
        }
      }
    } catch {
      if (current()) {
        stopSpeech();
        interruptGeneration();
        releaseSpoken();
        changePhase('error');
        setErrorDetail('Audio playback failed. End and restart live conversation to try again.');
      }
    } finally {
      if (current()) {
        voiceSegmentDrainActiveRef.current = false;
        finishSegmentTurnIfReady();
      }
    }
  }, [browserSpeechFallback, cancelPendingTurn, changePhase, commitSpoken,
    finishSegmentTurnIfReady, interruptGeneration, playBlob, releaseSpoken, revealSpoken,
    stopRecognition, stopSpeech]);

  const handleVoiceStreamEvent = useCallback((event: VoiceStreamEvent) => {
    if (!activeRef.current || !awaitingAssistantRef.current || responseAbortRef.current.signal.aborted
      || !acceptedTurnIdRef.current || event.turnId !== acceptedTurnIdRef.current) return;
    if (responseMessageIdRef.current && responseMessageIdRef.current !== event.messageId) return;
    responseMessageIdRef.current = event.messageId;

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
        language: speechLocale(),
        speed: 0.98,
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
            language: speechLocale(),
            speed: 0.98,
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
      voiceTurnOutcomeRef.current = 'incomplete';
      finishSegmentTurnIfReady();
    }
  }, [drainVoiceSegments, finishSegmentTurnIfReady, qualityContext]);

  useEffect(() => subscribeVoiceStreamEvents(handleVoiceStreamEvent), [handleVoiceStreamEvent]);
  const speakAssistant = useCallback((messageId: string, text: string) => {
    if (!activeRef.current || responseAbortRef.current.signal.aborted) return;
    voiceTurnClosedRef.current = true;
    responseMessageIdRef.current = messageId;
    voiceTurnOutcomeRef.current = 'fallback';
    splitSpeechChunks(text).forEach((spoken, sequence) => {
      const controller = new AbortController();
      voiceSegmentQueueRef.current.push({
        text: spoken, sequence, messageId, controller,
        audio: api.tts.synthesizeStream(spoken, {
          language: speechLocale(), speed: 0.98, signal: controller.signal,
        }).catch(() => null),
      });
    });
    void drainVoiceSegments();
  }, [drainVoiceSegments]);

  const interruptPlayback = useCallback(() => {
    if (!activeRef.current || (phaseRef.current !== 'speaking' && phaseRef.current !== 'thinking')) return;
    reportVoiceQuality(qualityContext(), 'assistant_turn_interrupted', {
      method: 'tap', cancellation_reason: 'user_interrupt',
    });
    stopSpeech();
    cancelPendingTurn();
    stopRecognition();
    interruptGeneration();
    releaseSpoken();
    transcriptRef.current.reset();
    lastSpokenTextRef.current = '';
    currentTurnIdRef.current = null;
    interruptedPreviousTurnRef.current = true;
    setLiveTranscript('');
    changePhase('listening');
    startRecognition();
  }, [cancelPendingTurn, changePhase, interruptGeneration, qualityContext,
    releaseSpoken, startRecognition, stopRecognition, stopSpeech]);

  /**
   * The microphone is louder than Lyo currently is, so someone may be talking
   * over it.
   *
   * Loudness alone does not end Lyo's turn. A room, a cough or a burst of its
   * own playback can all clear the bar, and ending the turn on that means Lyo
   * cuts itself off mid-sentence for no reason. Playback ducks instead, which
   * is instant and reversible, and the recognizer decides: words that are not
   * an echo end the turn for real (in onresult), and a window that closes
   * without them simply brings the volume back.
   */
  const bargeIn = useCallback(() => {
    if (!activeRef.current || phaseRef.current !== 'speaking') return;
    if (pendingRmsBargeAtRef.current > 0) return;
    const detectedAt = voiceQualityNow();
    reportVoiceQuality(qualityContext(), 'barge_in', {
      method: 'rms_ducked',
      speaking_elapsed_ms: speakingStartedAtRef.current > 0
        ? Math.max(0, Math.round(detectedAt - speakingStartedAtRef.current))
        : -1,
      generation_active: useChatStore.getState().isGenerating,
    });
    pendingRmsBargeAtRef.current = detectedAt;
    duckPlayback();
    loudFramesRef.current = 0;
    if (pendingRmsBargeTimerRef.current) clearTimeout(pendingRmsBargeTimerRef.current);
    pendingRmsBargeTimerRef.current = setTimeout(() => {
      if (!pendingRmsBargeAtRef.current) return;
      reportVoiceQuality(qualityContext(), 'false_barge_in', {
        method: 'rms_without_non_echo_speech',
        confirm_window_ms: 1800,
      });
      pendingRmsBargeAtRef.current = 0;
      pendingRmsBargeTimerRef.current = null;
      // Nothing the recognizer could call speech: Lyo was talking to itself.
      if (phaseRef.current === 'speaking') restorePlayback();
    }, 1800);
  }, [duckPlayback, qualityContext, restorePlayback]);

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
    currentTurnIdRef.current = null;
    interruptedPreviousTurnRef.current = false;
    lastSpokenTextRef.current = '';
    transcriptRef.current.reset();
    if (!createSpeechRecognition()) {
      setErrorDetail('This browser cannot listen. Try Chrome, Edge or Safari.');
      changePhase('error');
      return;
    }
    // Start listening straight away. The recognizer asks for the microphone
    // itself, so nothing else may hold it open first.
    startRecognition();
    return () => {
      activeRef.current = false;
      cancelPendingTurn();
      stopRecognition();
      stopSpeech();
      releaseMicMonitor();
      releaseSpoken();
      transcriptRef.current.reset();
      currentTurnIdRef.current = null;
    };
  }, [active, cancelPendingTurn, changePhase, releaseMicMonitor, releaseSpoken, startRecognition, stopRecognition, stopSpeech]);

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
    releaseSpoken();
    changePhase('idle');
    setLiveTranscript('');
    setMicSilent(false);
    setErrorDetail('');
  }, [
    active,
    cancelPendingTurn,
    changePhase,
    releaseMicMonitor,
    releaseSpoken,
    stopRecognition,
    stopSpeech,
  ]);

  useEffect(() => {
    if (!active) return;
    const tick = () => {
      const analyser = analyserRef.current;
      if (analyser && speakingStartedAtRef.current > 0 && phaseRef.current === 'speaking' && performance.now() - speakingStartedAtRef.current > BARGE_IN_GRACE_MS) {
        const samples = new Uint8Array(analyser.fftSize);
        analyser.getByteTimeDomainData(samples);
        let sum = 0;
        for (let i = 0; i < samples.length; i++) {
          const normalized = (samples[i] - 128) / 128;
          sum += normalized * normalized;
        }
        const rms = Math.sqrt(sum / samples.length);

        // Track how loud Lyo's own playback comes back through the microphone:
        // fall quickly toward quiet so the floor follows a pause in its speech,
        // and rise slowly so a learner talking over it cannot drag the floor up
        // to meet their own voice.
        bleedFloorRef.current = bleedFloorRef.current === 0
          ? rms
          : rms < bleedFloorRef.current
            ? bleedFloorRef.current * 0.9 + rms * 0.1
            : bleedFloorRef.current * 0.995 + rms * 0.005;

        const bar = Math.max(BARGE_IN_RMS_THRESHOLD, bleedFloorRef.current * BARGE_IN_EXCESS);
        loudFramesRef.current = rms > bar ? loudFramesRef.current + 1 : 0;
        if (loudFramesRef.current >= BARGE_IN_FRAMES) bargeIn();
      } else {
        loudFramesRef.current = 0;
        bleedFloorRef.current = 0;
      }
      animationFrameRef.current = requestAnimationFrame(tick);
    };
    animationFrameRef.current = requestAnimationFrame(tick);
    return () => {
      if (animationFrameRef.current != null) cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    };
  }, [active, bargeIn]);

  useEffect(() => {
    if (!active || isGenerating || !awaitingAssistantRef.current || voiceTurnClosedRef.current
      || !responseMessageIdRef.current) return;
    // Only this request's rendered message may supply a whole-answer fallback.
    // A failed request or canonical reload must never replay an older answer.
    const latest = useChatStore.getState().getActiveConversation()?.messages.find(
      (message) => message.id === responseMessageIdRef.current && message.role === 'assistant',
    );
    voiceTurnClosedRef.current = true;
    if (voiceSegmentsReceivedRef.current) {
      voiceTurnClosedRef.current = true;
      finishSegmentTurnIfReady();
      return;
    }
    if (!latest?.content.trim()) {
      voiceTurnOutcomeRef.current = 'incomplete';
      finishSegmentTurnIfReady();
      return;
    }
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

  // Long waits get a short, optional spoken acknowledgement. The canonical
  // answer still comes from the chat stream; filler is never saved as an answer.
  // Clearing the timer and cancelling its utterance avoids talking over Lyo.
  useEffect(() => {
    if (!active || phase !== 'thinking') {
      setThinkingNudge('');
      return;
    }
    const spanish = typeof navigator !== 'undefined'
      && speechLocale().toLowerCase().startsWith('es');
    const nudges = spanish
      ? ['Mmm, déjame ver…', 'Sigo revisando…', 'Un momento más…']
      : ['Hmm, let me see…', 'Still checking…', 'One more moment…'];
    const timers = nudges.map((line, index) => window.setTimeout(() => {
      if (!activeRef.current || phaseRef.current !== 'thinking') return;
      setThinkingNudge(line);
      // Only the first nudge speaks, preventing an artificial monologue
      // during long requests. Browsers may block synthesis without a gesture.
      if (index === 0 && 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window) {
        const cue = new SpeechSynthesisUtterance(line);
        cue.lang = spanish ? 'es-ES' : 'en-US';
        cue.rate = 1.08;
        cue.volume = 0.65;
        try { window.speechSynthesis.speak(cue); } catch { /* visual cue remains */ }
      }
    }, [2400, 6500, 11500][index]));
    return () => {
      timers.forEach(window.clearTimeout);
      window.speechSynthesis?.cancel();
    };
  }, [active, phase]);

  const changeVoiceLanguage = (value: 'device' | 'en-US' | 'es-ES') => {
    preferredSpeechLanguageRef.current = value;
    setPreferredSpeechLanguage(value);
    if (phaseRef.current === 'listening') {
      stopRecognition();
      // Restart with the new model after the previous speech service releases
      // the mic; the text already collected in this turn remains intact.
      setTimeout(() => {
        if (activeRef.current && phaseRef.current === 'listening') startRecognition();
      }, 100);
    }
  };

  const endSession = () => setVoiceSessionActive(false);

  if (!active) return null;

  // Spoken words can arrive before the canonical assistant message is inserted
  // into the chat store. Still show them live, without replacing an older answer.
  const liveAssistantCaption = spokenText
    && spokenText.messageId === responseMessageIdRef.current
    ? spokenText.text : '';
  const status = phase === 'listening'
    ? (micSilent ? 'Check your microphone permission' : 'Listening')
    : phase === 'thinking' ? 'Lyo is thinking'
      : phase === 'speaking' ? 'Lyo is speaking'
        : phase === 'error' ? 'Voice needs attention' : 'Connecting';
  const caption = phase === 'listening'
    ? (liveTranscript || 'Go ahead. I’m listening.')
    : phase === 'speaking'
      ? (liveAssistantCaption || 'Speaking…')
      : phase === 'thinking'
        ? (thinkingNudge || 'Thinking about your question…')
        : phase === 'error'
          ? (errorDetail || 'Check your microphone and try again.')
          : 'Getting your microphone ready…';
  const transcriptMessages = (conversation?.messages ?? [])
    .filter((message) => message.role === 'assistant' || message.role === 'user');

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="LYO live voice conversation"
      className="fixed inset-0 z-[100] overflow-hidden bg-[#090817] text-white"
    >
      <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(circle_at_50%_38%,rgba(132,80,231,0.24),transparent_54%),radial-gradient(circle_at_80%_100%,rgba(249,115,22,0.13),transparent_44%)]" />
      <div className="relative flex h-full flex-col mx-auto w-full max-w-3xl px-5 pt-[max(env(safe-area-inset-top),1.25rem)] pb-[max(env(safe-area-inset-bottom),1.25rem)]">
        <header className="flex items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
              <h2 className="text-lg font-semibold tracking-tight">Live with Lyo</h2>
            </div>
            <p className="text-xs text-white/55 mt-1">A real conversation, in English or Spanish</p>
          </div>
          <label className="sr-only" htmlFor="lyo-voice-language">Voice language</label>
          <select id="lyo-voice-language" aria-label="Voice language"
            value={preferredSpeechLanguage}
            onChange={(event) => changeVoiceLanguage(event.target.value as 'device' | 'en-US' | 'es-ES')}
            disabled={phase === 'thinking' || phase === 'speaking'}
            className="max-w-[9rem] rounded-full border border-white/20 bg-[#211837] px-3 py-2 text-xs text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-white disabled:opacity-50"
          >
            <option value="device">Device language</option>
            <option value="en-US">English</option>
            <option value="es-ES">Español</option>
          </select>
          <button type="button" onClick={endSession}
            className="flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3 py-2 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-white"
            aria-label="End live voice and return to chat">
            <X className="h-4 w-4" /> End
          </button>
        </header>

        <main className="flex-1 min-h-0 flex flex-col items-center justify-center gap-5 sm:gap-7">
          <div
            className={cn('relative flex items-center justify-center rounded-full transition-transform duration-300',
              phase === 'speaking' && 'scale-[1.035]',
              phase === 'listening' && liveTranscript && 'scale-105')}
            onClick={interruptionMode === 'tap' && (phase === 'speaking' || phase === 'thinking') ? interruptPlayback : undefined}
            role={interruptionMode === 'tap' && (phase === 'speaking' || phase === 'thinking') ? 'button' : undefined}
            tabIndex={interruptionMode === 'tap' && (phase === 'speaking' || phase === 'thinking') ? 0 : undefined}
            onKeyDown={(event) => {
              if (interruptionMode === 'tap' && (event.key === 'Enter' || event.key === ' ')
                && (phase === 'speaking' || phase === 'thinking')) interruptPlayback();
            }}
            aria-label={interruptionMode === 'tap' ? 'Tap the mascot to speak' : undefined}
          >
            <div className={cn('absolute w-56 h-56 sm:w-72 sm:h-72 rounded-full blur-3xl opacity-50',
              phase === 'speaking' ? 'bg-orange-500/45 animate-pulse'
                : phase === 'listening' ? 'bg-emerald-500/30 animate-pulse' : 'bg-violet-500/40')} />
            <div className={cn('absolute w-[240px] h-[240px] sm:w-[300px] sm:h-[300px] rounded-full border-2',
              phase === 'speaking' ? 'border-orange-400/45 animate-ping'
                : phase === 'listening' ? 'border-emerald-400/40 animate-pulse' : 'border-violet-400/25')} />
            <div className="relative w-48 h-48 sm:w-60 sm:h-60 flex items-center justify-center">
              <MascotAvatar thinking={phase === 'thinking'} speaking={phase === 'speaking'}
                idle={phase === 'listening' || phase === 'idle'} size={240} alt={status} />
            </div>
          </div>
          <div className="flex flex-col items-center max-w-xl w-full gap-3 text-center">
            <div className="flex items-center gap-2 text-sm font-medium text-violet-200" role="status" aria-live="polite">
              {phase === 'speaking' ? <Volume2 className="h-4 w-4" />
                : phase === 'error' ? <MicOff className="h-4 w-4" />
                  : <Mic className="h-4 w-4" />}
              {status}
            </div>
            <p className="text-xl sm:text-2xl leading-relaxed font-medium min-h-[4.5rem] max-h-36 overflow-y-auto px-2"
              aria-live="polite" aria-atomic="false">{caption}</p>
            <p className="text-xs text-white/45">
              {phase === 'listening' ? 'Speak naturally — Lyo will answer when you finish.'
                : phase === 'speaking' && interruptionMode === 'speech' ? 'Just start talking to interrupt.'
                  : (phase === 'speaking' || phase === 'thinking') && interruptionMode === 'tap'
                    ? 'Hands-free interruption is unavailable in this browser. Tap Lyo to speak.'
                    : phase === 'thinking' ? 'Your conversation is being saved.' : ' '}
            </p>
          </div>
        </main>

        {showTranscript && (
          <section className="shrink-0 max-h-[38vh] overflow-y-auto rounded-2xl border border-white/15 bg-black/35 p-4 mb-4"
            aria-label="Live transcript" id="lyo-voice-transcript">
            <h3 className="font-semibold text-sm text-white/75 mb-3">Conversation transcript</h3>
            <div className="flex flex-col gap-3">
              {transcriptMessages.length === 0 && !liveAssistantCaption && !liveTranscript && <p className="text-sm text-white/50">Your conversation will appear here as you speak.</p>}
              {transcriptMessages.map((message) => {
                const assistantCurrentlySpeaking = phase === 'speaking'
                  && message.role === 'assistant' && message.id === spokenText?.messageId;
                const text = assistantCurrentlySpeaking
                  ? liveAssistantCaption : message.content;
                if (!text.trim()) return null;
                return (
                  <div key={message.id} className={cn('text-sm leading-relaxed rounded-xl p-3',
                    message.role === 'user' ? 'bg-violet-500/20 ml-6' : 'bg-white/10 mr-6')}>
                    <span className="block text-[11px] font-semibold text-white/45 mb-1">
                      {message.role === 'user' ? 'You' : 'Lyo'}
                    </span>
                    <p className="whitespace-pre-wrap">{text}</p>
                  </div>
                );
              })}
              {phase === 'speaking' && liveAssistantCaption
                && !transcriptMessages.some((message) => message.id === spokenText?.messageId) && (
                <div className="rounded-xl bg-white/10 mr-6 p-3 text-sm" aria-live="polite">
                  <span className="block text-[11px] text-white/45 mb-1">Lyo · live</span>
                  <p className="whitespace-pre-wrap">{liveAssistantCaption}</p>
                </div>
              )}
              {phase === 'listening' && liveTranscript && (
                <div className="rounded-xl bg-violet-500/20 ml-6 p-3 text-sm">
                  <span className="block text-[11px] text-white/45 mb-1">You · live</span>
                  {liveTranscript}
                </div>
              )}
            </div>
          </section>
        )}
        <footer className="flex items-center justify-center gap-3">
          <button type="button" onClick={() => setShowTranscript((shown) => !shown)}
            aria-expanded={showTranscript} aria-controls="lyo-voice-transcript"
            className="flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-5 py-3 text-sm font-medium hover:bg-white/15 focus-visible:outline focus-visible:outline-2 focus-visible:outline-white">
            <MessageSquareText className="h-4 w-4" />
            {showTranscript ? 'Hide transcript' : 'Transcript'}
          </button>
          {phase === 'error' && (
            <button type="button" onClick={() => { setErrorDetail(''); changePhase('listening'); startRecognition(); }}
              className="rounded-full bg-violet-500 px-5 py-3 text-sm font-medium">Try microphone again</button>
          )}
        </footer>
        {debugEnabled && <pre className="mt-3 max-h-24 overflow-auto whitespace-pre-wrap font-mono text-[10px] text-white/50">
          {debugLog.length ? debugLog.join('\n') : 'waiting for speech engine…'}
        </pre>}
      </div>
    </div>
  );
}
