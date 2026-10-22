import assert from 'node:assert/strict';
import test from 'node:test';
import { courseDestination } from './course-destination.mjs';

test('real numeric course IDs open the persisted course', () => {
  assert.equal(courseDestination({ id: 82, content_id: '123', title: 'Fractions' }), '/courses/123');
});

test('topic labels never enter the integer-only course detail route', () => {
  assert.equal(courseDestination({ id: 82, content_id: 'Fractions', title: 'Fractions' }),
    '/classroom?topic=Fractions&courseId=Fractions');
});

test('a Stack row ID must never masquerade as a course ID', () => {
  assert.equal(courseDestination({ id: 82, content_id: null, title: 'Plant Biology' }),
    '/classroom?topic=Plant%20Biology&courseId=stack-82');
});

test('UUID-like and sentinel course IDs fall back to a working classroom entry', () => {
  for (const content_id of ['gen_abc-123', 'GENERATE:review:12', '9f28c8ab-f1ce-47cd-bcd3-9398c615504e']) {
    const url = courseDestination({ id: 22, content_id, title: 'Chemistry' });
    assert.ok(url.startsWith('/classroom?topic=Chemistry&courseId='));
    assert.ok(!url.startsWith('/courses/'));
  }
});

test('path injection and unsafe integers cannot become detail routes', () => {
  for (const content_id of ['../../admin', '1/2', '999999999999999999999999999999', '0', '-12']) {
    assert.ok(courseDestination({ id: 5, content_id, title: 'Bio' }).startsWith('/classroom?'));
  }
});
