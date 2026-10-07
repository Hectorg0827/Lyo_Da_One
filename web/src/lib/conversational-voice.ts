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


export type VoiceStreamEvent =
  | {
      type: 'voice_text_segment';
      text: string;
      sequence: number;
      messageId: string;
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
    }
  | {
      type: 'voice_transport_error';
      messageId: string;
    }
  | {
      type: 'voice_transport_recovered';
      messageId: string;
    }
  | {
      type: 'voice_handoff';
      target: 'classroom' | 'test_prep';
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
