import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildClassroomWsUrl,
  isTransferReady,
  normalizeClassroomMode,
} from './classroom-contract.mjs';

test('classroom URL preserves learner controls and course context', () => {
  const url = new URL(buildClassroomWsUrl('https://api.lyoapp.com/', {
    topic: 'Fractions',
    sessionId: 'course-7',
    objective: 'Compare fractions',
    difficulty: 'advanced',
    mode: 'challenge',
    durationMinutes: 20,
    reducedMotion: true,
  }, 'token-1'));
  assert.equal(url.protocol, 'wss:');
  assert.equal(url.searchParams.get('session_id'), 'course-7');
  assert.equal(url.searchParams.get('objective'), 'Compare fractions');
  assert.equal(url.searchParams.get('mode'), 'challenge');
  assert.equal(url.searchParams.get('duration_minutes'), '20');
  assert.equal(url.searchParams.get('reduced_motion'), 'true');
  assert.equal(url.searchParams.get('token'), 'token-1');
});

test('invalid modes fail safely to solo teacher mode', () => {
  assert.equal(normalizeClassroomMode('party'), 'solo');
});

test('transfer evidence requires a substantive response', () => {
  assert.equal(isTransferReady('too short', 6), false);
  assert.equal(isTransferReady('I apply the ratio by scaling every value equally', 6), true);
});
