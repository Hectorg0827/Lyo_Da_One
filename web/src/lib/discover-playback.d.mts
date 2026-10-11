export interface PlaybackIntent { selected: boolean; foreground: boolean; paused: boolean; scrubbing: boolean; failed: boolean; }
export class DiscoverPlaybackController {
  constructor(video: HTMLVideoElement, callbacks?: { onBlocked?: () => void; onError?: () => void });
  update(intent: PlaybackIntent): void;
  seek(seconds: number): void;
  dispose(): void;
}
export interface PageRequest { page: number; generation: number; }
export class DiscoverPageCursor {
  nextPage: number;
  reset(): void;
  begin(): PageRequest | null;
  complete(request: PageRequest): boolean;
  fail(request: PageRequest): void;
}
export function mergeClipPage<T extends Record<string, unknown>>(current: T[], incoming: T[]): T[];
export function nextClipIndex(ids: string[], selectedId: string | undefined, finishedId: string): number | null;
