import test from 'node:test';
import assert from 'node:assert/strict';
import { courseLessonBlocks, courseLessonMinutes } from './course-durable-content.mjs';

test('persisted text content reopens as visible lesson block', () => {
  assert.deepEqual(courseLessonBlocks('1/2 means one of two equal parts', '42'), [
    { id: '42-text', type: 'text', content: '1/2 means one of two equal parts' },
  ]);
});
test('existing rich course blocks are preserved', () => {
  const blocks = [{ id: 'q1', type: 'quiz', content: 'What is 1/2?' }];
  assert.equal(courseLessonBlocks(blocks, '13'), blocks);
});
test('empty content does not invent a lesson explanation', () => {
  assert.deepEqual(courseLessonBlocks('   ', '5'), []);
  assert.deepEqual(courseLessonBlocks(null, '5'), []);
});
test('duration uses persisted minutes before legacy text', () => {
  assert.equal(courseLessonMinutes({ duration_minutes: 8, duration: '99 min' }), 8);
  assert.equal(courseLessonMinutes({ duration: '15 min' }), 15);
  assert.equal(courseLessonMinutes({}), 10);
});
