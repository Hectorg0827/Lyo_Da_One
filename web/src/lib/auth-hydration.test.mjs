import assert from 'node:assert/strict';
import test from 'node:test';
import { hydrationFailureKind } from './auth-hydration.mjs';

test('429, 503 and network failures are retryable and not proof of logout', () => {
  for (const failure of [{status:429},{status:503},{status:500},new TypeError('Failed to fetch'),{status:0}]) {
    assert.equal(hydrationFailureKind(failure), 'transient');
  }
});
test('only authoritative failed authentication invalidates session', () => {
  assert.equal(hydrationFailureKind({status:401}), 'invalid_session');
  assert.equal(hydrationFailureKind({status:403}), 'invalid_session');
});
