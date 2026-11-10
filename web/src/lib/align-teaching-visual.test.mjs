import test from 'node:test';
import assert from 'node:assert/strict';
import { alignTeachingVisualToExample } from './align-teaching-visual.mjs';
import { parseTeachingVisual } from './teaching-activity.mjs';

const pie = parseTeachingVisual({ kind: 'fraction_pie', title: '3 out of 6 slices', caption: '3 mini slices of 6',
  description: 'Three of six slices form half the circle', parts: 6, value: 3, whole: 1, unit: 'whole' });

test('chocolate-bar example displays a rectangular fraction without changing its mathematics', () => {
  const original = structuredClone(pie);
  const aligned = alignTeachingVisualToExample(pie, 'Watch me · Chocolate Bar Analogy', 'Total bar = six mini-squares');
  assert.equal(aligned.kind, 'fraction_bar');
  assert.equal(aligned.parts, 6);
  assert.equal(aligned.value, 3);
  assert.equal(aligned.whole, 1);
  assert.match(aligned.title, /Chocolate bar/);
  assert.deepEqual(pie, original, 'server source must remain unchanged');
  assert.deepEqual(parseTeachingVisual(aligned), aligned);
});

test('pizza/circle comparisons and unrelated examples keep the authored pie', () => {
  assert.equal(alignTeachingVisualToExample(pie, 'Pizza slices'), pie);
  assert.equal(alignTeachingVisualToExample(pie, 'Chocolate Bar versus Pizza', 'Compare a circle with a bar'), pie);
  assert.equal(alignTeachingVisualToExample(pie, 'Chocolate Bar Analogy', 'Use a circular pie to compare'), pie);
});

test('non-fraction visuals and an unusable heading never change', () => {
  const bar = { ...pie, kind: 'fraction_bar' };
  assert.equal(alignTeachingVisualToExample(bar, 'Chocolate Bar Analogy'), bar);
  assert.equal(alignTeachingVisualToExample(pie, '', ''), pie);
});
