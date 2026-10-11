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

/** The fast welcome uses a nested scene_stream envelope and sends no
 * component_render messages. Normal scene_start streams components separately. */
export function classroomSceneStart(message) {
  if (message?.type === 'scene_stream') {
    const scene = message.data?.scene;
    return {
      scene,
      inlineComponents: Array.isArray(scene?.components) ? scene.components : [],
    };
  }
  if (message?.event_type === 'scene_start' || message?.type === 'scene_start'
      || message?.event_type === 'SCENE_START') {
    return { scene: message.scene, inlineComponents: [] };
  }
  return null;
}

export function buildClassroomWsUrl(apiUrl, connection, token) {
  const base = apiUrl.replace(/^http/, 'ws').replace(/\/$/, '');
  const params = new URLSearchParams({
    session_id: connection.sessionId || connection.topic,
    client_contract_version: '2',
    topic: connection.topic,
    mode: normalizeClassroomMode(connection.mode),
    duration_minutes: String(Math.max(3, Math.min(60, Number(connection.durationMinutes) || 10))),
    reduced_motion: connection.reducedMotion ? 'true' : 'false',
    language: connection.language || 'auto',
  });
  if (connection.courseId) params.set('course_id', connection.courseId);
  if (connection.recordScope === 'unit') params.set('record_scope', 'unit');
  if (connection.lessonId) params.set('lesson_id', connection.lessonId);
  if (connection.reviewConceptId) params.set('review_concept_id', connection.reviewConceptId);
  if (connection.objective) params.set('objective', connection.objective);
  if (connection.difficulty) params.set('difficulty', connection.difficulty);
  if (token) params.set('token', token);
  return `${base}/api/v1/classroom/ws/connect?${params}`;
}

export function isTransferReady(response, minWords = 6) {
  return response.trim().split(/\s+/).filter(Boolean).length >= minWords;
}

// ─── Starting a class, and starting it over ─────────────────────────────────

/**
 * The live teaching session is keyed server-side by `session_id`, and the
 * engine stores the learner's place inside it (`GuidedState`). So the id a
 * client sends is not a label — it decides whether the backend teaches a
 * lesson or resumes one.
 *
 * Every surface used to send the course id (or, for a free topic, the topic
 * text itself), which meant the id never changed. A learner who opened the
 * same topic a second time was handed back the session they left, mid-unit,
 * with no opening and no way to ask for a clean start: the class began with
 * the teacher carrying on about something the learner had not been told yet.
 * It was worst after a failed step, because the broken session was the one
 * that came back every time.
 *
 * The first class on a topic still sends exactly the id it always did, so
 * nothing changes for a learner meeting a topic for the first time. Opening
 * the same topic again starts a new session beside it, and resuming is
 * something the learner asks for rather than the only thing on offer.
 */

/** Which course or topic a saved session belongs to. */
export function classroomCourseKey(connection) {
  const key = (connection?.courseId || connection?.topic || '').toString().trim();
  return key || 'general';
}

/** Where a surface remembers the last live session for a course. */
export function classroomSessionStorageKey(courseKey) {
  return `lyo_classroom_session:${courseKey}`;
}

/**
 * How long a half-finished class stays worth offering back.
 *
 * Past this, "pick up where you left off" is a promise about a lesson the
 * learner no longer remembers sitting, so the class simply starts.
 */
export const CLASSROOM_RESUME_WINDOW_MS = 6 * 60 * 60 * 1000;

export function canResumeClassroom(saved, now = Date.now()) {
  if (!saved || !saved.id) return false;
  // A class that reached its end is not unfinished, however recent it is.
  // Without this a learner who sat a lesson through to the dismissal and
  // reopened the topic an hour later was told they had an unfinished class
  // and offered the finished one back — which would drop them on its last
  // screen. Age alone cannot tell those two apart.
  if (saved.finished) return false;
  const startedAt = Number(saved.startedAt);
  if (!Number.isFinite(startedAt)) return false;
  return now - startedAt >= 0 && now - startedAt <= CLASSROOM_RESUME_WINDOW_MS;
}

/**
 * The session id this entry should connect with.
 *
 * `saved` is whatever the surface stored last time (or null). `resume` is the
 * learner actually asking for their old seat back — never the default, and
 * never honoured for a session too old to recognise.
 */
export function classroomSessionStart(courseKey, saved, { resume = false, now = Date.now() } = {}) {
  const key = (courseKey ?? '').toString().trim() || 'general';
  if (resume && canResumeClassroom(saved, now)) {
    return {
      sessionId: saved.id,
      generation: Math.max(1, Number(saved.generation) || 1),
      resumed: true,
    };
  }
  // A brand-new client has no local history, but the backend can still hold
  // an old failed session under the plain topic key. Every fresh entry needs
  // its own server identity, even on the first run after app installation.
  // Keep the original course key separate for learner progress.
  const generation = !saved?.id ? 1 : Math.max(1, Number(saved.generation) || 1) + 1;
  return { sessionId: `${key}~${generation}-${now}`, generation, resumed: false };
}

// ─── When the next step does not arrive ─────────────────────────────────────

/**
 * A class can only wait so long before waiting is itself a failure.
 *
 * The teaching engine generates each turn on demand, so a slow or failed
 * generation reaches the learner as nothing at all: no speech, no board, no
 * control that does anything. Clients used to wait forever. These are the two
 * moments at which they stop pretending.
 *
 * NOTICE: say out loud that this is taking longer than it should.
 * RECOVERY: the step is not coming — resend it once, then hand the learner
 * controls that can actually get the class moving again.
 */
export const CLASSROOM_STALL_NOTICE_MS = 12000;
export const CLASSROOM_STALL_RECOVERY_MS = 30000;

export const CLASSROOM_STALL_NOTICE =
  'This step is taking longer than it should. Still working on it…';
export const CLASSROOM_STALL_RECOVERY =
  "The next step didn't arrive. Nothing you've done is lost, and this is not a wrong answer.";

// ─── The lesson has a beginning ─────────────────────────────────────────────

/**
 * What the learner is told before the teaching starts.
 *
 * A class that opens straight into a teaching turn gives the learner no way
 * to tell whether they are at the start of something or in the middle of it,
 * and after a resumed or recovered session they were genuinely in the middle
 * of it with nothing saying so. This is the cover page: the subject, what the
 * session is for, how long it runs, and the fact that they can interrupt it.
 *
 * It is deliberately not teaching, and it claims nothing the engine has not
 * been asked for — the objective and the length are the ones that went up the
 * wire, so the card cannot promise a lesson different from the one requested.
 */
export const CLASSROOM_OPENING_NOTE =
  'You can stop Lyo at any time — raise your hand, ask a question, or say you are lost.';

export function classroomOpening({
  topic, objective, durationMinutes, difficulty, mode, resumed = false,
} = {}) {
  const subject = (topic ?? '').toString().trim() || 'this topic';
  const minutes = Math.max(3, Math.min(60, Number(durationMinutes) || 10));
  const facts = [`${minutes} min`];
  if (difficulty) facts.push(`${difficulty} level`);
  const lessonMode = normalizeClassroomMode(mode);
  if (lessonMode !== 'solo') facts.push(`${lessonMode} mode`);
  return {
    title: resumed ? `Back to ${subject}` : `Today: ${subject}`,
    objective: (objective ?? '').toString().trim() || defaultClassroomObjective(subject),
    facts,
    note: CLASSROOM_OPENING_NOTE,
    resumed,
  };
}

/** Mirrors entry-contract's defaultObjective, for callers that never had one. */
export function defaultClassroomObjective(topic) {
  return `Understand and apply ${topic}`;
}
