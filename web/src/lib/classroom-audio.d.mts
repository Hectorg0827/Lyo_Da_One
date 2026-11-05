export class SpeechPreparationCache {
  constructor(limit?: number);
  hasPending(): boolean;
  prepare(key: string, load: (signal: AbortSignal) => Promise<Response | null>): void;
  take(key: string): { controller: AbortController; response: Promise<Response | null> } | undefined;
  clear(): void;
}
export function firstAudibleTurn(turns: Array<{ type: string; text?: string; speaker?: string }>): { type: string; text?: string; speaker?: string } | undefined;
export function silentCaptionDelay(text: string): number;
export class SpeechLookaheadQueue {
  constructor(segments: string[], load: (text: string, index: number) => Promise<Response | null>, firstResponse?: Promise<Response | null>);
  get(index: number): Promise<Response | null> | null;
  take(index: number): Promise<Response | null> | null;
  warmNext(index: number): Promise<Response | null> | null;
  clear(): void;
}
export function splitSpeechForStreaming(text: string, firstChars?: number, laterChars?: number): string[];
export function boardTransitionDelay(): number;
export function retryPlaybackAfterMoreAudio(error: { name?: string } | null | undefined): boolean;
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
  startupTimeoutMs?: number;
}): Promise<void>;
