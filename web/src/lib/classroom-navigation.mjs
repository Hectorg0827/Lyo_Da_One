/**
 * Decide the permanent classroom Next control from the live lesson state.
 * History navigation never sends a graded action. While feedback is loading,
 * disabled navigation cannot accidentally submit the learner's answer twice.
 */
export function classroomNextAction({
  viewingHistory = false, readyToContinue = false, narrating = false,
  stalled = false, live = false, waiting = false,
  hasCheckpoint = false, hasPrompt = false, continueLabel = 'Continue',
} = {}) {
  if (viewingHistory) return { type: 'history', label: 'Next board', disabled: false };
  if (readyToContinue) return { type: 'continue', label: continueLabel || 'Continue', disabled: false };
  if (narrating && live) return { type: 'skip', label: 'Skip narration', disabled: false };
  if (stalled && live) return { type: 'retry', label: 'Ask teacher again', disabled: false };
  if (hasCheckpoint || hasPrompt) return { type: 'answer', label: 'Answer to continue', disabled: true };
  if (waiting) return { type: 'waiting', label: live ? 'Preparing next step…' : 'Restoring lesson…', disabled: true };
  return { type: 'waiting', label: live ? 'Preparing next step…' : 'Connecting…', disabled: true };
}

/**
 * Progress is server-authored. A learner can return to their courses once
 * every tracked skill is completed and a recap has appeared, but never while
 * answering a checkpoint or while the next scene is still being generated.
 * This is navigation only: it does not increment progress or end a session.
 * @param {{progressCurrent?: number, progressTotal?: number,
 *   board?: readonly {kind?: string}[], viewingHistory?: boolean,
 *   waiting?: boolean, hasCheckpoint?: boolean, hasPrompt?: boolean}} options
 */
export function classroomCompletionExitReady({
  progressCurrent = 0, progressTotal = 0, board = [], viewingHistory = false,
  waiting = false, hasCheckpoint = false, hasPrompt = false,
} = {}) {
  return !viewingHistory && !waiting && !hasCheckpoint && !hasPrompt
    && Number.isFinite(progressCurrent) && Number.isFinite(progressTotal)
    && progressTotal > 0 && progressCurrent >= progressTotal
    && Array.isArray(board) && board.some((element) => element?.kind === 'summary');
}
