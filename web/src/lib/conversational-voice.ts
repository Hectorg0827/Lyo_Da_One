export type SpeechRecognitionResultLike = {
  isFinal?: boolean;
  [index: number]: { transcript: string };
};

export type SpeechRecognitionEventLike = {
  resultIndex?: number;
  results: ArrayLike<SpeechRecognitionResultLike>;
};

export type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  start: () => void;
  stop: () => void;
  abort?: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onend: (() => void) | null;
  onerror: ((event?: { error?: string }) => void) | null;
};

export function createSpeechRecognition(): SpeechRecognitionLike | null {
  if (typeof window === 'undefined') return null;
  const w = window as unknown as Record<string, unknown>;
  const Ctor = (w.SpeechRecognition || w.webkitSpeechRecognition) as
    | (new () => SpeechRecognitionLike)
    | undefined;
  return Ctor ? new Ctor() : null;
}

export function normalizeForEchoCheck(text: string): string {
  return text
    .toLocaleLowerCase()
    .replace(/[^A-Za-z0-9À-ɏ\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function isLikelyPlaybackEcho(heard: string, spoken: string): boolean {
  const a = normalizeForEchoCheck(heard);
  const b = normalizeForEchoCheck(spoken);
  if (!a || !b) return false;
  if (a.length >= 12 && b.includes(a)) return true;
  if (b.length >= 12 && a.includes(b)) return true;
  const aWords = new Set(a.split(' '));
  const bWords = new Set(b.split(' '));
  let overlap = 0;
  aWords.forEach((word) => { if (bWords.has(word)) overlap += 1; });
  return overlap / Math.max(1, Math.min(aWords.size, bWords.size)) >= 0.82;
}

export function stripForSpeech(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/#{1,6}\s*/g, '')
    .replace(/^\s*[-*+]\s+/gm, '')
    .replace(/^\s*\d+[.)]\s+/gm, '')
    .replace(/\|/g, ', ')
    .replace(/[*_~>]/g, '')
    .replace(/【[^】]+】/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const SHORT_COMPLETE_UTTERANCE_RE = /^(?:yes|yeah|yep|no|nope|okay|ok|sure|right|thanks|thank you|got it|exactly|correct|sí|si|no|vale|gracias)$/i;
const INCOMPLETE_ENDING_RE = /(?:[,;:]|\.\.\.)\s*$/;
const OPEN_ENDED_LAST_WORD_RE = /\b(?:and|but|or|because|so|if|when|while|that|to|with|for|from|about|y|pero|porque|si|cuando|con|para|de)\s*$/i;

/**
 * Semantic endpointing for conversational voice.
 *
 * A fixed silence timeout feels either sluggish after a complete sentence or
 * too aggressive in the middle of a thought. This bounded heuristic adapts
 * only the transport timing; it never changes the canonical Chat intent.
 */
export function voiceEndOfTurnDelayMs(text: string): number {
  const normalized = text.trim();
  if (!normalized) return 900;
  if (SHORT_COMPLETE_UTTERANCE_RE.test(normalized)) return 420;
  if (/[.!?]\s*$/.test(normalized)) return 430;
  if (INCOMPLETE_ENDING_RE.test(normalized) || OPEN_ENDED_LAST_WORD_RE.test(normalized)) {
    return 1100;
  }
  const words = normalized.split(/\s+/).filter(Boolean).length;
  if (words <= 2) return 900;
  if (words <= 5) return 700;
  return 620;
}

export function splitSpeechChunks(text: string, maxChars = 260): string[] {
  const spoken = stripForSpeech(text);
  if (!spoken) return [];
  const sentences = spoken.match(/[^.!?]+[.!?]+|[^.!?]+$/g) ?? [spoken];
  const chunks: string[] = [];
  let current = '';
  for (const sentenceRaw of sentences) {
    const sentence = sentenceRaw.trim();
    if (!sentence) continue;
    if (!current) {
      current = sentence;
      continue;
    }
    if ((current + ' ' + sentence).length <= maxChars) {
      current += ' ' + sentence;
    } else {
      chunks.push(current);
      current = sentence;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}


export function supportsProgressiveMp3Playback(): boolean {
  return (
    typeof window !== 'undefined'
    && typeof MediaSource !== 'undefined'
    && typeof MediaSource.isTypeSupported === 'function'
    && MediaSource.isTypeSupported('audio/mpeg')
  );
}

function voiceAbortError(): Error {
  if (typeof DOMException !== 'undefined') {
    return new DOMException('Voice playback aborted', 'AbortError');
  }
  const error = new Error('Voice playback aborted');
  error.name = 'AbortError';
  return error;
}

function waitForMediaSourceOpen(
  mediaSource: MediaSource,
  signal?: AbortSignal,
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(voiceAbortError());
      return;
    }
    const cleanup = () => {
      mediaSource.removeEventListener('sourceopen', onOpen);
      signal?.removeEventListener('abort', onAbort);
    };
    const onOpen = () => {
      cleanup();
      resolve();
    };
    const onAbort = () => {
      cleanup();
      reject(voiceAbortError());
    };
    mediaSource.addEventListener('sourceopen', onOpen, { once: true });
    signal?.addEventListener('abort', onAbort, { once: true });
  });
}

function appendMediaChunk(
  sourceBuffer: SourceBuffer,
  chunk: Uint8Array,
  signal?: AbortSignal,
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(voiceAbortError());
      return;
    }
    const cleanup = () => {
      sourceBuffer.removeEventListener('updateend', onDone);
      sourceBuffer.removeEventListener('error', onError);
      signal?.removeEventListener('abort', onAbort);
    };
    const onDone = () => {
      cleanup();
      resolve();
    };
    const onError = () => {
      cleanup();
      reject(new Error('Progressive voice buffer failed'));
    };
    const onAbort = () => {
      cleanup();
      reject(voiceAbortError());
    };
    sourceBuffer.addEventListener('updateend', onDone, { once: true });
    sourceBuffer.addEventListener('error', onError, { once: true });
    signal?.addEventListener('abort', onAbort, { once: true });

    // Copy the exact byte window into its own ArrayBuffer. This avoids a
    // SharedArrayBuffer/offset ambiguity across browser implementations.
    const bytes = chunk.slice().buffer;
    sourceBuffer.appendBuffer(bytes);
  });
}

function waitForAudioEnd(
  audio: HTMLAudioElement,
  signal?: AbortSignal,
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(voiceAbortError());
      return;
    }
    const cleanup = () => {
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('error', onError);
      signal?.removeEventListener('abort', onAbort);
    };
    const onEnded = () => {
      cleanup();
      resolve();
    };
    const onError = () => {
      cleanup();
      reject(new Error('Voice audio playback failed'));
    };
    const onAbort = () => {
      cleanup();
      reject(voiceAbortError());
    };
    audio.addEventListener('ended', onEnded, { once: true });
    audio.addEventListener('error', onError, { once: true });
    signal?.addEventListener('abort', onAbort, { once: true });
  });
}

/**
 * Play one canonical Chat speech segment as bytes arrive.
 *
 * The backend already returns a true StreamingResponse. Previously Web called
 * response.blob(), which buffered the entire segment before the first sound.
 * MediaSource-capable browsers now start after the first MP3 bytes append.
 * Browsers without MP3 MediaSource support keep the safe Blob fallback.
 */
export async function playSpeechResponse(
  response: Response,
  options: {
    signal?: AbortSignal;
    onAudio?: (audio: HTMLAudioElement) => void;
  } = {},
): Promise<void> {
  const { signal, onAudio } = options;
  if (signal?.aborted) throw voiceAbortError();

  if (!response.body || !supportsProgressiveMp3Playback()) {
    const blob = await response.blob();
    if (signal?.aborted) throw voiceAbortError();
    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    onAudio?.(audio);
    const ended: Promise<Error | null> = waitForAudioEnd(audio, signal).then(
    (): Error | null => null,
    (error): Error | null => error instanceof Error ? error : new Error(String(error)),
  );
    try {
      await audio.play();
      const endError = await ended;
      if (endError) throw endError;
    } finally {
      audio.pause();
      audio.removeAttribute('src');
      URL.revokeObjectURL(url);
    }
    return;
  }

  const mediaSource = new MediaSource();
  const url = URL.createObjectURL(mediaSource);
  const audio = new Audio();
  const reader = response.body.getReader();
  audio.preload = 'auto';
  audio.src = url;
  onAudio?.(audio);
  const ended: Promise<Error | null> = waitForAudioEnd(audio, signal).then(
    (): Error | null => null,
    (error): Error | null => error instanceof Error ? error : new Error(String(error)),
  );

  try {
    await waitForMediaSourceOpen(mediaSource, signal);
    const sourceBuffer = mediaSource.addSourceBuffer('audio/mpeg');
    let started = false;
    let playError: unknown = null;
    let playPromise: Promise<void> | null = null;

    while (true) {
      if (signal?.aborted) throw voiceAbortError();
      const { done, value } = await reader.read();
      if (done) break;
      if (!value?.byteLength) continue;
      await appendMediaChunk(sourceBuffer, value, signal);
      if (!started) {
        started = true;
        // Do not await play() here. Some decoders need more than the first
        // MP3 chunk before the play promise resolves; blocking the reader would
        // prevent those bytes from ever reaching MediaSource.
        playPromise = audio.play().catch((error) => {
          playError = error;
        });
      }
    }

    if (!started) throw new Error('Voice provider returned empty audio');
    if (mediaSource.readyState === 'open' && !sourceBuffer.updating) {
      mediaSource.endOfStream();
    }
    await playPromise;
    if (playError) throw playError;
    const endError = await ended;
    if (endError) throw endError;
  } finally {
    try { await reader.cancel(); } catch { /* stream already closed */ }
    audio.pause();
    audio.removeAttribute('src');
    URL.revokeObjectURL(url);
  }
}


export type VoiceStreamEvent =
  | {
      type: 'voice_text_segment';
      text: string;
      sequence: number;
      messageId: string;
      turnId?: string;
      serverElapsedMs?: number;
    }
  | {
      type: 'voice_ready';
      text: string;
      messageId: string;
      speak: boolean;
    }
  | {
      type: 'voice_incomplete';
      text: string;
      messageId: string;
    };

const voiceStreamTarget =
  typeof EventTarget !== 'undefined' ? new EventTarget() : null;
const VOICE_STREAM_EVENT = 'lyo-voice-stream';

export function publishVoiceStreamEvent(event: VoiceStreamEvent): void {
  if (!voiceStreamTarget || typeof CustomEvent === 'undefined') return;
  voiceStreamTarget.dispatchEvent(
    new CustomEvent<VoiceStreamEvent>(VOICE_STREAM_EVENT, { detail: event }),
  );
}

export function subscribeVoiceStreamEvents(
  handler: (event: VoiceStreamEvent) => void,
): () => void {
  if (!voiceStreamTarget) return () => undefined;
  const listener = (raw: Event) => {
    const event = raw as CustomEvent<VoiceStreamEvent>;
    if (event.detail) handler(event.detail);
  };
  voiceStreamTarget.addEventListener(VOICE_STREAM_EVENT, listener);
  return () => voiceStreamTarget.removeEventListener(VOICE_STREAM_EVENT, listener);
}
