import assert from 'node:assert/strict';
import test from 'node:test';
import { authReturnPath, authSwitchHref } from './auth-return.mjs';

test('return only to Test Prep and reject external or ambiguous destinations', () => {
  assert.equal(authReturnPath('?next=%2Ftest-prep'), '/test-prep');
  for (const search of ['', '?next=https%3A%2F%2Fevil.example', '?next=%2F%2Fevil.example',
    '?next=%2Ftest-prep%2F..%2Fauth', '?next=%2F%5Cevil.example']) {
    assert.equal(authReturnPath(search), '/');
  }
});

test('an event invite link survives login, and nothing that only looks like one', () => {
  const token = 'Ab3_x-9ZqLmN0pQrStUvWx';
  assert.equal(authReturnPath(`?next=%2Fcommunity%2Finvite%2F${token}`), `/community/invite/${token}`);
  for (const next of [
    '/community/invite/short',
    `/community/invite/${token}/../../auth`,
    `/community/invite/${token}?x=1`,
    `//evil.example/community/invite/${token}`,
    `https://evil.example/community/invite/${token}`,
    '/community/invite/has%20space',
  ]) {
    assert.equal(authReturnPath(`?next=${encodeURIComponent(next)}`), '/', next);
  }
  assert.equal(authSwitchHref('/auth/signup', `?next=%2Fcommunity%2Finvite%2F${token}`), `/auth/signup?next=%2Fcommunity%2Finvite%2F${token}`);
  assert.equal(authSwitchHref('/auth/login', '?next=%2Ftest-prep'), '/auth/login?next=%2Ftest-prep');
  assert.equal(authSwitchHref('/auth/login', ''), '/auth/login');
});
