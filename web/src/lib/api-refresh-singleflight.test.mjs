import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import * as authFailure from './auth-failure.mjs';

// Exercise the actual TypeScript request/refresh implementation. The HTTP
// responses are controlled here so JWT expiry is deterministic: moving
// Date.now() would not expire a server-signed token or cause an HTTP 401.
const compiled = ts.transpileModule(
  readFileSync(new URL('./api.ts', import.meta.url), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } },
).outputText;

function deferred() {
  let resolve;
  const promise = new Promise((done) => { resolve = done; });
  return { promise, resolve };
}

const settle = async () => {
  for (let i = 0; i < 8; i += 1) await Promise.resolve();
};

function response(status, body) {
  return { status, ok: status >= 200 && status < 300, json: async () => body };
}

function harness({ failRefresh = false } = {}) {
  const values = new Map([
    ['lyo_token', 'expired-access'],
    ['lyo_refresh_token', 'original-refresh'],
  ]);
  const localStorage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
  const calls = [];
  const refreshStarted = deferred();
  const releaseRefresh = deferred();
  const fetch = async (url, init = {}) => {
    const call = { url, method: init.method ?? 'GET', authorization: init.headers?.Authorization, body: init.body };
    calls.push(call);
    if (url.endsWith('/auth/refresh')) {
      refreshStarted.resolve();
      await releaseRefresh.promise;
      return failRefresh
        ? response(401, { detail: 'Refresh expired' })
        : response(200, { access_token: 'renewed-access', refresh_token: 'rotated-refresh' });
    }
    if (call.authorization === 'Bearer expired-access') return response(401, { detail: 'Expired' });
    if (call.authorization === 'Bearer renewed-access') {
      return response(200, { path: new URL(url).pathname, method: call.method });
    }
    return response(401, { detail: 'No bearer access token' });
  };
  const window = { localStorage, location: { href: 'https://staging.example/classroom' } };
  const exports = {};
  const context = {
    exports,
    process: { env: { NEXT_PUBLIC_API_URL: 'https://staging.example' } },
    require: (name) => {
      if (name === '@/lib/auth-failure.mjs') return authFailure;
      if (name === '@/lib/account-deletion.mjs') return { requestAccountDeletion: async () => {} };
      throw new Error(`Unexpected dependency in API test: ${name}`);
    },
    fetch, localStorage, window, URL, URLSearchParams, AbortController,
    console,
  };
  vm.runInNewContext(compiled, context, { filename: 'api.ts' });
  return { api: exports, calls, values, window, refreshStarted: refreshStarted.promise,
    releaseRefresh: () => releaseRefresh.resolve() };
}

test('concurrent stack GET and TTS POST share one rotating refresh and retry with the new access token', async () => {
  const h = harness();
  const getStack = h.api.request('/api/v1/stack/items', { optionalAuth: true });
  const postTts = h.api.request('/api/v1/tts/synthesize/stream', {
    method: 'POST', body: JSON.stringify({ text: 'Hello class', voice: 'teacher' }),
  });

  await h.refreshStarted;
  await settle();
  assert.equal(h.calls.filter((call) => call.url.endsWith('/auth/refresh')).length, 1,
    'parallel 401s must not rotate the same refresh token twice');
  assert.equal(h.calls.filter((call) => call.authorization === 'Bearer expired-access').length, 2);

  h.releaseRefresh();
  const [stack, speech] = await Promise.all([getStack, postTts]);
  assert.equal(stack.path, '/api/v1/stack/items');
  assert.equal(speech.method, 'POST');
  assert.equal(h.values.get('lyo_token'), 'renewed-access');
  assert.equal(h.values.get('lyo_refresh_token'), 'rotated-refresh');
  assert.equal(h.window.location.href, 'https://staging.example/classroom');

  const retried = h.calls.filter((call) => call.authorization === 'Bearer renewed-access');
  assert.equal(retried.length, 2);
  assert.deepEqual(retried.map((call) => call.method).sort(), ['GET', 'POST']);
  assert.equal(retried.find((call) => call.method === 'POST').body, JSON.stringify({ text: 'Hello class', voice: 'teacher' }),
    'the protected POST must preserve its body across the refresh retry');
});

test('failed refresh on supplementary stack sync cannot clear tokens or evict an active classroom', async () => {
  const h = harness({ failRefresh: true });
  const pending = h.api.request('/api/v1/stack/items', { optionalAuth: true });
  await h.refreshStarted;
  h.releaseRefresh();
  await assert.rejects(pending, (error) => error.status === 401 && /not signed in/i.test(error.message));
  assert.equal(h.values.get('lyo_token'), 'expired-access');
  assert.equal(h.values.get('lyo_refresh_token'), 'original-refresh');
  assert.equal(h.window.location.href, 'https://staging.example/classroom');
});

test('failed refresh on required API access clears the unusable session and opens sign-in', async () => {
  const h = harness({ failRefresh: true });
  const pending = h.api.request('/api/v1/me');
  await h.refreshStarted;
  h.releaseRefresh();
  await assert.rejects(pending, (error) => error.status === 401 && /session expired/i.test(error.message));
  assert.equal(h.values.has('lyo_token'), false);
  assert.equal(h.values.has('lyo_refresh_token'), false);
  assert.equal(h.window.location.href, '/auth/login');
});
