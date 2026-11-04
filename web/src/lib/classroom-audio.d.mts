export class SpeechPreparationCache {
  constructor(limit?: number);
  prepare(key: string, load: (signal: AbortSignal) => Promise<Response | null>): void;
  take(key: string): { controller: AbortController; response: Promise<Response | null> } | undefined;
  clear(): void;
}
export function splitSpeechForStreaming(text: string, firstChars?: number, laterChars?: number): string[];
export function boardTransitionDelay(): number;
export function playSpeechResponse(response: Promise<Response | null>, options: {
  signal: AbortSignal;
  onStarted?: () => void;
  startupTimeoutMs?: number;
}): Promise<void>;
export function speakBrowserFallback(text: string, options?: {
  language?: string;
  rate?: number;
  signal?: AbortSignal;
  onStarted?: () => void;
}): Promise<void>;
