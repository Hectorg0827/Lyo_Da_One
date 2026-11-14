import test from 'node:test';
import assert from 'node:assert/strict';
import { stackCourseHref, classroomExitHref } from './course-destination.mjs';

test('catalog stack cards route to numeric course detail', () => {
  assert.equal(stackCourseHref({ id: 18, content_id: '123', title: 'Biology', status: 'in_progress' }), '/courses/123');
});

test('free-topic course cards resume a saved classroom rather than a nonexistent title ID', () => {
  const href = stackCourseHref({
    id: 18, content_id: 'Teach me fractions', title: 'Teach me fractions', status: 'in_progress',
    extra_data: { classroom: { topic: 'Teach me fractions', objective: 'Understand and apply fractions', recordScope: 'unit', difficulty: 'beginner', durationMinutes: 30, language: 'en' } },
  });
  assert.ok(href.startsWith('/classroom?'));
  const params = new URLSearchParams(href.split('?')[1]);
  assert.equal(params.get('topic'), 'Teach me fractions');
  assert.equal(params.get('courseId'), 'Teach me fractions');
  assert.equal(params.get('resume'), '1');
  assert.equal(params.get('duration'), '30');
  assert.equal(params.get('recordScope'), 'unit');
});

test('legacy free-topic cards still resume; completed cards begin a fresh session', () => {
  const legacy = { id: 11, content_id: 'Photosynthesis', title: 'Photosynthesis', status: 'in_progress' };
  const resume = new URLSearchParams(stackCourseHref(legacy).split('?')[1]);
  assert.equal(resume.get('resume'), '1');
  assert.equal(resume.get('topic'), 'Photosynthesis');
  const complete = new URLSearchParams(stackCourseHref({ ...legacy, status: 'completed' }).split('?')[1]);
  assert.equal(complete.has('resume'), false);
});

test('a missing catalog content ID never uses the unrelated stack row ID', () => {
  const href = stackCourseHref({ id: 99, title: 'Drawing', status: 'in_progress' });
  assert.ok(href.startsWith('/classroom?'));
  assert.equal(new URLSearchParams(href.split('?')[1]).get('courseId'), 'Drawing');
});

test('leaving a free-topic classroom returns to Focus regardless of browser history', () => {
  assert.equal(classroomExitHref('Teach me fractions'), '/');
  assert.equal(classroomExitHref('123'), '/courses/123');
  assert.equal(classroomExitHref('0'), '/');
});
