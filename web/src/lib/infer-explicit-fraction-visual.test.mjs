import test from 'node:test';
import assert from 'node:assert/strict';
import { inferExplicitFractionVisual } from './infer-explicit-fraction-visual.mjs';
import { parseTeachingVisual } from './teaching-activity.mjs';

test('exact staging lesson narration recovers five equal bar partitions and three shaded', () => {
  const narration = 'Look at the fraction bar model. A single whole rectangle is divided into 5 equal parts, with 3 of those parts shaded blue. Which fraction correctly represents the shaded portion of the rectangle? A) 2/5 B) 3/5 C) 5/3 D) 3/8';
  const visual = inferExplicitFractionVisual(narration);
  assert.ok(visual);
  assert.equal(visual.kind, 'fraction_bar');
  assert.equal(visual.parts, 5);
  assert.equal(visual.value, 3);
  assert.deepEqual(parseTeachingVisual(visual), visual, 'the inferred model must satisfy the actual renderer contract');
  assert.doesNotMatch(visual.caption, /2\/5|5\/3|3\/8/, 'answer choices must not appear in visual labels');
});

test('spoken number words and an explicit pie construct a circular visual', () => {
  const visual = inferExplicitFractionVisual('A circle is split into four equal sectors. One sector is shaded blue.');
  assert.equal(visual?.kind, 'fraction_pie');
  assert.equal(visual?.parts, 4);
  assert.equal(visual?.value, 1);
});

test('the model must explicitly provide shape, equal partitions, and shaded count', () => {
  for (const text of [
    'Look at the fraction bar model.',
    'Look at this fraction bar model. Which is correct? A) 3/5 B) 1/5 C) 2/7',
    'A rectangle is divided into five equal parts. Which fraction is shaded?',
    'Three parts of a fraction bar are shaded blue. How many parts are there?',
    'A rectangle is divided into five parts. Three of those parts are shaded.',
    'A rectangle is divided into 5 equal parts, with several parts shaded.',
    'A whole is divided into five equal parts with three shaded.',
    'Which of 3/5, 2/5, 1/5 shows the shaded rectangle?',
  ]) assert.equal(inferExplicitFractionVisual(text), null, text);
});

test('answer choice descriptions must not supply missing model facts', () => {
  assert.equal(inferExplicitFractionVisual(
    'Look at the bar. Which answer describes it? A) A rectangle divided into 5 equal parts with 3 parts shaded. B) A rectangle divided into 3 equal parts with 2 shaded.'
  ), null);
  assert.equal(inferExplicitFractionVisual(
    'Look at the fraction bar. A)A rectangle is divided into 5 equal parts, 3 parts shaded. B)A rectangle is divided into 4 equal parts, 2 shaded.'
  ), null, 'unspaced A) choices must also be ignored');
});

test('conflicting counts, multiple figures, estimates, and impossible fractions refuse a fabricated diagram', () => {
  for (const text of [
    'A rectangle is divided into five equal parts. Three parts are shaded, but two parts are shaded in the same model.',
    'A rectangle is divided into five equal parts, then divided into four equal parts. Three parts are shaded.',
    'A rectangle is divided into five equal parts with three parts shaded; a circle is also divided into five equal parts with three shaded.',
    'A rectangle is divided into 3 equal parts with 5 parts shaded.',
    'A rectangle is divided into 25 equal parts with 3 parts shaded.',
    'A rectangle is divided into about 5 equal parts with 3 parts shaded.',
    'A rectangle is divided into five equal parts with three parts not shaded.',
  ]) assert.equal(inferExplicitFractionVisual(text), null, text);
});

test('safe alternate phrasings still use explicit counts, never fractions in question choices', () => {
  for (const text of [
    'The fraction bar is split evenly into 5 pieces, and 3 pieces are shaded. Which is right? A. 1/5 B. 3/5',
    'A rectangle is divided into 5 parts of equal size. 3 are shaded.',
    'A bar is partitioned into five equally sized sections. Three of the sections are highlighted.',
  ]) {
    const visual = inferExplicitFractionVisual(text);
    assert.equal(visual?.parts, 5, text);
    assert.equal(visual?.value, 3, text);
    assert.equal(visual?.kind, 'fraction_bar', text);
  }
});
