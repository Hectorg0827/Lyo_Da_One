import test from 'node:test';
import assert from 'node:assert/strict';
import { alignTeachingVisualToExample, alignTeachingVisualsOnBoard } from './align-teaching-visual.mjs';
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

test('a restored chocolate board displays as a bar while a pizza reference stays circular', () => {
  const saved = [
    { id: 'example', kind: 'summary', title: 'Watch me · Chocolate Bar Analogy', content: 'Three mini-squares make one half.' },
    { id: 'chocolate', kind: 'teaching_visual', visual: pie },
    { id: 'pizza-example', kind: 'summary', title: 'Pizza cut into six slices', content: 'Half a pizza is three slices.' },
    { id: 'pizza', kind: 'teaching_visual', visual: pie },
  ];
  const displayed = alignTeachingVisualsOnBoard(saved);
  assert.equal(displayed[1].visual.kind, 'fraction_bar');
  assert.equal(displayed[1].visual.parts, 6);
  assert.equal(displayed[1].visual.value, 3);
  assert.equal(displayed[3].visual.kind, 'fraction_pie');
  assert.equal(saved[1].visual.kind, 'fraction_pie', 'saved scene remains untouched');
  assert.equal(displayed[3], saved[3], 'pizza reference is unchanged');
  assert.equal(alignTeachingVisualsOnBoard(displayed), displayed, 'rendering an aligned board is stable');
});

test('saved scenes are independent and unrelated boards retain their identity', () => {
  const previous = [{ id: 'old-example', kind: 'summary', title: 'Chocolate Bar Analogy' }];
  const next = [{ id: 'new-visual', kind: 'teaching_visual', visual: pie }];
  assert.equal(alignTeachingVisualsOnBoard(previous), previous);
  assert.equal(alignTeachingVisualsOnBoard(next), next);
});
