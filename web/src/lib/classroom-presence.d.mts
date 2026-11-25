export const WAITING_COMPANION_BEATS: ReadonlyArray<{
  showAtMs: number;
  hideAtMs: number;
  cue: string;
}>;
export function teacherPresenceMs(options?: { narrating?: boolean; prompt?: boolean }): number;
