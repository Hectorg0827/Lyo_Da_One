export function playVoiceBlob(blob: Blob, options: {
  signal: AbortSignal;
  volume?: number;
  onAudio?: (audio: HTMLAudioElement | null, owner: HTMLAudioElement) => void;
  onStart?: () => void;
  onProgress?: (fraction: number) => void;
}): Promise<void>;
export function speakVoiceFallback(text: string, options: {
  signal: AbortSignal;
  language?: string;
  onStart?: () => void;
}): Promise<void>;
export function unspokenRemainder(text: string, fraction?: number): string;
export function pauseAfterSpeechMs(text: string): number;
export function waitForSpeechPause(milliseconds: number, options?: { signal?: AbortSignal }): Promise<void>;
