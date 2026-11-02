/**
 * Decide the permanent classroom Next control from the live lesson state.
 * History navigation never sends a graded action. While feedback is loading,
 * disabled navigation cannot accidentally submit the learner's answer twice.
 */
export function classroomNextAction({
  viewingHistory = false, readyToContinue = false, narrating = false,
  stalled = false, live = false, waiting = false,
  hasCheckpoint = false, hasPrompt = false,
} = {}) {
  if (viewingHistory) return { type: 'history', label: 'Next board', disabled: false };
  if (readyToContinue) return { type: 'continue', label: 'Continue', disabled: false };
  if (narrating && live) return { type: 'skip', label: 'Skip narration', disabled: false };
  if (stalled && live) return { type: 'retry', label: 'Ask teacher again', disabled: false };
  if (hasCheckpoint || hasPrompt) return { type: 'answer', label: 'Answer to continue', disabled: true };
  if (waiting) return { type: 'waiting', label: live ? 'Preparing next step…' : 'Connecting…', disabled: true };
  return { type: 'waiting', label: live ? 'Preparing next step…' : 'Connecting…', disabled: true };
}
