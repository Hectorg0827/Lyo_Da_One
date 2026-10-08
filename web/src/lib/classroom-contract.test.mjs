import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CLASSROOM_RESUME_WINDOW_MS,
  CLASSROOM_STALL_NOTICE_MS,
  CLASSROOM_STALL_RECOVERY,
  CLASSROOM_STALL_RECOVERY_MS,
  buildClassroomWsUrl,
  canResumeClassroom,
  classroomCourseKey,
  classroomOpening,
  classroomSceneStart,
  classroomSessionStart,
  classroomSessionStorageKey,
  defaultClassroomObjective,
  isTransferReady,
  normalizeClassroomMode,
} from './classroom-contract.mjs';

test('classroom URL preserves learner controls and course context', () => {
  const url = new URL(buildClassroomWsUrl('https://api.lyoapp.com/', {
    topic: 'Fractions',
    sessionId: 'course-7',
    courseId: 'course-7',
    lessonId: 'lesson-3',
    objective: 'Compare fractions',
    difficulty: 'advanced',
    mode: 'challenge',
    durationMinutes: 20,
    reducedMotion: true,
    language: 'es-US',
  }, 'token-1'));
  assert.equal(url.protocol, 'wss:');
  assert.equal(url.searchParams.get('session_id'), 'course-7');
  assert.equal(url.searchParams.get('course_id'), 'course-7');
  assert.equal(url.searchParams.get('lesson_id'), 'lesson-3');
  assert.equal(url.searchParams.get('client_contract_version'), '2');
  assert.equal(url.searchParams.get('objective'), 'Compare fractions');
  assert.equal(url.searchParams.get('mode'), 'challenge');
  assert.equal(url.searchParams.get('duration_minutes'), '20');
  assert.equal(url.searchParams.get('reduced_motion'), 'true');
  assert.equal(url.searchParams.get('language'), 'es-US');
  assert.equal(url.searchParams.get('token'), 'token-1');
});

test('invalid modes fail safely to solo teacher mode', () => {
  assert.equal(normalizeClassroomMode('party'), 'solo');
});

test('unit record scope reaches the teaching engine only when explicitly requested', () => {
  const base = 'https://api.lyoapp.com';
  const expanded = new URL(buildClassroomWsUrl(base, {
    topic: 'Digital Marketing', recordScope: 'unit', durationMinutes: 30,
  }, null));
  const focused = new URL(buildClassroomWsUrl(base, { topic: 'Quadratic equations' }, null));
  assert.equal(expanded.searchParams.get('record_scope'), 'unit');
  assert.equal(focused.searchParams.get('record_scope'), null);
});

test('nested fast welcome restores saved skill identities and renders its only components', () => {
  const scene = {
    metadata: { target_concepts: ['Customer Segmentation', 'Marketing Positioning'] },
    components: [{ type: 'TeacherMessage', component_id: 'opening', text: 'What do you know?' }],
  };
  const fast = classroomSceneStart({ type: 'scene_stream', data: { event_type: 'SCENE_START', scene } });
  assert.equal(fast.scene, scene);
  assert.deepEqual(fast.inlineComponents, scene.components);
  const normal = classroomSceneStart({ event_type: 'scene_start', scene });
  assert.equal(normal.scene, scene);
  assert.deepEqual(normal.inlineComponents, []); // separately streamed; no duplicate teacher speech
});

test('transfer evidence requires a substantive response', () => {
  assert.equal(isTransferReady('too short', 6), false);
  assert.equal(isTransferReady('I apply the ratio by scaling every value equally', 6), true);
});

// ─── Starting a class, and starting it over ─────────────────────────────────

test('a first class sends exactly the id every client sent before', () => {
  const start = classroomSessionStart('course-7', null);
  assert.deepEqual(start, { sessionId: 'course-7', generation: 1, resumed: false });
});

test('opening the same topic again is a new class, not the old seat', () => {
  const first = classroomSessionStart('Teach me minecraft', null);
  const second = classroomSessionStart('Teach me minecraft', {
    id: first.sessionId, startedAt: Date.now(), generation: first.generation,
  });
  assert.notEqual(second.sessionId, first.sessionId);
  assert.equal(second.resumed, false);
  assert.equal(second.generation, 2);
  // A third entry does not collide with the second.
  const third = classroomSessionStart('Teach me minecraft', {
    id: second.sessionId, startedAt: Date.now(), generation: second.generation,
  });
  assert.notEqual(third.sessionId, second.sessionId);
});

test('resuming is honoured only when the learner asks for it', () => {
  const saved = { id: 'course-7~2', startedAt: Date.now(), generation: 2 };
  assert.equal(classroomSessionStart('course-7', saved, { resume: true }).sessionId, 'course-7~2');
  assert.equal(classroomSessionStart('course-7', saved, { resume: true }).resumed, true);
  assert.equal(classroomSessionStart('course-7', saved).sessionId, 'course-7~3');
});

test('a class too old to remember sitting is started, not resumed', () => {
  const now = Date.now();
  const stale = { id: 'course-7~2', startedAt: now - CLASSROOM_RESUME_WINDOW_MS - 1, generation: 2 };
  assert.equal(canResumeClassroom(stale, now), false);
  const start = classroomSessionStart('course-7', stale, { resume: true, now });
  assert.equal(start.resumed, false);
  assert.equal(start.sessionId, 'course-7~3');
});

test('the session id survives the wire as the id the engine is keyed by', () => {
  const start = classroomSessionStart('Teach me minecraft', {
    id: 'Teach me minecraft', startedAt: Date.now(), generation: 1,
  });
  const url = new URL(buildClassroomWsUrl('https://api.lyoai.app', {
    topic: 'Teach me minecraft', sessionId: start.sessionId,
  }, null));
  assert.equal(url.searchParams.get('session_id'), start.sessionId);
  assert.equal(url.searchParams.get('topic'), 'Teach me minecraft');
});

test('the course key prefers the real course over the typed topic', () => {
  assert.equal(classroomCourseKey({ courseId: 'course-7', topic: 'Fractions' }), 'course-7');
  assert.equal(classroomCourseKey({ topic: 'Fractions' }), 'Fractions');
  assert.equal(classroomCourseKey(null), 'general');
  assert.equal(classroomSessionStorageKey('course-7'), 'lyo_classroom_session:course-7');
});

// ─── The lesson has a beginning ─────────────────────────────────────────────

test('the opening names the lesson that was actually requested', () => {
  const opening = classroomOpening({
    topic: 'Minecraft', objective: 'Build a first shelter',
    durationMinutes: 20, difficulty: 'beginner', mode: 'solo',
  });
  assert.equal(opening.title, 'Today: Minecraft');
  assert.equal(opening.objective, 'Build a first shelter');
  assert.deepEqual(opening.facts, ['20 min', 'beginner level']);
  assert.equal(opening.resumed, false);
  assert.match(opening.note, /stop Lyo at any time/);
});

test('a resumed class says so instead of pretending to start', () => {
  assert.equal(classroomOpening({ topic: 'Minecraft', resumed: true }).title, 'Back to Minecraft');
});

test('the opening falls back to the objective the entry contract would send', () => {
  const opening = classroomOpening({ topic: 'Fractions', durationMinutes: 999, mode: 'challenge' });
  assert.equal(opening.objective, defaultClassroomObjective('Fractions'));
  // The length shown is the length the server will be told, clamped the same way.
  assert.deepEqual(opening.facts, ['60 min', 'challenge mode']);
});

test('the stall thresholds give the first one time to be slow before it is broken', () => {
  assert.ok(CLASSROOM_STALL_NOTICE_MS > 0);
  assert.ok(CLASSROOM_STALL_RECOVERY_MS > CLASSROOM_STALL_NOTICE_MS);
  assert.match(CLASSROOM_STALL_RECOVERY, /not a wrong answer/);
});
