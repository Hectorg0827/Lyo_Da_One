'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { AudioLines, MicOff, Volume2 } from 'lucide-react';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
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

type VoiceQaSnapshot = {
  submitToAudioMs?: number;
  micToAudioMs?: number;
  segmentArrivalMs?: number;
  bargeIns: number;
  possibleFalseBargeIns: number;
  echoRejects: number;
  reconnects: number;
  lastHandoff?: 'classroom' | 'test_prep';
};

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
const MIC_ACTIVITY_RMS_THRESHOLD = 0.04;
const MIC_ACTIVITY_FRAMES = 3;
const POSSIBLE_FALSE_BARGE_WINDOW_MS = 1600;

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
  const [qaEnabled, setQaEnabled] = useState(false);
  const [qaSnapshot, setQaSnapshot] = useState<VoiceQaSnapshot>({
    bargeIns: 0,
    possibleFalseBargeIns: 0,
    echoRejects: 0,
    reconnects: 0,
  });

  const phaseRef = useRef<VoicePhase>('idle');
  const activeRef = useRef(false);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const finalTranscriptRef = useRef('');
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
  const qaSessionIdRef = useRef('');
  const currentTurnIdRef = useRef<string | null>(null);
  const firstMicActivityAtRef = useRef<number | null>(null);
  const firstRecognitionAtRef = useRef<number | null>(null);
  const lastRecognitionAtRef = useRef<number | null>(null);
  const selectedEndpointDelayRef = useRef<number | null>(null);
  const turnSubmittedAtRef = useRef<number | null>(null);
  const firstSegmentAtRef = useRef<number | null>(null);
  const firstAudioAtRef = useRef<number | null>(null);
  const listeningStartedAtRef = useRef<number | null>(null);
  const bargeInAtRef = useRef<number | null>(null);
  const possibleFalseBargeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const micActivityFramesRef = useRef(0);
  const transportErrorAtRef = useRef<number | null>(null);

  const changePhase = useCallback((next: VoicePhase) => {
    phaseRef.current = next;
    setPhase(next);
  }, []);

  const reportVoiceQuality = useCallback((
    event: string,
    metrics: Record<string, string | number | boolean> = {},
    turnId: string | null = currentTurnIdRef.current,
  ) => {
    if (!qaSessionIdRef.current) return;
    void api.chat.reportVoiceQuality({
      session_id: qaSessionIdRef.current,
      turn_id: turnId ?? undefined,
      conversation_id: useChatStore.getState().activeConversationId ?? undefined,
      platform: 'web',
      event,
      locale: typeof navigator !== 'undefined' ? navigator.language || 'auto' : 'auto',
      scenario: 'live_conversation',
      metrics,
    }).catch(() => undefined);
  }, []);

  const resetUserTurnTiming = useCallback(() => {
    currentTurnIdRef.current = null;
    firstMicActivityAtRef.current = null;
    firstRecognitionAtRef.current = null;
    lastRecognitionAtRef.current = null;
    selectedEndpointDelayRef.current = null;
    turnSubmittedAtRef.current = null;
    firstSegmentAtRef.current = null;
    firstAudioAtRef.current = null;
    bargeInAtRef.current = null;
    micActivityFramesRef.current = 0;
    listeningStartedAtRef.current = performance.now();
  }, []);

  const markFirstAudioStarted = useCallback(() => {
    if (firstAudioAtRef.current != null) return;
    const now = performance.now();
    firstAudioAtRef.current = now;
    const submitToAudioMs = turnSubmittedAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - turnSubmittedAtRef.current));
    const micToAudioMs = firstMicActivityAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - firstMicActivityAtRef.current));
    const recognitionToAudioMs = firstRecognitionAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - firstRecognitionAtRef.current));
    const segmentToAudioMs = firstSegmentAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - firstSegmentAtRef.current));

    setQaSnapshot((previous) => ({
      ...previous,
      submitToAudioMs,
      micToAudioMs,
    }));
    reportVoiceQuality('first_audio', {
      ...(submitToAudioMs == null ? {} : { submit_to_audio_ms: submitToAudioMs }),
      ...(micToAudioMs == null ? {} : { mic_to_audio_ms: micToAudioMs }),
      ...(recognitionToAudioMs == null ? {} : { recognition_to_audio_ms: recognitionToAudioMs }),
      ...(segmentToAudioMs == null ? {} : { segment_to_audio_ms: segmentToAudioMs }),
    });
  }, [reportVoiceQuality]);

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
    finalTranscriptRef.current = '';
    setLiveTranscript('');
    if (!transcript || !activeRef.current) return;
    if (isLikelyPlaybackEcho(transcript, lastSpokenTextRef.current)) {
      setQaSnapshot((previous) => ({ ...previous, echoRejects: previous.echoRejects + 1 }));
      reportVoiceQuality('semantic_echo_rejected', {
        phase: phaseRef.current,
      });
      changePhase('listening');
      return;
    }

    if (possibleFalseBargeTimerRef.current) {
      clearTimeout(possibleFalseBargeTimerRef.current);
      possibleFalseBargeTimerRef.current = null;
    }

    const now = performance.now();
    const turnId = crypto.randomUUID();
    currentTurnIdRef.current = turnId;
    turnSubmittedAtRef.current = now;
    firstSegmentAtRef.current = null;
    firstAudioAtRef.current = null;

    const endpointingMs = lastRecognitionAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - lastRecognitionAtRef.current));
    const utteranceMs = firstRecognitionAtRef.current == null
      ? undefined
      : Math.max(0, Math.round(now - firstRecognitionAtRef.current));
    reportVoiceQuality('turn_submitted', {
      ...(endpointingMs == null ? {} : { endpointing_ms: endpointingMs }),
      ...(utteranceMs == null ? {} : { recognized_utterance_ms: utteranceMs }),
      ...(selectedEndpointDelayRef.current == null
        ? {}
        : { selected_endpoint_delay_ms: selectedEndpointDelayRef.current }),
      interrupted_previous_turn: Boolean(
        interruptedPreviousTurnRef.current
        || phaseRef.current === 'speaking'
        || useChatStore.getState().isGenerating
      ),
    }, turnId);

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
    changePhase('thinking');
    interruptedPreviousTurnRef.current = false;
    await sendMessage(transcript, [], {
      voiceSession: true,
      voiceInterruptedPreviousTurn: interruptedPreviousTurn,
      voiceTurnId: turnId,
      voiceLocale: navigator.language || 'auto',
    });
  }, [
    changePhase,
    interruptGeneration,
    reportVoiceQuality,
    sendMessage,
    stopRecognition,
    stopSpeech,
  ]);

  const startRecognition = useCallback((allowWhileSpeaking = false) => {
    if (!activeRef.current || (phaseRef.current === 'speaking' && !allowWhileSpeaking)) return;
    stopRecognition();
    const recognition = createSpeechRecognition();
    if (!recognition) {
      changePhase('error');
      return;
    }
    recognitionRef.current = recognition;
    recognition.lang = navigator.language || 'en-US';
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.onresult = (event) => {
      // A stopped recognizer may still dispatch queued callbacks after a new
      // shadow recognizer has already taken ownership. Ignore those stale
      // callbacks so two recognition sessions can never contribute to one turn.
      if (recognitionRef.current !== recognition) return;
      let finalText = finalTranscriptRef.current;
      let interimText = '';
      const start = event.resultIndex ?? 0;
      for (let i = start; i < event.results.length; i++) {
        const result = event.results[i];
        const transcript = result?.[0]?.transcript?.trim() ?? '';
        if (!transcript) continue;
        if (result.isFinal) finalText = `${finalText} ${transcript}`.trim();
        else interimText = `${interimText} ${transcript}`.trim();
      }
      const combined = `${finalText} ${interimText}`.trim();
      if (!combined) return;

      const recognitionNow = performance.now();
      if (firstRecognitionAtRef.current == null) {
        firstRecognitionAtRef.current = recognitionNow;
        const listenGapMs = listeningStartedAtRef.current == null
          ? undefined
          : Math.max(0, Math.round(recognitionNow - listeningStartedAtRef.current));
        reportVoiceQuality('first_recognition_result', {
          ...(listenGapMs == null ? {} : { listening_to_recognition_ms: listenGapMs }),
          recognizer_locale: recognition.lang || 'auto',
        });
      }
      lastRecognitionAtRef.current = recognitionNow;

      // During playback, keep a shadow recognizer armed. Acoustic echo
      // cancellation handles most speaker bleed; semantic echo rejection is
      // the second line of defence. A non-echo utterance owns the floor
      // immediately, so the first word is not lost while a new recognizer is
      // being started after RMS barge-in.
      if (phaseRef.current === 'speaking') {
        // Do not commit a final playback echo into finalTranscriptRef. Otherwise
        // the next genuine barge-in would be concatenated with Lyo's own words.
        if (isLikelyPlaybackEcho(combined, lastSpokenTextRef.current)) {
          setQaSnapshot((previous) => ({ ...previous, echoRejects: previous.echoRejects + 1 }));
          reportVoiceQuality('semantic_echo_rejected', {
            phase: 'speaking',
          });
          return;
        }
        if (possibleFalseBargeTimerRef.current) {
          clearTimeout(possibleFalseBargeTimerRef.current);
          possibleFalseBargeTimerRef.current = null;
        }
        const confirmedAt = performance.now();
        const bargeRecognitionMs = bargeInAtRef.current == null
          ? undefined
          : Math.max(0, Math.round(confirmedAt - bargeInAtRef.current));
        setQaSnapshot((previous) => ({ ...previous, bargeIns: previous.bargeIns + 1 }));
        reportVoiceQuality('barge_in_confirmed', {
          source: bargeInAtRef.current == null ? 'semantic' : 'rms_plus_semantic',
          ...(bargeRecognitionMs == null ? {} : { rms_to_recognition_ms: bargeRecognitionMs }),
        });
        interruptedPreviousTurnRef.current = true;
        stopSpeech();
        if (useChatStore.getState().isGenerating) interruptGeneration();
        changePhase('listening');
      }

      finalTranscriptRef.current = finalText;
      setLiveTranscript(combined);
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      const endpointDelay = voiceEndOfTurnDelayMs(combined);
      selectedEndpointDelayRef.current = endpointDelay;
      silenceTimerRef.current = setTimeout(() => {
        void sendVoiceTurn(combined);
      }, endpointDelay);
    };
    recognition.onerror = (event) => {
      if (recognitionRef.current !== recognition || !activeRef.current) return;
      if (event?.error === 'no-speech' || event?.error === 'aborted') return;
      changePhase('error');
    };
    recognition.onend = () => {
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
  }, [changePhase, sendVoiceTurn, stopRecognition]);

  const playBlob = useCallback((
    blob: Blob,
    onStarted?: () => void,
  ) => new Promise<void>((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    let settled = false;
    let started = false;
    const cleanup = () => {
      URL.revokeObjectURL(url);
      if (audioRef.current === audio) audioRef.current = null;
    };
    audioRef.current = audio;
    audio.onplaying = () => {
      if (started) return;
      started = true;
      onStarted?.();
    };
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

  const browserSpeechFallback = useCallback((
    text: string,
    onStarted?: () => void,
  ) => new Promise<void>((resolve) => {
    if (typeof window === 'undefined' || !window.speechSynthesis) { resolve(); return; }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = navigator.language || 'en-US';
    utterance.rate = 1.02;
    utterance.onstart = () => onStarted?.();
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
    reportVoiceQuality('assistant_turn_complete');
    resetUserTurnTiming();
    changePhase('listening');
    startRecognition();
  }, [changePhase, reportVoiceQuality, resetUserTurnTiming, startRecognition]);

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
          await playBlob(blob, markFirstAudioStarted);
        } catch {
          if (!activeRef.current || phaseRef.current !== 'speaking') break;
          await browserSpeechFallback(spoken, markFirstAudioStarted);
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
    markFirstAudioStarted,
    playBlob,
    stopRecognition,
  ]);

  const handleVoiceStreamEvent = useCallback((event: VoiceStreamEvent) => {
    if (!activeRef.current) return;

    if (event.type === 'voice_text_segment') {
      voiceSegmentsReceivedRef.current = true;
      awaitingAssistantRef.current = true;
      const segmentNow = performance.now();
      const isFirstSegment = firstSegmentAtRef.current == null;
      if (isFirstSegment) {
        firstSegmentAtRef.current = segmentNow;
        const submitToSegmentMs = turnSubmittedAtRef.current == null
          ? undefined
          : Math.max(0, Math.round(segmentNow - turnSubmittedAtRef.current));
        setQaSnapshot((previous) => ({
          ...previous,
          segmentArrivalMs: submitToSegmentMs,
        }));
        reportVoiceQuality('first_voice_segment', {
          ...(submitToSegmentMs == null ? {} : { submit_to_segment_ms: submitToSegmentMs }),
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
      const ttsStartedAt = performance.now();
      const audio = api.tts.synthesizeStream(event.text, {
        language: navigator.language || 'auto',
        speed: 1.02,
        signal: controller.signal,
      }).then((blob) => {
        if (isFirstSegment) {
          reportVoiceQuality('first_tts_ready', {
            tts_ms: Math.max(0, Math.round(performance.now() - ttsStartedAt)),
          });
        }
        return blob;
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
          if (firstSegmentAtRef.current == null) {
            firstSegmentAtRef.current = performance.now();
            const submitToReadyMs = turnSubmittedAtRef.current == null
              ? undefined
              : Math.max(0, Math.round(firstSegmentAtRef.current - turnSubmittedAtRef.current));
            setQaSnapshot((previous) => ({
              ...previous,
              segmentArrivalMs: submitToReadyMs,
            }));
            reportVoiceQuality('voice_ready_fallback', {
              ...(submitToReadyMs == null ? {} : { submit_to_ready_ms: submitToReadyMs }),
            });
          }
          const ttsStartedAt = performance.now();
          const audio = api.tts.synthesizeStream(event.text, {
            language: navigator.language || 'auto',
            speed: 1.02,
            signal: controller.signal,
          }).then((blob) => {
            reportVoiceQuality('fallback_tts_ready', {
              tts_ms: Math.max(0, Math.round(performance.now() - ttsStartedAt)),
            });
            return blob;
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
      reportVoiceQuality('voice_incomplete');
      finishSegmentTurnIfReady();
      return;
    }

    if (event.type === 'voice_transport_error') {
      transportErrorAtRef.current = performance.now();
      reportVoiceQuality('transport_error');
      return;
    }

    if (event.type === 'voice_transport_recovered') {
      const recoveredAt = performance.now();
      const recoveryMs = transportErrorAtRef.current == null
        ? undefined
        : Math.max(0, Math.round(recoveredAt - transportErrorAtRef.current));
      transportErrorAtRef.current = null;
      setQaSnapshot((previous) => ({
        ...previous,
        reconnects: previous.reconnects + 1,
      }));
      reportVoiceQuality('transport_recovered', {
        ...(recoveryMs == null ? {} : { recovery_ms: recoveryMs }),
      });
      return;
    }

    if (event.type === 'voice_handoff') {
      setQaSnapshot((previous) => ({
        ...previous,
        lastHandoff: event.target,
      }));
      reportVoiceQuality('learning_handoff', {
        target: event.target,
        voice_session_active: activeRef.current,
      });
    }
  }, [drainVoiceSegments, finishSegmentTurnIfReady, reportVoiceQuality]);

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
    finalTranscriptRef.current = '';
    setLiveTranscript('');
    changePhase('listening');
    startRecognition();
  }, [changePhase, interruptGeneration, startRecognition, stopSpeech]);

  useEffect(() => {
    if (!active) return;
    activeRef.current = true;
    if (!createSpeechRecognition() || !navigator.mediaDevices?.getUserMedia) {
      changePhase('error');
      return;
    }
    let cancelled = false;
    void navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    }).then((stream) => {
      if (cancelled) { stream.getTracks().forEach((track) => track.stop()); return; }
      mediaStreamRef.current = stream;
      const Context = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (Context) {
        const context = new Context();
        const source = context.createMediaStreamSource(stream);
        const analyser = context.createAnalyser();
        analyser.fftSize = 512;
        analyser.smoothingTimeConstant = 0.2;
        source.connect(analyser);
        audioContextRef.current = context;
        analyserRef.current = analyser;
      }
      startRecognition();
    }).catch(() => {
      changePhase('error');
    });
    return () => { cancelled = true; };
  }, [active, changePhase, startRecognition]);

  useEffect(() => {
    activeRef.current = active;
    if (active) return;
    awaitingAssistantRef.current = false;
    stopRecognition();
    stopSpeech();
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    mediaStreamRef.current = null;
    void audioContextRef.current?.close();
    audioContextRef.current = null;
    analyserRef.current = null;
    if (animationFrameRef.current != null) cancelAnimationFrame(animationFrameRef.current);
    animationFrameRef.current = null;
    changePhase('idle');
    setLiveTranscript('');
  }, [active, changePhase, stopRecognition, stopSpeech]);

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

  const endSession = () => setVoiceSessionActive(false);

  if (!active) return null;

  const label = phase === 'listening'
    ? (liveTranscript || 'Listening…')
    : phase === 'thinking'
      ? 'Lyo is thinking…'
      : phase === 'speaking'
        ? 'Lyo is speaking — start talking to interrupt'
        : phase === 'error'
          ? 'Voice unavailable'
          : 'Voice ready';

  return (
    <div className="max-w-3xl mx-auto mb-2 rounded-2xl border border-lyo-500/25 bg-lyo-500/10 px-3 py-2.5 flex items-center gap-3">
      <div className={cn(
        'w-9 h-9 rounded-full flex items-center justify-center shrink-0',
        phase === 'speaking' ? 'bg-lyo-500/20 text-lyo-200' : 'bg-white/10 text-white/80'
      )}>
        {phase === 'speaking' ? <Volume2 className="w-4 h-4" /> : phase === 'error' ? <MicOff className="w-4 h-4" /> : <AudioLines className="w-4 h-4" />}
      </div>
      <div className="min-w-0 flex-1">
        <div className="text-xs font-semibold text-white/85">Live conversation</div>
        <div className="text-xs text-white/55 truncate">{label}</div>
      </div>
      <button
        type="button"
        onClick={endSession}
        className="px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/15 text-xs text-white/75"
      >
        End
      </button>
    </div>
  );
}
