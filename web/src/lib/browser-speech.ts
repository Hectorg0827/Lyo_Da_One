import type { SpeechResultEventLike } from './speech-transcript.mjs';
import { normalizeSpeechLang } from './speech-transcript.mjs';

export type BrowserSpeechRecognition = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  maxAlternatives?: number;
  start: () => void;
  stop: () => void;
  abort?: () => void;
  onresult: ((event: SpeechResultEventLike) => void) | null;
  onend: (() => void) | null;
  onerror: ((event?: { error?: string }) => void) | null;
};

export function createBrowserSpeechRecognition(): BrowserSpeechRecognition | null {
  if (typeof window === 'undefined') return null;
  const browser = window as unknown as Record<string, unknown>;
  const Recognition = (browser.SpeechRecognition || browser.webkitSpeechRecognition) as
    | (new () => BrowserSpeechRecognition)
    | undefined;
  return Recognition ? new Recognition() : null;
}

/**
 * Settings every dictation surface shares.
 *
 * Asking for several alternatives lets the transcript pick the most confident
 * wording rather than whichever one the engine happened to list first, and a
 * region-qualified language tag keeps the recognizer on a single accent model.
 */
export function configureDictation(
  recognition: BrowserSpeechRecognition,
  lang?: string | null,
): void {
  recognition.lang = normalizeSpeechLang(
    lang ?? (typeof navigator === 'undefined' ? null : navigator.language),
  );
  recognition.interimResults = true;
  recognition.continuous = true;
  recognition.maxAlternatives = 3;
}
