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
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
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

  const stopRecognition = useCallback(() => {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
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
    if (isLikelyPlaybackEcho(transcript, lastSpokenTextRef.current)) {
      changePhase('listening');
      return;
    }
    stopSpeech();
    stopRecognition();
    const interruptedPreviousTurn = interruptedPreviousTurnRef.current
      || phaseRef.current === 'speaking'
      || useChatStore.getState().isGenerating;
    if (useChatStore.getState().isGenerating) interruptGeneration();
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
      voiceTurnId: crypto.randomUUID(),
      voiceLocale: navigator.language || 'auto',
    });
  }, [changePhase, interruptGeneration, note, sendMessage, stopRecognition, stopSpeech]);

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
    recognition.onspeechstart = () => note('speech detected');
    recognition.onspeechend = () => note('speech ended');
    // The engine heard words but could not transcribe them. That is not a
    // failure of the session — keep listening rather than going quiet.
    recognition.onnomatch = () => note('no match (heard, not understood)');

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
          return;
        }
        interruptedPreviousTurnRef.current = true;
        stopSpeech();
        if (useChatStore.getState().isGenerating) interruptGeneration();
        changePhase('listening');
      }

      setLiveTranscript(combined);
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = setTimeout(() => {
        void sendVoiceTurn(combined);
      }, voiceEndOfTurnDelayMs(combined));
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
  }, [changePhase, note, sendVoiceTurn, stopRecognition]);

  const playBlob = useCallback((blob: Blob) => new Promise<void>((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    let settled = false;
    const cleanup = () => {
      URL.revokeObjectURL(url);
      if (audioRef.current === audio) audioRef.current = null;
    };
    audioRef.current = audio;
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
  }), []);

  const browserSpeechFallback = useCallback((text: string) => new Promise<void>((resolve) => {
    if (typeof window === 'undefined' || !window.speechSynthesis) { resolve(); return; }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = navigator.language || 'en-US';
    utterance.rate = 1.02;
    utterance.onend = () => resolve();
    utterance.onerror = () => resolve();
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(utterance);
  }), []);

  const finishSegmentTurnIfReady = useCallback(() => {
    if (
      !activeRef.current
      || !voiceTurnClosedRef.current
      || voiceSegmentDrainActiveRef.current
      || voiceSegmentQueueRef.current.length > 0
    ) return;
    awaitingAssistantRef.current = false;
    changePhase('listening');
    startRecognition();
  }, [changePhase, startRecognition]);

  const drainVoiceSegments = useCallback(async () => {
    if (voiceSegmentDrainActiveRef.current || !activeRef.current) return;
    voiceSegmentDrainActiveRef.current = true;
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
  }, [drainVoiceSegments, finishSegmentTurnIfReady]);

  useEffect(() => subscribeVoiceStreamEvents(handleVoiceStreamEvent), [handleVoiceStreamEvent]);
  const speakAssistant = useCallback(async (messageId: string, text: string) => {
    const chunks = splitSpeechChunks(text);
    if (!chunks.length || !activeRef.current) return;
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
        changePhase('listening');
        startRecognition();
      }
    }
  }, [browserSpeechFallback, changePhase, playBlob, startRecognition, stopRecognition]);

  const bargeIn = useCallback(() => {
    if (!activeRef.current || phaseRef.current !== 'speaking') return;
    interruptedPreviousTurnRef.current = true;
    stopSpeech();
    if (useChatStore.getState().isGenerating) interruptGeneration();
    loudFramesRef.current = 0;
    transcriptRef.current.reset();
    setLiveTranscript('');
    changePhase('listening');
    startRecognition();
  }, [changePhase, interruptGeneration, startRecognition, stopSpeech]);

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
    stopRecognition();
    stopSpeech();
    releaseMicMonitor();
    if (animationFrameRef.current != null) cancelAnimationFrame(animationFrameRef.current);
    animationFrameRef.current = null;
    changePhase('idle');
    setLiveTranscript('');
    setMicSilent(false);
    setErrorDetail('');
  }, [active, changePhase, releaseMicMonitor, stopRecognition, stopSpeech]);

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
