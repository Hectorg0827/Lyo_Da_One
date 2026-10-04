'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '@/lib/api';
import { playSpeechResponse } from '@/lib/classroom-audio.mjs';
import {
  createBrowserSpeechRecognition,
  type BrowserSpeechRecognition,
  type BrowserSpeechRecognitionEvent,
} from '@/lib/browser-speech';
import { useChatStore } from '@/stores/chat-store';
import type { ChatMessage } from '@/types';

export type ChatVoiceStatus = 'off' | 'listening' | 'thinking' | 'speaking' | 'error';

interface Options {
  onTranscript: (text: string) => void;
  onFinalUtterance: (text: string) => Promise<void>;
}

function latestAssistant(messages: ChatMessage[]): ChatMessage | undefined {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (messages[i].role === 'assistant') return messages[i];
  }
  return undefined;
}

export function speechTextForMessage(message?: ChatMessage): string {
  if (!message) return '';
  let text = message.content.trim();
  if (!text && message.blocks) {
    text = message.blocks
      .filter((block) => !(block.type === 'interactive' && block.subtype === 'sourceNavigator'))
      .map((block) => {
        const content = (block.content || {}) as Record<string, unknown>;
        return String(content.text || content.question || content.title || content.front || '');
      })
      .filter(Boolean)
      .join(' ');
  }
  return text
    .replace(/\u3010[^\u3011]+\u3011/g, '')
    .replace(/!\[[^\]]*\]\([^)]+\)/g, ' Image shown on screen. ')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/#{1,6}\s*/g, '')
    .replace(/[*_#>|]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function splitSpeechChunks(text: string, maxChars = 900): string[] {
  const sentences = text.trim().match(/[^.!?]+[.!?]+|[^.!?]+$/g) || [];
  const chunks: string[] = [];
  let current = '';
  for (const raw of sentences) {
    const sentence = raw.trim();
    const joined = current ? current + ' ' + sentence : sentence;
    if (joined.length <= maxChars) {
      current = joined;
    } else {
      if (current) chunks.push(current);
      current = sentence;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

function browserSpeak(text: string, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (!('speechSynthesis' in window)) {
      reject(new Error('Browser speech unavailable'));
      return;
    }
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = navigator.language || 'en-US';
    utterance.rate = 0.98;
    const abort = () => {
      window.speechSynthesis.cancel();
      reject(new DOMException('Interrupted', 'AbortError'));
    };
    signal.addEventListener('abort', abort, { once: true });
    utterance.onend = () => {
      signal.removeEventListener('abort', abort);
      resolve();
    };
    utterance.onerror = () => {
      signal.removeEventListener('abort', abort);
      reject(new Error('Browser speech failed'));
    };
    window.speechSynthesis.speak(utterance);
  });
}

/**
 * Voice is a presentation layer over canonical Chat:
 * microphone -> STT -> same Chat turn (response_channel=voice) -> same
 * InteractionContract/memory/tools -> same answer -> TTS.
 */
export function useChatVoiceSession({ onTranscript, onFinalUtterance }: Options) {
  const isGenerating = useChatStore((state) => state.isGenerating);
  const activeConversationId = useChatStore((state) => state.activeConversationId);
  const conversations = useChatStore((state) => state.conversations);
  const cancelActiveResponse = useChatStore((state) => state.cancelActiveResponse);

  const [status, setStatus] = useState<ChatVoiceStatus>('off');
  const [supported, setSupported] = useState(false);

  const activeRef = useRef(false);
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const speechAbortRef = useRef<AbortController | null>(null);
  const awaitingRef = useRef(false);
  const submittingRef = useRef(false);
  const baselineAssistantRef = useRef<string | null>(null);
  const transcriptCallbackRef = useRef(onTranscript);
  const submitCallbackRef = useRef(onFinalUtterance);

  useEffect(() => { transcriptCallbackRef.current = onTranscript; }, [onTranscript]);
  useEffect(() => { submitCallbackRef.current = onFinalUtterance; }, [onFinalUtterance]);

  const stopRecognition = useCallback((abort = false) => {
    const recognition = recognitionRef.current;
    recognitionRef.current = null;
    if (!recognition) return;
    recognition.onresult = null;
    recognition.onend = null;
    recognition.onerror = null;
    try {
      if (abort && recognition.abort) recognition.abort();
      else recognition.stop();
    } catch {}
  }, []);

  const stopSpeech = useCallback(() => {
    speechAbortRef.current?.abort();
    speechAbortRef.current = null;
    if ('speechSynthesis' in window) window.speechSynthesis.cancel();
  }, []);

  const listen = useCallback(() => {
    if (!activeRef.current) return;
    stopSpeech();
    stopRecognition(true);
    const recognition = createBrowserSpeechRecognition();
    if (!recognition) {
      activeRef.current = false;
      setStatus('error');
      return;
    }
    recognitionRef.current = recognition;
    recognition.lang = navigator.language || 'en-US';
    recognition.interimResults = true;
    recognition.continuous = true;
    let finalText = '';

    recognition.onstart = () => {
      setStatus('listening');
      transcriptCallbackRef.current('');
    };
    recognition.onresult = (event: BrowserSpeechRecognitionEvent) => {
      let interim = '';
      let completed = '';
      for (let i = event.resultIndex || 0; i < event.results.length; i += 1) {
        const result = event.results[i];
        const piece = result?.[0]?.transcript?.trim() || '';
        if (!piece) continue;
        if (result.isFinal) completed += (completed ? ' ' : '') + piece;
        else interim += (interim ? ' ' : '') + piece;
      }
      if (completed) finalText = (finalText + ' ' + completed).trim();
      transcriptCallbackRef.current([finalText, interim].filter(Boolean).join(' ').trim());

      if (completed && !submittingRef.current) {
        submittingRef.current = true;
        stopRecognition();
        const state = useChatStore.getState();
        const conversation = state.conversations.find(
          (item) => item.id === state.activeConversationId
        );
        baselineAssistantRef.current = latestAssistant(conversation?.messages || [])?.id || null;
        awaitingRef.current = true;
        setStatus('thinking');
        void submitCallbackRef.current(finalText).finally(() => {
          submittingRef.current = false;
        });
      }
    };
    recognition.onerror = (event) => {
      const benign = event?.error === 'aborted' || event?.error === 'no-speech';
      if (benign && activeRef.current && !awaitingRef.current) {
        window.setTimeout(listen, 180);
      } else if (!benign) {
        setStatus('error');
      }
    };
    recognition.onend = () => {
      recognitionRef.current = null;
      if (activeRef.current && !awaitingRef.current && !submittingRef.current) {
        window.setTimeout(listen, 180);
      }
    };
    try {
      recognition.start();
    } catch {
      setStatus('error');
    }
  }, [stopRecognition, stopSpeech]);

  const speak = useCallback(async (text: string) => {
    const chunks = splitSpeechChunks(text);
    if (!chunks.length) {
      listen();
      return;
    }
    setStatus('speaking');
    stopRecognition(true);
    const controller = new AbortController();
    speechAbortRef.current = controller;

    try {
      for (const chunk of chunks) {
        try {
          await playSpeechResponse(
            api.tts.stream(chunk, {
              language: navigator.language || 'auto',
              signal: controller.signal,
            }),
            { signal: controller.signal, startupTimeoutMs: 6000 }
          );
        } catch (error) {
          if (controller.signal.aborted) throw error;
          const started = Boolean((error as { playbackStarted?: boolean }).playbackStarted);
          if (!started) await browserSpeak(chunk, controller.signal);
        }
      }
    } catch (error) {
      if ((error as Error)?.name !== 'AbortError') setStatus('error');
    } finally {
      if (speechAbortRef.current === controller) speechAbortRef.current = null;
      if (activeRef.current && !controller.signal.aborted) listen();
    }
  }, [listen, stopRecognition]);

  useEffect(() => {
    if (!activeRef.current || !awaitingRef.current || isGenerating) return;
    const conversation = conversations.find((item) => item.id === activeConversationId);
    const assistant = latestAssistant(conversation?.messages || []);
    if (!assistant || assistant.id === baselineAssistantRef.current) return;
    awaitingRef.current = false;
    baselineAssistantRef.current = assistant.id;
    transcriptCallbackRef.current('');
    const spoken = speechTextForMessage(assistant);
    if (spoken) void speak(spoken);
    else listen();
  }, [activeConversationId, conversations, isGenerating, listen, speak]);

  const start = useCallback(() => {
    if (!supported) return;
    activeRef.current = true;
    awaitingRef.current = false;
    listen();
  }, [listen, supported]);

  const stop = useCallback(() => {
    activeRef.current = false;
    awaitingRef.current = false;
    submittingRef.current = false;
    stopRecognition(true);
    stopSpeech();
    transcriptCallbackRef.current('');
    setStatus('off');
  }, [stopRecognition, stopSpeech]);

  const bargeIn = useCallback(() => {
    if (!activeRef.current) {
      start();
      return;
    }
    stopSpeech();
    if (isGenerating) cancelActiveResponse();
    awaitingRef.current = false;
    submittingRef.current = false;
    listen();
  }, [cancelActiveResponse, isGenerating, listen, start, stopSpeech]);

  useEffect(() => {
    setSupported(createBrowserSpeechRecognition() !== null);
    return () => {
      activeRef.current = false;
      stopRecognition(true);
      stopSpeech();
    };
  }, [stopRecognition, stopSpeech]);

  return { status, supported, active: status !== 'off', start, stop, bargeIn };
}
