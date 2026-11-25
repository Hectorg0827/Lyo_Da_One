import test from 'node:test';
import assert from 'node:assert/strict';
import { isUncertainAnswerLabel } from './classroom-answer-options.mjs';

test('duplicate uncertainty choices are collapsed into the dedicated skip action', () => {
  for (const value of ["I'm not sure yet", 'I am not sure yet.', 'Todavía no lo sé', 'Aún no lo sé', 'No estoy seguro']) {
    assert.equal(isUncertainAnswerLabel(value), true, value);
  }
});

test('mathematical and misconception answer choices remain available', () => {
  for (const value of ['4/8', '4/16', '6', 'I am sure', 'I do not know the denominator']) {
    assert.equal(isUncertainAnswerLabel(value), false, value);
  }
});
