/**
 * Brief appearances, separated by useful board-only time. A slow model or
 * voice service must not leave Lyo painted on-screen for the whole wait.
 * Each beat is a real waiting message, never a claim of percent complete.
 */
export const WAITING_COMPANION_BEATS = Object.freeze([
  { showAtMs: 1800, hideAtMs: 4900, cue: 'Your next step is on its way…' },
  { showAtMs: 10500, hideAtMs: 13700, cue: 'Still here with you. The teacher is taking a moment.' },
  { showAtMs: 22000, hideAtMs: 25600, cue: 'This is taking longer than usual. Your work is still here.' },
]);

/** Show the teacher at a turn's entrance, then make room for the lesson. */
export function teacherPresenceMs({ narrating = false, prompt = false } = {}) {
  if (narrating) return 6200;
  return prompt ? 3600 : 2200;
}
