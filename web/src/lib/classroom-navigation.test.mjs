import test from 'node:test';
import assert from 'node:assert/strict';
import { classroomNextAction } from './classroom-navigation.mjs';

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
