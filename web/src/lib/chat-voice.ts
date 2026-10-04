'use client';

import { api } from '@/lib/api';
import { playSpeechResponse } from '@/lib/classroom-audio.mjs';

export type ChatVoicePhase = 'off' | 'listening' | 'thinking' | 'speaking' | 'interrupted' | 'error';

export interface ChatVoiceState {
  active: boolean;
  phase: ChatVoicePhase;
  interimTranscript: string;
  lastTranscript: string;
  error?: string;
}

export interface VoiceTurnMeta {
  locale: string;
  turnId: string;
  interruptedPreviousTurn: boolean;
  handsFree: boolean;
}

type SpeechRecognitionResultLike = {
  0: { transcript: string };
  isFinal?: boolean;
};
type SpeechRecognitionEventLike = {
  resultIndex?: number;
  results: ArrayLike<SpeechRecognitionResultLike>;
};
type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  maxAlternatives?: number;
  start: () => void;
  stop: () => void;
  abort?: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onend: (() => void) | null;
  onerror: ((event?: unknown) => void) | null;
};

function createRecognition(): SpeechRecognitionLike | null {
  if (typeof window === 'undefined') return null;
  const target = window as unknown as Record<string, unknown>;
  const Constructor = (target.SpeechRecognition || target.webkitSpeechRecognition) as
    | (new () => SpeechRecognitionLike)
    | undefined;
  return Constructor ? new Constructor() : null;
}

export function cleanChatTextForSpeech(input: string): string {
  return input
    .replace(/\`\`\`[\s\S]*?\`\`\`/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/【[^】]+】/g, '')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^[-*+]\s+/gm, '')
    .replace(/^\d+\.\s+/gm, '')
    .replace(/[*_~\`>|]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function splitChatSpeech(text: string, maxChars = 430): string[] {
  const clean = cleanChatTextForSpeech(text);
  if (!clean) return [];
  const sentences = clean.match(/[^.!?]+[.!?]+|[^.!?]+$/g) ?? [clean];
  const chunks: string[] = [];
  let current = '';
  for (const raw of sentences) {
    const sentence = raw.trim();
    const next = current ? current + ' ' + sentence : sentence;
    if (next.length <= maxChars) {
      current = next;
      continue;
    }
    if (current) chunks.push(current);
    if (sentence.length <= maxChars) {
      current = sentence;
      continue;
    }
    current = '';
    for (const word of sentence.split(/\s+/)) {
      const candidate = current ? current + ' ' + word : word;
      if (candidate.length > maxChars && current) {
        chunks.push(current);
        current = word;
      } else {
        current = candidate;
      }
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

class ChatVoiceController {
  private state: ChatVoiceState = {
    active: false,
    phase: 'off',
    interimTranscript: '',
    lastTranscript: '',
  };
  private listeners = new Set<(state: ChatVoiceState) => void>();
  private recognition: SpeechRecognitionLike | null = null;
  private sendTurn: ((text: string, meta: VoiceTurnMeta) => Promise<void>) | null = null;
  private cancelTurn: (() => void) | null = null;
  private speechAbort: AbortController | null = null;
  private speechQueue: string[] = [];
  private speaking = false;
  private assistantTurnFinished = false;
  private interruptedPreviousTurn = false;
  private locale = 'auto';
  private recognitionGeneration = 0;
  private microphoneStream: MediaStream | null = null;
  private audioContext: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private vadFrame = 0;
  private vadHotSince: number | null = null;
  private speakingStartedAt = 0;

  subscribe(listener: (state: ChatVoiceState) => void) {
    this.listeners.add(listener);
    listener(this.state);
    return () => this.listeners.delete(listener);
  }

  snapshot() { return this.state; }

  supported() { return createRecognition() !== null; }

  async activate(options: {
    sendTurn: (text: string, meta: VoiceTurnMeta) => Promise<void>;
    cancelTurn: () => void;
    locale?: string;
  }) {
    if (!this.supported()) {
      this.patch({ phase: 'error', error: 'Conversational voice is not supported by this browser.' });
      return false;
    }
    this.sendTurn = options.sendTurn;
    this.cancelTurn = options.cancelTurn;
    this.locale = options.locale || navigator.language || 'auto';
    this.patch({ active: true, phase: 'listening', error: undefined });
    await this.startVad();
    this.startListening();
    return true;
  }

  deactivate() {
    this.stopRecognition();
    this.stopSpeech();
    this.stopVad();
    this.speechQueue = [];
    this.sendTurn = null;
    this.cancelTurn = null;
    this.assistantTurnFinished = false;
    this.interruptedPreviousTurn = false;
    this.patch({ active: false, phase: 'off', interimTranscript: '', error: undefined });
  }

  interruptAndListen() {
    if (!this.state.active) return;
    const hadFloor = this.state.phase === 'speaking' || this.state.phase === 'thinking';
    if (hadFloor) {
      this.interruptedPreviousTurn = true;
      this.cancelTurn?.();
    }
    this.stopSpeech();
    this.speechQueue = [];
    this.assistantTurnFinished = false;
    this.patch({ phase: 'interrupted' });
    queueMicrotask(() => this.startListening());
  }

  markThinking() {
    if (!this.state.active) return;
    this.stopRecognition();
    this.patch({ phase: 'thinking', interimTranscript: '' });
  }

  enqueueAssistantText(text: string) {
    if (!this.state.active) return;
    const chunks = splitChatSpeech(text);
    if (!chunks.length) return;
    this.speechQueue.push(...chunks);
    void this.drainSpeechQueue();
  }

  finishAssistantTurn() {
    if (!this.state.active) return;
    this.assistantTurnFinished = true;
    if (!this.speaking && this.speechQueue.length === 0) this.resumeHandsFree();
  }

  failAssistantTurn(message = 'Lyo could not finish that spoken turn.') {
    if (!this.state.active) return;
    this.stopSpeech();
    this.speechQueue = [];
    this.patch({ phase: 'error', error: message });
    window.setTimeout(() => {
      if (this.state.active) this.startListening();
    }, 700);
  }

  private patch(patch: Partial<ChatVoiceState>) {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener(this.state);
  }

  private startListening() {
    if (!this.state.active || this.state.phase === 'speaking') return;
    this.stopRecognition();
    const recognition = createRecognition();
    if (!recognition) {
      this.patch({ phase: 'error', error: 'Speech recognition is unavailable.' });
      return;
    }

    const generation = ++this.recognitionGeneration;
    this.recognition = recognition;
    let finalText = '';
    recognition.lang = this.locale === 'auto' ? navigator.language || 'en-US' : this.locale;
    recognition.interimResults = true;
    recognition.continuous = false;
    recognition.maxAlternatives = 1;

    recognition.onresult = (event) => {
      if (generation !== this.recognitionGeneration || !this.state.active) return;
      let interim = '';
      for (let i = event.resultIndex ?? 0; i < event.results.length; i++) {
        const result = event.results[i];
        const transcript = result?.[0]?.transcript?.trim() || '';
        if (!transcript) continue;
        if (result.isFinal) finalText = (finalText + ' ' + transcript).trim();
        else interim = (interim + ' ' + transcript).trim();
      }
      this.patch({ phase: 'listening', interimTranscript: interim || finalText });
    };

    recognition.onerror = () => {
      if (generation !== this.recognitionGeneration || !this.state.active) return;
      this.patch({ phase: 'error', error: 'I could not hear that clearly.' });
    };

    recognition.onend = () => {
      if (generation !== this.recognitionGeneration || !this.state.active) return;
      this.recognition = null;
      const transcript = finalText.trim() || this.state.interimTranscript.trim();
      if (!transcript) {
        window.setTimeout(() => {
          if (this.state.active && this.state.phase !== 'speaking' && this.state.phase !== 'thinking') {
            this.startListening();
          }
        }, 250);
        return;
      }
      this.patch({
        phase: 'thinking',
        lastTranscript: transcript,
        interimTranscript: '',
        error: undefined,
      });
      const interrupted = this.interruptedPreviousTurn;
      this.interruptedPreviousTurn = false;
      const send = this.sendTurn;
      if (!send) return;
      void send(transcript, {
        locale: this.locale,
        turnId: crypto.randomUUID(),
        interruptedPreviousTurn: interrupted,
        handsFree: true,
      }).catch(() => this.failAssistantTurn('That voice turn could not be sent.'));
    };

    try {
      recognition.start();
      this.patch({ phase: 'listening', interimTranscript: '', error: undefined });
    } catch {
      this.patch({ phase: 'error', error: 'Microphone access is unavailable.' });
    }
  }

  private stopRecognition() {
    this.recognitionGeneration += 1;
    const recognition = this.recognition;
    this.recognition = null;
    if (!recognition) return;
    try { recognition.onend = null; recognition.onresult = null; recognition.onerror = null; } catch {}
    try { recognition.abort?.(); } catch {}
    try { recognition.stop(); } catch {}
  }

  private async drainSpeechQueue() {
    if (this.speaking || !this.state.active) return;
    this.speaking = true;
    try {
      while (this.state.active && this.speechQueue.length > 0) {
        const next = this.speechQueue.shift();
        if (!next) continue;
        const controller = new AbortController();
        this.speechAbort = controller;
        this.speakingStartedAt = performance.now();
        this.patch({ phase: 'speaking', error: undefined });
        try {
          await playSpeechResponse(
            api.tts.stream(next, {
              language: this.locale,
              speed: 1.0,
              signal: controller.signal,
            }),
            { signal: controller.signal, startupTimeoutMs: 7000 },
          );
        } catch (error) {
          if (controller.signal.aborted || !this.state.active) break;
          const playbackStarted = Boolean((error as { playbackStarted?: boolean })?.playbackStarted);
          if (!playbackStarted) await this.deviceSpeechFallback(next, controller.signal);
        } finally {
          if (this.speechAbort === controller) this.speechAbort = null;
          controller.abort();
        }
      }
    } finally {
      this.speaking = false;
      if (this.state.active && this.assistantTurnFinished && this.speechQueue.length === 0) {
        this.resumeHandsFree();
      }
    }
  }

  private stopSpeech() {
    this.speechAbort?.abort();
    this.speechAbort = null;
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) window.speechSynthesis.cancel();
    this.speaking = false;
  }

  private async deviceSpeechFallback(text: string, signal: AbortSignal) {
    if (!('speechSynthesis' in window) || signal.aborted) return;
    await new Promise<void>((resolve) => {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = this.locale === 'auto' ? navigator.language || 'en-US' : this.locale;
      utterance.rate = 1.0;
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        signal.removeEventListener('abort', cancel);
        resolve();
      };
      const cancel = () => {
        window.speechSynthesis.cancel();
        finish();
      };
      utterance.onend = finish;
      utterance.onerror = finish;
      signal.addEventListener('abort', cancel, { once: true });
      window.speechSynthesis.speak(utterance);
    });
  }

  private resumeHandsFree() {
    if (!this.state.active) return;
    this.assistantTurnFinished = false;
    window.setTimeout(() => {
      if (this.state.active && !this.speaking) this.startListening();
    }, 180);
  }

  private async startVad() {
    if (!navigator.mediaDevices?.getUserMedia || this.microphoneStream) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
      if (!this.state.active) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }
      this.microphoneStream = stream;
      const candidate = window as unknown as { webkitAudioContext?: typeof AudioContext };
      const Context = window.AudioContext || candidate.webkitAudioContext;
      if (!Context) return;
      const context = new Context();
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.35;
      source.connect(analyser);
      this.audioContext = context;
      this.analyser = analyser;
      this.monitorVad();
    } catch {
      // SpeechRecognition can still provide push-to-interrupt voice without VAD.
    }
  }

  private monitorVad() {
    if (!this.state.active || !this.analyser) return;
    const data = new Uint8Array(this.analyser.fftSize);
    this.analyser.getByteTimeDomainData(data);
    let sum = 0;
    for (const sample of data) {
      const normalized = (sample - 128) / 128;
      sum += normalized * normalized;
    }
    const rms = Math.sqrt(sum / data.length);
    const now = performance.now();

    if (this.state.phase === 'speaking' && now - this.speakingStartedAt > 650 && rms > 0.075) {
      if (this.vadHotSince == null) this.vadHotSince = now;
      if (now - this.vadHotSince > 260) {
        this.vadHotSince = null;
        this.interruptAndListen();
      }
    } else {
      this.vadHotSince = null;
    }
    this.vadFrame = requestAnimationFrame(() => this.monitorVad());
  }

  private stopVad() {
    if (this.vadFrame) cancelAnimationFrame(this.vadFrame);
    this.vadFrame = 0;
    this.vadHotSince = null;
    this.analyser?.disconnect();
    this.analyser = null;
    if (this.audioContext) void this.audioContext.close().catch(() => {});
    this.audioContext = null;
    this.microphoneStream?.getTracks().forEach((track) => track.stop());
    this.microphoneStream = null;
  }
}

export const chatVoiceController = new ChatVoiceController();
