import test from 'node:test';
import assert from 'node:assert/strict';
import { CLASSMATES, LYO_COMPANION, TEACHERS, classroomSpeaker, speakingClassmates, teacherForTopic } from './classroom-cast.mjs';

test('four existing teachers and four existing student characters have distinct identities', () => {
  assert.equal(TEACHERS.length, 4);
  assert.equal(CLASSMATES.length, 4);
  assert.equal(new Set([...TEACHERS, ...CLASSMATES, LYO_COMPANION].map((p) => p.id)).size, 9);
  assert.equal(new Set([...TEACHERS, ...CLASSMATES].map((p) => p.image)).size, 8);
  assert.ok(TEACHERS.every((p) => p.id !== LYO_COMPANION.id));
});

test('subject teacher does not drift and Lyo remains the companion', () => {
  assert.deepEqual(teacherForTopic('Algebra'), teacherForTopic('algebra'));
  assert.equal(classroomSpeaker('Teacher', 'Algebra')?.id, teacherForTopic('Algebra').id);
  assert.equal(classroomSpeaker('Lyo', 'Algebra'), LYO_COMPANION);
  assert.equal(classroomSpeaker('Rio')?.id, 'student_rio');
});

test('classmate rail only shows people with actual speaking turns', () => {
  const realTurns = [{ speaker: 'Teacher' }, { speaker: 'Maya' }, { speaker: 'You' }];
  assert.deepEqual(speakingClassmates(realTurns, 'solo'), []);
  assert.deepEqual(speakingClassmates(realTurns, 'classroom').map((p) => p.name), ['Maya']);
  assert.deepEqual(speakingClassmates([], 'classroom'), []);
});
