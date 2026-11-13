import test from 'node:test';
import assert from 'node:assert/strict';
import {classroomRejoinConnection, nextClassroomReconnectDelay} from './classroom-websocket-recovery.mjs';

test('unexpected disconnect receives finite, escalating retry delays', () => {
  assert.deepEqual([0, 1, 2, 3, 4].map((attempt) => nextClassroomReconnectDelay(attempt)),
    [400, 1000, 2200, 4400, null]);
});

test('lesson completion and intentional exit never reconnect', () => {
  assert.equal(nextClassroomReconnectDelay(0, {lessonEnded: true}), null);
  assert.equal(nextClassroomReconnectDelay(0, {intentionalExit: true}), null);
});

test('invalid attempt number fails closed rather than retrying forever', () => {
  assert.equal(nextClassroomReconnectDelay(-1), null);
  assert.equal(nextClassroomReconnectDelay(NaN), null);
  assert.equal(nextClassroomReconnectDelay(1.5), null);
});

test('reconnect preserves the exact session, course and learner preferences', () => {
  const original = {topic: 'Fractions', courseId: 'course42', language: 'es',
    sessionId: undefined, durationMinutes: 30};
  const result = classroomRejoinConnection(original, 'session-abc');
  assert.deepEqual(result, {...original, sessionId: 'session-abc'});
  assert.notEqual(result, original);
  assert.equal(original.sessionId, undefined);
});

test('cannot silently start another class when the session ID is absent', () => {
  assert.throws(() => classroomRejoinConnection({topic: 'Algebra'}, ''), /session ID/);
});
