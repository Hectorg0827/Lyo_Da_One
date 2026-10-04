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


export type VoiceTextSegment = {
  text: string;
  sequence: number;
};

type VoiceTextSegmentListener = (segment: VoiceTextSegment) => void;

const voiceTextSegmentListeners = new Set<VoiceTextSegmentListener>();

/**
 * Ephemeral delivery bus for spoken segments.
 *
 * Segments are deliberately not persisted in Zustand or conversation history.
 * The canonical final answer remains the only stored assistant message; this
 * bus only lets the voice renderer start TTS while that answer is generating.
 */
export function emitVoiceTextSegment(text: string, sequence = 0) {
  const clean = stripForSpeech(text);
  if (!clean) return;
  for (const listener of voiceTextSegmentListeners) {
    listener({ text: clean, sequence });
  }
}

export function subscribeVoiceTextSegments(listener: VoiceTextSegmentListener) {
  voiceTextSegmentListeners.add(listener);
  return () => voiceTextSegmentListeners.delete(listener);
}
