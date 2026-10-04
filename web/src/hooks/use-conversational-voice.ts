'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';
import {
  createBrowserSpeechRecognition,
  type BrowserSpeechRecognition,
  type BrowserSpeechRecognitionEvent,
} from '@/lib/browser-speech';
import { useChatStore } from '@/stores/chat-store';

export type ConversationalVoicePhase =
  | 'idle'
  | 'listening'
  | 'thinking'
  | 'speaking';

type VoiceMetadata = {
  voiceTurn?: { id?: unknown; phase?: unknown };
  voiceSegments?: unknown;
  voiceLanguage?: unknown;
};

const SILENCE_COMMIT_MS = 650;
const MIN_UTTERANCE_CHARS = 2;

function latestAssistantVoiceMetadata(): VoiceMetadata | null {
  const state = useChatStore.getState();
  const conversation = state.getActiveConversation();
  if (!conversation) return null;
  const assistant = [...conversation.messages].reverse().find((message) => message.role === 'assistant');
  return (assistant?.metadata as VoiceMetadata | undefined) ?? null;
}

async function playStreamingResponse(
  response: Response,
  audio: HTMLAudioElement,
  signal: AbortSignal
): Promise<void> {
  if (!response.body) throw new Error('Speech response has no audio body');

  const canUseMediaSource =
    typeof window !== 'undefined'
    && 'MediaSource' in window
    && typeof MediaSource.isTypeSupported === 'function'
    && MediaSource.isTypeSupported('audio/mpeg');

  if (!canUseMediaSource) {
    const blob = await response.blob();
    if (signal.aborted) throw new DOMException('Aborted', 'AbortError');
    const url = URL.createObjectURL(blob);
    try {
      audio.src = url;
      await audio.play();
      await new Promise<void>((resolve, reject) => {
        const onEnded = () => { cleanup(); resolve(); };
        const onError = () => { cleanup(); reject(new Error('Audio playback failed')); };
        const onAbort = () => { cleanup(); reject(new DOMException('Aborted', 'AbortError')); };
        const cleanup = () => {
          audio.removeEventListener('ended', onEnded);
          audio.removeEventListener('error', onError);
          signal.removeEventListener('abort', onAbort);
        };
        audio.addEventListener('ended', onEnded, { once: true });
        audio.addEventListener('error', onError, { once: true });
        signal.addEventListener('abort', onAbort, { once: true });
      });
    } finally {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
      URL.revokeObjectURL(url);
    }
    return;
  }

  const mediaSource = new MediaSource();
  const url = URL.createObjectURL(mediaSource);
  const reader = response.body.getReader();
  audio.src = url;

  try {
    await new Promise<void>((resolve, reject) => {
      const onOpen = async () => {
        try {
          const sourceBuffer = mediaSource.addSourceBuffer('audio/mpeg');
          const append = (chunk: ArrayBuffer) =>
            new Promise<void>((resolveAppend, rejectAppend) => {
              const onUpdate = () => { cleanup(); resolveAppend(); };
              const onError = () => { cleanup(); rejectAppend(new Error('Audio buffer failed')); };
              const cleanup = () => {
                sourceBuffer.removeEventListener('updateend', onUpdate);
                sourceBuffer.removeEventListener('error', onError);
              };
              sourceBuffer.addEventListener('updateend', onUpdate, { once: true });
              sourceBuffer.addEventListener('error', onError, { once: true });
              sourceBuffer.appendBuffer(chunk);
            });

          // Start playback as soon as the first provider bytes are buffered.
          let started = false;
          while (true) {
            if (signal.aborted) throw new DOMException('Aborted', 'AbortError');
            const { done, value } = await reader.read();
            if (done) break;
            if (!value?.byteLength) continue;
            const chunk = value.buffer.slice(
              value.byteOffset,
              value.byteOffset + value.byteLength
            ) as ArrayBuffer;
            await append(chunk);
            if (!started) {
              started = true;
              await audio.play();
            }
          }
          if (mediaSource.readyState === 'open') mediaSource.endOfStream();
          resolve();
        } catch (error) {
          reject(error);
        }
      };
      mediaSource.addEventListener('sourceopen', onOpen, { once: true });
      signal.addEventListener(
        'abort',
        () => reject(new DOMException('Aborted', 'AbortError')),
        { once: true }
      );
    });

    if (!signal.aborted) {
      await new Promise<void>((resolve) => {
        if (audio.ended) return resolve();
        audio.addEventListener('ended', () => resolve(), { once: true });
      });
    }
  } finally {
    reader.cancel().catch(() => undefined);
    audio.pause();
    audio.removeAttribute('src');
    audio.load();
    URL.revokeObjectURL(url);
  }
}

export function useConversationalVoice() {
  const sendMessage = useChatStore((state) => state.sendMessage);
  const interruptActiveResponse = useChatStore((state) => state.interruptActiveResponse);
  const isGenerating = useChatStore((state) => state.isGenerating);
  const conversations = useChatStore((state) => state.conversations);
  const activeConversationId = useChatStore((state) => state.activeConversationId);

  const [active, setActive] = useState(false);
  const [phase, setPhase] = useState<ConversationalVoicePhase>('idle');
  const [partialTranscript, setPartialTranscript] = useState('');
  const [supported, setSupported] = useState(false);

  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const finalTranscriptRef = useRef('');
  const interimTranscriptRef = useRef('');
  const currentVoiceTurnRef = useRef<string | null>(null);
  const playedVoiceTurnRef = useRef<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const speechAbortRef = useRef<AbortController | null>(null);
  const shouldListenAfterSpeechRef = useRef(false);
  const phaseRef = useRef<ConversationalVoicePhase>('idle');
  const activeRef = useRef(false);

  useEffect(() => { phaseRef.current = phase; }, [phase]);
  useEffect(() => { activeRef.current = active; }, [active]);

  const clearSilenceTimer = useCallback(() => {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
  }, []);

  const stopAudio = useCallback(() => {
    speechAbortRef.current?.abort();
    speechAbortRef.current = null;
    const audio = audioRef.current;
    if (audio) {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
    }
  }, []);

  const stopRecognition = useCallback((abort = false) => {
    clearSilenceTimer();
    const recognition = recognitionRef.current;
    recognitionRef.current = null;
    if (!recognition) return;
    try {
      if (abort && recognition.abort) recognition.abort();
      else recognition.stop();
    } catch {
      // Browser recognizers throw when stop races their natural onend.
    }
  }, [clearSilenceTimer]);

  const startListening = useCallback(() => {
    if (!activeRef.current) return;
    stopRecognition(true);

    const recognition = createBrowserSpeechRecognition();
    if (!recognition) {
      setSupported(false);
      setActive(false);
      setPhase('idle');
      return;
    }

    recognitionRef.current = recognition;
    finalTranscriptRef.current = '';
    interimTranscriptRef.current = '';
    setPartialTranscript('');

    recognition.lang = navigator.language || 'en-US';
    recognition.interimResults = true;
    // One utterance at a time is substantially more reliable across browsers;
    // the controller restarts immediately after each spoken Lyo turn.
    recognition.continuous = false;

    recognition.onspeechstart = () => {
      // Barge-in: speech has priority over output. Stop audio immediately and
      // cancel the canonical chat stream only when it is still generating.
      if (phaseRef.current === 'speaking') stopAudio();
      if (useChatStore.getState().isGenerating) interruptActiveResponse();
      setPhase('listening');
    };

    const scheduleCommit = () => {
      clearSilenceTimer();
      silenceTimerRef.current = setTimeout(() => {
        const transcript = (finalTranscriptRef.current || interimTranscriptRef.current).trim();
        if (transcript.length < MIN_UTTERANCE_CHARS || !activeRef.current) return;
        stopRecognition(false);
        setPartialTranscript('');
        const voiceTurnId = crypto.randomUUID();
        currentVoiceTurnRef.current = voiceTurnId;
        setPhase('thinking');
        void sendMessage(transcript, [], {
          deliveryMode: 'voice',
          voiceTurnId,
        });
      }, SILENCE_COMMIT_MS);
    };

    recognition.onresult = (event: BrowserSpeechRecognitionEvent) => {
      let finalText = '';
      let interimText = '';
      for (let index = 0; index < event.results.length; index += 1) {
        const result = event.results[index];
        const text = result?.[0]?.transcript ?? '';
        if (result?.isFinal) finalText += text;
        else interimText += text;
      }
      if (finalText.trim()) finalTranscriptRef.current = finalText.trim();
      interimTranscriptRef.current = interimText.trim();
      const transcript = (finalText || interimText).trim();
      setPartialTranscript(transcript);
      if (transcript.length >= MIN_UTTERANCE_CHARS) scheduleCommit();
    };

    recognition.onerror = () => {
      clearSilenceTimer();
      if (activeRef.current && phaseRef.current === 'listening') {
        // Recover from transient recognition failures without ending the
        // voice conversation.
        window.setTimeout(() => startListening(), 250);
      }
    };
    recognition.onend = () => {
      recognitionRef.current = null;
      if (
        activeRef.current
        && phaseRef.current === 'listening'
        && !silenceTimerRef.current
        && !useChatStore.getState().isGenerating
      ) {
        window.setTimeout(() => startListening(), 150);
      }
    };

    try {
      recognition.start();
      setPhase('listening');
    } catch {
      setActive(false);
      setPhase('idle');
    }
  }, [clearSilenceTimer, interruptActiveResponse, sendMessage, stopAudio, stopRecognition]);

  const playSegments = useCallback(async (
    segments: string[],
    language: string,
    voiceTurnId: string
  ) => {
    if (!segments.length || !activeRef.current) return;
    stopRecognition(true);
    stopAudio();
    setPhase('speaking');
    shouldListenAfterSpeechRef.current = true;

    const audio = audioRef.current ?? new Audio();
    audioRef.current = audio;
    const abort = new AbortController();
    speechAbortRef.current = abort;

    try {
      for (const segment of segments) {
        if (abort.signal.aborted || !activeRef.current) break;
        const response = await api.tts.streamSpeech(segment, {
          language,
          signal: abort.signal,
        });
        await playStreamingResponse(response, audio, abort.signal);
      }
    } catch (error) {
      if ((error as Error)?.name !== 'AbortError') {
        // Voice is progressive enhancement; the canonical text answer remains.
      }
    } finally {
      if (speechAbortRef.current === abort) speechAbortRef.current = null;
      if (
        activeRef.current
        && shouldListenAfterSpeechRef.current
        && currentVoiceTurnRef.current === voiceTurnId
      ) {
        setPhase('listening');
        window.setTimeout(() => startListening(), 120);
      }
    }
  }, [startListening, stopAudio, stopRecognition]);

  const latestVoice = useMemo(() => {
    const conversation = conversations.find((item) => item.id === activeConversationId);
    const assistant = conversation
      ? [...conversation.messages].reverse().find((message) => message.role === 'assistant')
      : undefined;
    const metadata = (assistant?.metadata as VoiceMetadata | undefined) ?? {};
    const turn = metadata.voiceTurn as { id?: unknown; phase?: unknown } | undefined;
    const id = typeof turn?.id === 'string' ? turn.id : null;
    const segments = Array.isArray(metadata.voiceSegments)
      ? metadata.voiceSegments.filter((item): item is string => typeof item === 'string' && item.trim().length > 0)
      : [];
    const language = typeof metadata.voiceLanguage === 'string' ? metadata.voiceLanguage : 'auto';
    return { id, segments, language };
  }, [activeConversationId, conversations]);

  useEffect(() => {
    if (!active || !latestVoice.id || latestVoice.segments.length === 0) return;
    if (latestVoice.id !== currentVoiceTurnRef.current) return;
    if (playedVoiceTurnRef.current === latestVoice.id) return;
    playedVoiceTurnRef.current = latestVoice.id;
    void playSegments(latestVoice.segments, latestVoice.language, latestVoice.id);
  }, [active, latestVoice, playSegments]);

  useEffect(() => {
    if (!active) return;
    if (isGenerating && phaseRef.current !== 'speaking') setPhase('thinking');
  }, [active, isGenerating]);

  useEffect(() => {
    setSupported(createBrowserSpeechRecognition() !== null);
    return () => {
      activeRef.current = false;
      stopRecognition(true);
      stopAudio();
    };
  }, [stopAudio, stopRecognition]);

  const start = useCallback(() => {
    if (!supported) return;
    activeRef.current = true;
    setActive(true);
    shouldListenAfterSpeechRef.current = true;
    startListening();
  }, [startListening, supported]);

  const stop = useCallback(() => {
    activeRef.current = false;
    shouldListenAfterSpeechRef.current = false;
    setActive(false);
    setPhase('idle');
    setPartialTranscript('');
    stopRecognition(true);
    stopAudio();
    if (useChatStore.getState().isGenerating) interruptActiveResponse();
  }, [interruptActiveResponse, stopAudio, stopRecognition]);

  const toggle = useCallback(() => {
    if (activeRef.current) stop();
    else start();
  }, [start, stop]);

  return {
    active,
    supported,
    phase,
    partialTranscript,
    start,
    stop,
    toggle,
    interrupt: () => {
      stopAudio();
      if (useChatStore.getState().isGenerating) interruptActiveResponse();
      if (activeRef.current) startListening();
    },
  };
}
