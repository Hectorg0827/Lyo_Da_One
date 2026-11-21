import test from 'node:test';
import assert from 'node:assert/strict';
import { isPracticeAnswerCorrect as correct } from './quiz-answer.mjs';

const question = (answer, type = 'multiple_choice') => ({
  type, correctAnswer: answer, options: ['3', '4', '5'], question: '2 + 2?',
});

test('numeric option keys score selected index correctly', () => {
  assert.equal(correct(question(1), 1), true);
  assert.equal(correct(question(1), 0), false);
  assert.equal(correct(question(1), '4'), true);
});

test('literal option text and letter keys align with feedback', () => {
  assert.equal(correct(question('4'), 1), true);
  assert.equal(correct(question('B'), 1), true);
  assert.equal(correct(question('A'), 1), false);
  assert.equal(correct(question('1'), 1), true);
});

test('literal values win when an option text itself is numeric or a letter', () => {
  assert.equal(correct({ type: 'multiple_choice', options: ['1', '2'], correctAnswer: '1' }, 0), true);
  assert.equal(correct({ type: 'multiple_choice', options: ['A', 'B'], correctAnswer: 'A' }, 0), true);
});

test('true/false comparisons tolerate case and numeric booleans', () => {
  assert.equal(correct(question('true', 'true_false'), 'True'), true);
  assert.equal(correct(question('FALSE', 'true_false'), 'False'), true);
  assert.equal(correct(question(0, 'true_false'), 'True'), false);
  assert.equal(correct(question(0, 'true_false'), 'False'), true);
});

test('wrong, absent, invalid and unsupported answers do not count as correct', () => {
  assert.equal(correct(question(1), undefined), false);
  assert.equal(correct(question(3), 1), false);
  assert.equal(correct(question('Z'), 0), false);
  assert.equal(correct(question(1), -1), false);
  assert.equal(correct({ type: 'multiple_choice', options: [], correctAnswer: 0 }, 0), false);
  assert.equal(correct({ type: 'code', correctAnswer: 'print(1)' }, 'print(1)'), false);
});

test('fill blank accepts canonical text but not empty responses', () => {
  assert.equal(correct(question('Quadratic', 'fill_blank'), ' quadratic '), true);
  assert.equal(correct(question('Quadratic', 'fill_blank'), ''), false);
});
