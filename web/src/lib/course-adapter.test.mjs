import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeCourseModules, normalizeLessonBlocks } from './course-adapter.mjs';

test('actual backend CourseDetailResponse renders saved top-level lessons with text', () => {
  const modules = normalizeCourseModules({
    id: 'course-123',
    title: 'Intermediate Algebra',
    lessons_count: 2,
    lessons: [
      {
        id: 'lesson-2', title: 'Quadratic Expressions',
        content: 'Factoring expressions\nExample: x² + 5x + 6',
        order_index: 1, estimated_duration_minutes: 22,
      },
      {
        id: 'lesson-1', title: 'Linear Equations',
        content: 'Solve equations by balancing both sides.',
        order_index: 0, estimated_duration_minutes: 18,
      },
    ],
  });
  assert.equal(modules.length, 1);
  assert.equal(modules[0].lessons.length, 2);
  assert.equal(modules[0].lessons[0].id, 'lesson-1');
  assert.equal(modules[0].lessons[0].content[0].content, 'Solve equations by balancing both sides.');
  assert.equal(modules[0].lessons[1].duration, 22);
  assert.match(modules[0].lessons[1].content[0].content, /Factoring expressions/);
});

test('nested modules keep authored lesson blocks, progress, and order', () => {
  const modules = normalizeCourseModules({
    id: 'old', modules: [{
      id: 'm1', title: 'Mechanics', lessons: [{
        id: 'l1', title: 'Motion', is_completed: true,
        blocks: [{ id: 'b1', type: 'heading', content: 'Velocity' },
                 { id: 'b2', type: 'text', content: 'Distance per unit time' }],
      }],
    }],
  });
  assert.equal(modules[0].lessons[0].isCompleted, true);
  assert.deepEqual(modules[0].lessons[0].content.map((block) => block.id), ['b1', 'b2']);
});

test('empty modules do not hide actual top-level lessons', () => {
  const modules = normalizeCourseModules({
    id: 'course', modules: [{ title: 'Empty placeholder', lessons: [] }],
    lessons: [{ id: 'actual', title: 'Evidence', content: 'Real body' }],
  });
  assert.equal(modules.length, 1);
  assert.equal(modules[0].lessons[0].id, 'actual');
});

test('JSON-encoded lesson blocks are decoded only when structurally valid', () => {
  const value = JSON.stringify([{ type: 'text', content: 'Saved text' }]);
  assert.equal(normalizeLessonBlocks(value, 'lesson')[0].content, 'Saved text');
  assert.equal(normalizeLessonBlocks('[this is ordinary prose', 'lesson')[0].content, '[this is ordinary prose');
});

test('no fabricated instructional content for missing or malformed lessons', () => {
  const modules = normalizeCourseModules({
    id: 'course', lessons: [{ id: 'l1', title: 'Incomplete', content: '' }],
  });
  assert.equal(modules[0].lessons.length, 1);
  assert.deepEqual(modules[0].lessons[0].content, []);
  assert.deepEqual(normalizeCourseModules({ id: 'course', lessons_count: 4 }), []);
  assert.deepEqual(normalizeLessonBlocks({ unsafe: 'data' }, 'lesson'), []);
});

test('ignores unsupported block objects without rendering arbitrary objects', () => {
  const content = normalizeLessonBlocks(
    [{ type: 'script', content: '<script>alert(1)</script>' },
     { type: 'text', content: 'Safe literal text' },
     { type: 'text', content: { nested: true } }], 'lesson',
  );
  assert.equal(content.length, 1);
  assert.equal(content[0].content, 'Safe literal text');
});
