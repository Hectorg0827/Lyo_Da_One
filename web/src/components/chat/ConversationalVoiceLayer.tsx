'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { AudioLines, MicOff, Volume2 } from 'lucide-react';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import {
  useChatStore,
  type VoiceIncomplete,
  type VoiceReady,
  type VoiceTextSegment,
} from '@/stores/chat-store';
import {
  createSpeechRecognition,
  isLikelyPlaybackEcho,
  splitSpeechChunks,
  type SpeechRecognitionLike,
} from '@/lib/conversational-voice';

type VoicePhase = 'idle' | 'listening' | 'thinking' | 'speaking' | 'error';

const END_OF_TURN_SILENCE_MS = 650;
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
  const voiceProtocolSeenRef = useRef(false);
  const interruptedPreviousTurnRef = useRef(false);
  const voicePlaybackGenerationRef = useRef(0);
  const voicePlaybackChainRef = useRef<Promise<void>>(Promise.resolve());
  const seenVoiceSegmentsRef = useRef(new Set<string>());
  const voiceReadyRef = useRef(false);
  const segmentControllersRef = useRef(new Set<AbortController>());
  const sendVoiceTurnRef = useRef<(raw: string) => void>(() => undefined);

  const changePhase = useCallback((next: VoicePhase) => {
    phaseRef.current = next;
    setPhase(next);
  }, []);

  const stopRecognition = useCallback(() => {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
    try { recognitionRef.current?.stop(); } catch { /* already stopped */ }
    recognitionRef.current = null;
  }, []);

  const stopSpeech = useCallback(() => {
    voicePlaybackGenerationRef.current += 1;
    voicePlaybackChainRef.current = Promise.resolve();
    ttsAbortRef.current?.abort();
    ttsPrefetchAbortRef.current?.abort();
    segmentControllersRef.current.forEach((controller) => controller.abort());
    segmentControllersRef.current.clear();
    ttsAbortRef.current = null;
    ttsPrefetchAbortRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }
    if (typeof window !== 'undefined') window.speechSynthesis?.cancel();
  }, []);

  const startRecognition = useCallback(() => {
    if (!activeRef.current || phaseRef.current === 'speaking') return;
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
      finalTranscriptRef.current = finalText;
      const combined = `${finalText} ${interimText}`.trim();
      setLiveTranscript(combined);
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      if (combined) {
        // Browser engines disagree about when an utterance becomes "final".
        // Our own silence endpointing keeps turn-taking fast and works from
        // stable interim text instead of waiting for the browser to decide.
        silenceTimerRef.current = setTimeout(() => {
          sendVoiceTurnRef.current(combined);
        }, END_OF_TURN_SILENCE_MS);
      }
    };
    recognition.onerror = (event) => {
      if (!activeRef.current) return;
      if (event?.error === 'no-speech' || event?.error === 'aborted') return;
      changePhase('error');
    };
    recognition.onend = () => {
      recognitionRef.current = null;
      if (activeRef.current && phaseRef.current === 'listening') {
        window.setTimeout(() => startRecognition(), 120);
      }
    };
    try {
      recognition.start();
      changePhase('listening');
    } catch {
      changePhase('error');
    }
  }, [changePhase, stopRecognition]);

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

  const speakAssistant = useCallback(async (messageId: string, text: string) => {
    const chunks = splitSpeechChunks(text);
    if (!chunks.length || !activeRef.current) return;
    stopRecognition();
    changePhase('speaking');
    speakingStartedAtRef.current = performance.now();
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

  const sendVoiceTurn = useCallback(async (raw: string) => {
    const transcript = raw.trim();
    finalTranscriptRef.current = '';
    setLiveTranscript('');
    if (!transcript || !activeRef.current) return;
    if (isLikelyPlaybackEcho(transcript, lastSpokenTextRef.current)) {
      changePhase('listening');
      return;
    }

    const wasInterrupted = interruptedPreviousTurnRef.current
      || phaseRef.current === 'speaking'
      || useChatStore.getState().isGenerating;
    interruptedPreviousTurnRef.current = false;

    stopSpeech();
    stopRecognition();
    if (useChatStore.getState().isGenerating) interruptGeneration();

    voiceProtocolSeenRef.current = false;
    voiceReadyRef.current = false;
    seenVoiceSegmentsRef.current.clear();
    lastSpokenTextRef.current = '';
    awaitingAssistantRef.current = true;
    const playbackGeneration = voicePlaybackGenerationRef.current;
    changePhase('thinking');

    const rearmAfterQueue = () => {
      const chain = voicePlaybackChainRef.current;
      void chain.finally(() => {
        if (
          activeRef.current
          && voicePlaybackGenerationRef.current === playbackGeneration
          && voiceReadyRef.current
          && phaseRef.current !== 'error'
        ) {
          changePhase('listening');
          startRecognition();
        }
      });
    };

    const onVoiceSegment = (event: VoiceTextSegment) => {
      if (!activeRef.current || voicePlaybackGenerationRef.current !== playbackGeneration) return;
      const key = `${event.messageId}:${event.sequence}`;
      if (seenVoiceSegmentsRef.current.has(key)) return;
      seenVoiceSegmentsRef.current.add(key);
      voiceProtocolSeenRef.current = true;
      awaitingAssistantRef.current = false;
      stopRecognition();
      changePhase('speaking');
      speakingStartedAtRef.current = performance.now();
      lastSpokenMessageIdRef.current = event.messageId;
      lastSpokenTextRef.current = [lastSpokenTextRef.current, event.text].filter(Boolean).join(' ');

      // Start synthesis as soon as the text segment arrives. Playback remains
      // ordered through one promise chain, so later segments can synthesize
      // while the current phrase is already audible.
      const controller = new AbortController();
      segmentControllersRef.current.add(controller);
      const audioPromise = api.tts.synthesizeStream(event.text, {
        language: navigator.language || 'auto',
        speed: 1.02,
        signal: controller.signal,
      });
      const generationAtEnqueue = playbackGeneration;
      voicePlaybackChainRef.current = voicePlaybackChainRef.current.then(async () => {
        if (!activeRef.current || voicePlaybackGenerationRef.current !== generationAtEnqueue) {
          controller.abort();
          return;
        }
        ttsAbortRef.current = controller;
        try {
          await playBlob(await audioPromise);
        } catch {
          if (activeRef.current && voicePlaybackGenerationRef.current === generationAtEnqueue) {
            await browserSpeechFallback(event.text);
          }
        } finally {
          segmentControllersRef.current.delete(controller);
          if (ttsAbortRef.current === controller) ttsAbortRef.current = null;
        }
      });
    };

    const onVoiceReady = (event: VoiceReady) => {
      if (!activeRef.current || voicePlaybackGenerationRef.current !== playbackGeneration) return;
      voiceProtocolSeenRef.current = true;
      awaitingAssistantRef.current = false;
      voiceReadyRef.current = true;

      if (event.speak && seenVoiceSegmentsRef.current.size === 0) {
        // Structured lesson / early-return paths may provide one canonical
        // ready payload instead of token segments. Speak it once.
        stopRecognition();
        changePhase('speaking');
        speakingStartedAtRef.current = performance.now();
        lastSpokenMessageIdRef.current = event.messageId || `voice-${playbackGeneration}`;
        lastSpokenTextRef.current = event.text;
        const controller = new AbortController();
        ttsAbortRef.current = controller;
        void api.tts.synthesizeStream(event.text, {
          language: navigator.language || 'auto',
          speed: 1.02,
          signal: controller.signal,
        }).then(playBlob)
          .catch(() => browserSpeechFallback(event.text))
          .finally(() => {
            if (ttsAbortRef.current === controller) ttsAbortRef.current = null;
            if (activeRef.current && voicePlaybackGenerationRef.current === playbackGeneration) {
              changePhase('listening');
              startRecognition();
            }
          });
        return;
      }

      // Segmented delivery already owns speech. Wait only for the queue to
      // drain; never repeat the final canonical answer.
      rearmAfterQueue();
    };

    const onVoiceIncomplete = (_event: VoiceIncomplete) => {
      if (!activeRef.current || voicePlaybackGenerationRef.current !== playbackGeneration) return;
      voiceProtocolSeenRef.current = true;
      awaitingAssistantRef.current = false;
      voiceReadyRef.current = true;
      stopSpeech();
      changePhase('listening');
      startRecognition();
    };

    await sendMessage(transcript, [], {
      voiceSession: true,
      voiceInterruptedPreviousTurn: wasInterrupted,
      onVoiceSegment,
      onVoiceReady,
      onVoiceIncomplete,
    });
  }, [
    browserSpeechFallback,
    changePhase,
    interruptGeneration,
    playBlob,
    sendMessage,
    startRecognition,
    stopRecognition,
    stopSpeech,
  ]);


  useEffect(() => {
    sendVoiceTurnRef.current = (raw: string) => { void sendVoiceTurn(raw); };
  }, [sendVoiceTurn]);

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
    voiceProtocolSeenRef.current = false;
    voiceReadyRef.current = false;
    interruptedPreviousTurnRef.current = false;
    seenVoiceSegmentsRef.current.clear();
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
    if (
      !active
      || isGenerating
      || !awaitingAssistantRef.current
      || voiceProtocolSeenRef.current
    ) return;
    const latest = latestAssistantMessage();
    if (!latest || latest.id === lastSpokenMessageIdRef.current || !latest.content.trim()) return;
    awaitingAssistantRef.current = false;
    void speakAssistant(latest.id, latest.content);
  }, [active, activeConversationId, isGenerating, speakAssistant]);

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
