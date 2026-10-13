import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('auth hydration distinguishes transient failures from invalid credentials', () => {
  const store = read('../stores/auth-store.ts');
  assert.match(store, /hydrationFailureKind\(error\) === 'invalid_session'/);
  assert.match(store, /authVerificationError: Boolean\(current\)/);
  assert.match(store, /if \(version !== authVersion\) return/);
  assert.match(store, /getAccessToken\(\)/);
});

test('Test Prep prompts a retry instead of losing its deep-linked exam after transient auth', () => {
  const page = read('../app/(main)/test-prep/page.tsx');
  assert.match(page, /Session verification unavailable/);
  assert.match(page, /Retry verification/);
  assert.match(page, /void hydrate\(\)/);
  assert.match(page, /query\.get\('profileId'\)/);
});

test('scheduled exam handoff does not award grades or quietly replace original profile', () => {
  const page = read('../app/(main)/test-prep/page.tsx');
  const entry = read('../components/coach/CoachMissionEntry.tsx');
  assert.match(page, /session=\{session\}/);
  assert.match(page, /returnedSessionId/);
  assert.match(entry, /studySessionJourneyPlan/);
  assert.doesNotMatch(entry, /completeSession\(/);
});


test('old 401 and refresh replies cannot clear or replace credentials for a newer account', () => {
  const api = read('./api.ts');
  assert.match(api, /getAccessToken\(\) !== requestAccessToken/);
  assert.match(api, /Session changed during request/);
  assert.match(api, /getRefreshToken\(\) !== refresh/);
  assert.match(api, /localStorage\.removeItem\('lyo_refresh_token'\)/);
});
