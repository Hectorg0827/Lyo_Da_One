import test from 'node:test';
import assert from 'node:assert/strict';
import {
  emptyTeachingRuntimeState,
  reduceTeachingPolicy,
  teachingStateSummary,
} from './teaching-runtime.mjs';

test('checks accumulate and explanation resets the check run', () => {
  let state = emptyTeachingRuntimeState();
  state = reduceTeachingPolicy(state, { action: 'diagnose' });
  state = reduceTeachingPolicy(state, { action: 'check_application' });
  assert.equal(state.consecutive_checks, 2);
  assert.equal(state.consecutive_explanations, 0);

  state = reduceTeachingPolicy(state, { action: 'demonstrate' });
  assert.equal(state.consecutive_checks, 0);
  assert.equal(state.consecutive_explanations, 1);
  assert.equal(state.last_action, 'demonstrate');
});

test('unknown policy events cannot poison client state', () => {
  const original = reduceTeachingPolicy(emptyTeachingRuntimeState(), { action: 'guide' });
  const next = reduceTeachingPolicy(original, { action: 'invented_action' });
  assert.deepEqual(next, original);
});

test('state summary carries teaching runtime and active course together', () => {
  const runtime = reduceTeachingPolicy(emptyTeachingRuntimeState(), { action: 'explain' });
  assert.deepEqual(teachingStateSummary(runtime, { topic: 'geometry' }), {
    teaching_runtime: runtime,
    active_course: { topic: 'geometry' },
  });
});
