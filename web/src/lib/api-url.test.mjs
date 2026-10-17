import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveApiEndpoint } from './api-url.mjs';

test('legacy auth and new journey calls map to exactly one v1 prefix', () => {
  for (const base of ['https://api.lyoai.app', 'https://api.lyoai.app/api/v1', 'https://api.lyoai.app/api/v1/']) {
    assert.equal(resolveApiEndpoint(base, '/auth/login'), 'https://api.lyoai.app/api/v1/auth/login');
    assert.equal(resolveApiEndpoint(base, '/auth/me'), 'https://api.lyoai.app/api/v1/auth/me');
    assert.equal(resolveApiEndpoint(base, '/api/v1/me/coach/journeys'), 'https://api.lyoai.app/api/v1/me/coach/journeys');
    assert.equal(resolveApiEndpoint(base, '/api/v1/lyo2/chat/stream'), 'https://api.lyoai.app/api/v1/lyo2/chat/stream');
    assert.equal(resolveApiEndpoint(base, '/gamification/overview'), 'https://api.lyoai.app/api/v1/gamification/overview');
  }
});

test('queries and encoded IDs are preserved in URL joining', () => {
  assert.equal(resolveApiEndpoint('https://stage.example/api/v1', '/me/study_plans/state?profile_id=exam%2F42'),
    'https://stage.example/api/v1/me/study_plans/state?profile_id=exam%2F42');
});

test('rejects external redirects, protocol-relative endpoints and credentials in API bases', () => {
  for (const endpoint of ['https://malicious.test', '//malicious.test/steal', 'auth/login']) {
    assert.throws(() => resolveApiEndpoint('https://stage.example', endpoint), /Invalid API endpoint/);
  }
  for (const base of ['javascript:alert(1)', 'https://u:password@stage.example', 'https://stage.example/something']) {
    assert.throws(() => resolveApiEndpoint(base, '/auth/login'), /Invalid API base/);
  }
});
