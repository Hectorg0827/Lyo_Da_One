import test from 'node:test';
import assert from 'node:assert/strict';
import { quizOptionIsSelected } from './classroom-quiz-selection.mjs';

const duplicateOptions = [
  { id: 'choice-a', label: '2/3' },
  { id: 'choice-b', label: '2/3' },
];

test('duplicate labels highlight only the selected option ID', () => {
  assert.equal(quizOptionIsSelected(duplicateOptions[0], duplicateOptions, '2/3', 'choice-b'), false);
  assert.equal(quizOptionIsSelected(duplicateOptions[1], duplicateOptions, '2/3', 'choice-b'), true);
});

test('legacy ambiguous label does not falsely highlight multiple choices', () => {
  assert.equal(quizOptionIsSelected(duplicateOptions[0], duplicateOptions, '2/3'), false);
  assert.equal(quizOptionIsSelected(duplicateOptions[1], duplicateOptions, '2/3'), false);
});

test('legacy unique label restores the correct visual selection', () => {
  const options = [{ id: 'x', label: 'A' }, { id: 'y', label: 'B' }];
  assert.equal(quizOptionIsSelected(options[0], options, 'B'), false);
  assert.equal(quizOptionIsSelected(options[1], options, 'B'), true);
});

test('unanswered options stay unselected', () => {
  assert.equal(quizOptionIsSelected(duplicateOptions[0], duplicateOptions), false);
});
