import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildClassroomWsUrl,
  classroomSceneStart,
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
