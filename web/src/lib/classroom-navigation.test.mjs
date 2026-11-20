import test from 'node:test';
import assert from 'node:assert/strict';
import { classroomCompletionExitReady, classroomNextAction } from './classroom-navigation.mjs';

test('answered question stays navigable without resubmitting an answer', () => {
  assert.deepEqual(classroomNextAction({ live: true, waiting: true }), {
    type: 'waiting', label: 'Preparing next step…', disabled: true,
  });
  assert.deepEqual(classroomNextAction({ live: true, readyToContinue: true }), {
    type: 'continue', label: 'Continue', disabled: false,
  });
  assert.deepEqual(classroomNextAction({ live: true, readyToContinue: true, continueLabel: 'Retry this step' }), {
    type: 'continue', label: 'Retry this step', disabled: false,
  });
});

test('interrupted transport does not pretend to prepare a new teaching step', () => {
  assert.deepEqual(classroomNextAction({ waiting: true, live: false }), {
    type: 'waiting', label: 'Restoring lesson…', disabled: true,
  });
});

test('history navigation is always local and takes precedence over loading', () => {
  assert.deepEqual(classroomNextAction({ viewingHistory: true, live: true, waiting: true }), {
    type: 'history', label: 'Next board', disabled: false,
  });
});

test('the learner can skip narration or retry a stalled teacher', () => {
  assert.equal(classroomNextAction({ live: true, narrating: true, waiting: true }).type, 'skip');
  assert.equal(classroomNextAction({ live: true, stalled: true, waiting: true }).type, 'retry');
});

test('unanswered work never offers a duplicate continuation', () => {
  assert.equal(classroomNextAction({ live: true, hasCheckpoint: true }).disabled, true);
  assert.equal(classroomNextAction({ live: true, hasPrompt: true }).type, 'answer');
});

test('completed skills and a recap offer an exit without changing the next lesson action', () => {
  const completed = { progressCurrent: 1, progressTotal: 1, board: [{ kind: 'summary', title: 'What you practised' }] };
  assert.equal(classroomCompletionExitReady(completed), true);
  assert.equal(classroomNextAction({ live: true, readyToContinue: true, continueLabel: 'Try a fresh example' }).label, 'Try a fresh example');
  assert.equal(classroomCompletionExitReady({ ...completed, progressTotal: 2 }), false);
  assert.equal(classroomCompletionExitReady({ ...completed, board: [{ kind: 'quiz', answered: true }] }), false);
});

test('completion exit remains unavailable during an unfinished checkpoint or transition', () => {
  const completed = { progressCurrent: 1, progressTotal: 1, board: [{ kind: 'summary' }] };
  assert.equal(classroomCompletionExitReady({ ...completed, hasCheckpoint: true }), false);
  assert.equal(classroomCompletionExitReady({ ...completed, hasPrompt: true }), false);
  assert.equal(classroomCompletionExitReady({ ...completed, waiting: true }), false);
  assert.equal(classroomCompletionExitReady({ ...completed, viewingHistory: true }), false);
  assert.equal(classroomCompletionExitReady({ progressCurrent: 0, progressTotal: 0, board: [] }), false);
});
