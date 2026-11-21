/**
 * Rejoin an interrupted Classroom socket without ending the learner's class.
 * A final "ended" scene or explicit user exit must never be auto-reopened.
 * Returning null signals that automated attempts are exhausted.
 *
 * Keep retry timing deterministic and bounded to avoid reconnect storms.
 */
const RETRY_DELAYS_MS = Object.freeze([400, 1000, 2200, 4400]);

export function nextClassroomReconnectDelay(attempt, {lessonEnded = false, intentionalExit = false} = {}) {
  if (lessonEnded || intentionalExit || !Number.isInteger(attempt) || attempt < 0) return null;
  return RETRY_DELAYS_MS[attempt] ?? null;
}

/** A retry is always the SAME classroom session, not a new generation. */
export function classroomRejoinConnection(connection, sessionId) {
  if (!sessionId || typeof sessionId !== 'string') throw new Error('Cannot rejoin a Classroom without a session ID');
  return {...connection, sessionId};
}
