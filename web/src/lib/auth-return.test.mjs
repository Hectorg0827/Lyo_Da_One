import assert from 'node:assert/strict';
import test from 'node:test';
import { authReturnPath } from './auth-return.mjs';

test('return only to Test Prep and reject external or ambiguous destinations', () => {
  assert.equal(authReturnPath('?next=%2Ftest-prep'), '/test-prep');
  for (const search of ['', '?next=https%3A%2F%2Fevil.example', '?next=%2F%2Fevil.example',
    '?next=%2Ftest-prep%2F..%2Fauth', '?next=%2F%5Cevil.example']) {
    assert.equal(authReturnPath(search), '/');
  }
});
