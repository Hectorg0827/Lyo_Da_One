import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { fractionReadout, fractionSlicePath, isFractionState, resizeFraction, toggleFractionSlice } from './fraction-pie.mjs';
import { parseTeachingVisual } from './teaching-activity.mjs';

const block = JSON.parse(readFileSync(new URL('../../../Sources/Tests/Fixtures/SharedFractionPie.json', import.meta.url), 'utf8'));

test('the shared Chat and Test Prep payload is also a valid Classroom visual', () => {
  const visual = parseTeachingVisual(block.content.visual);
  assert.equal(visual.kind, 'fraction_pie');
  assert.equal(block.subtype, 'teaching_visual');
  assert.equal(block.metadata.source_surface, 'test_prep');
  assert.equal(block.content.items[0].detail, visual.description);
  assert.equal(fractionReadout(visual).fraction, '3/4');
  for (const invalid of [{ parts: 0 }, { parts: 21 }, { value: 5 }, { value: true }, { whole: Infinity }]) {
    assert.equal(parseTeachingVisual({ ...visual, ...invalid }), null);
  }
  assert.ok(parseTeachingVisual({ ...visual, parts: 1, value: 1 }));
});

test('equivalent fractions have the same value, with exact reduced forms', () => {
  const half = fractionReadout({ parts: 4, value: 2 });
  assert.deepEqual(half, { fraction: '2/4', reduced: '1/2', decimal: 0.5, percent: 50 });
  assert.equal(half.decimal, fractionReadout({ parts: 8, value: 4 }).decimal);
  assert.deepEqual(fractionReadout({ parts: 20, value: 0 }), { fraction: '0/20', reduced: '0/1', decimal: 0, percent: 0 });
  assert.deepEqual(fractionReadout({ parts: 1, value: 1 }), { fraction: '1/1', reduced: '1/1', decimal: 1, percent: 100 });
});

test('changing the denominator changes the slice size and bounds the numerator', () => {
  let state = { parts: 4, value: 3 };
  state = resizeFraction(state, 8);
  assert.equal(fractionReadout(state).fraction, '3/8');
  assert.equal(fractionReadout(state).percent, 37.5);
  state = resizeFraction(state, 2);
  assert.deepEqual(state, { parts: 2, value: 2 });
  assert.equal(fractionReadout(state).percent, 100);
  for (const invalid of [0, 21, 1.5, true, '4']) assert.equal(resizeFraction(state, invalid), null);
});

test('tapping non-adjacent slices changes their count without filling unrelated slices', () => {
  let selected = [0, 1, 2];
  selected = toggleFractionSlice(selected, 1, 4);
  assert.deepEqual(selected, [0, 2]);
  selected = toggleFractionSlice(selected, 3, 4);
  assert.deepEqual(selected, [0, 2, 3]);
  assert.equal(fractionReadout({ parts: 4, value: selected.length }).fraction, '3/4');
  assert.equal(toggleFractionSlice(selected, 4, 4), null);
});

test('all supported pies have finite SVG sectors, including the whole circle', () => {
  assert.equal((fractionSlicePath(0, 1).match(/ A /g) ?? []).length, 2);
  for (let parts = 1; parts <= 20; parts++) {
    for (let index = 0; index < parts; index++) {
      const path = fractionSlicePath(index, parts);
      assert.ok(path.endsWith(' Z'));
      assert.doesNotMatch(path, /NaN|Infinity/);
    }
    assert.equal(fractionSlicePath(parts, parts), '');
  }
  for (const state of [null, {}, { parts: 4, value: false }, { parts: 4, value: 5 }, { parts: 1e9, value: 1e9 }]) {
    assert.equal(isFractionState(state), false);
    assert.equal(fractionReadout(state), null);
  }
});
