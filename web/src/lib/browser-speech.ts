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

export function dictationErrorMessage(error?: string, spanish = false): string {
  switch (error) {
    case 'not-allowed':
    case 'service-not-allowed':
      return spanish ? 'Permite el acceso al micrófono y al dictado en el navegador, o escribe tu respuesta.' : 'Allow microphone and dictation access in your browser, or type your response.';
    case 'audio-capture':
      return spanish ? 'Comprueba que el micrófono esté conectado y seleccionado, y vuelve a intentarlo.' : 'Check that your microphone is connected and selected, then try again.';
    case 'network':
      return spanish ? 'No se pudo conectar al servicio de dictado. Vuelve a intentarlo o escribe tu respuesta.' : 'Could not reach the speech service. Try again or type your response.';
    case 'no-speech':
      return spanish ? 'No se detectó voz. Pulsa el micrófono para volver a intentarlo.' : 'No speech was detected. Press the microphone to try again.';
    default:
      return spanish ? 'El dictado se detuvo. Vuelve a intentarlo o escribe tu respuesta.' : 'Dictation stopped. Try again or type your response.';
  }
}
