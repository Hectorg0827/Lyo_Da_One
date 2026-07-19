export const CLASSROOM_MODES = Object.freeze(['solo', 'classroom', 'challenge', 'review']);
export const HINT_LEVELS = Object.freeze([
  'nudge',
  'principle',
  'worked_step',
  'full_example',
  'prerequisite',
]);

export function normalizeClassroomMode(value) {
  return CLASSROOM_MODES.includes(value) ? value : 'solo';
}

export function buildClassroomWsUrl(apiUrl, connection, token) {
  const base = apiUrl.replace(/^http/, 'ws').replace(/\/$/, '');
  const params = new URLSearchParams({
    session_id: connection.sessionId || connection.topic,
    topic: connection.topic,
    mode: normalizeClassroomMode(connection.mode),
    duration_minutes: String(Math.max(3, Math.min(60, Number(connection.durationMinutes) || 10))),
    reduced_motion: connection.reducedMotion ? 'true' : 'false',
  });
  if (connection.objective) params.set('objective', connection.objective);
  if (connection.difficulty) params.set('difficulty', connection.difficulty);
  if (token) params.set('token', token);
  return `${base}/api/v1/classroom/ws/connect?${params}`;
}

export function isTransferReady(response, minWords = 6) {
  return response.trim().split(/\s+/).filter(Boolean).length >= minWords;
}
