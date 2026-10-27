import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  ACCOUNT_DELETION_METHOD,
  ACCOUNT_DELETION_PATH,
  accountDeletionFailure,
  accountDeletionSucceeded,
  clearLocalAccountData,
  requestAccountDeletion,
} from './account-deletion.mjs';

function fakeFetch(...statuses) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    const next = statuses.shift();
    if (next instanceof Error) throw next;
    return { status: next };
  };
  return { impl, calls };
}

function memoryStorage(entries) {
  const map = new Map(Object.entries(entries));
  return {
    get length() { return map.size; },
    key: (index) => [...map.keys()][index] ?? null,
    removeItem: (key) => map.delete(key),
    keys: () => [...map.keys()],
  };
}

test('the contract is DELETE /auth/me, and only 200 or 204 count as deleted', () => {
  assert.equal(ACCOUNT_DELETION_METHOD, 'DELETE');
  assert.equal(ACCOUNT_DELETION_PATH, '/auth/me');
  assert.equal(accountDeletionSucceeded(200), true);
  assert.equal(accountDeletionSucceeded(204), true);
  for (const status of [0, 201, 202, 400, 401, 404, 500]) assert.equal(accountDeletionSucceeded(status), false, String(status));
});

test('the request sends the bearer token, no body, to the configured API', async () => {
  const { impl, calls } = fakeFetch(204);
  const result = await requestAccountDeletion({ apiUrl: 'https://staging.example/', getToken: () => 'tok', fetchImpl: impl });
  assert.deepEqual(result, { ok: true, status: 204 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://staging.example/auth/me');
  assert.equal(calls[0].init.method, 'DELETE');
  assert.equal(calls[0].init.headers.Authorization, 'Bearer tok');
  assert.equal(calls[0].init.body, undefined);
});

test('an expired token is refreshed once, then the deletion is retried', async () => {
  let token = 'old';
  const { impl, calls } = fakeFetch(401, 200);
  const result = await requestAccountDeletion({
    apiUrl: 'https://api',
    getToken: () => token,
    refresh: async () => { token = 'new'; return true; },
    fetchImpl: impl,
  });
  assert.equal(result.ok, true);
  assert.deepEqual(calls.map((call) => call.init.headers.Authorization), ['Bearer old', 'Bearer new']);
});

test('failures are reported, never thrown, and say the account still exists', async () => {
  const server = await requestAccountDeletion({ apiUrl: 'https://api', getToken: () => 't', fetchImpl: fakeFetch(500).impl });
  assert.equal(server.ok, false);
  assert.match(server.message, /not deleted/);
  const offline = await requestAccountDeletion({ apiUrl: 'https://api', getToken: () => 't', fetchImpl: fakeFetch(new TypeError('offline')).impl });
  assert.deepEqual([offline.ok, offline.status], [false, 0]);
  assert.match(offline.message, /connection/);
  const noToken = fakeFetch(204);
  const signedOut = await requestAccountDeletion({ apiUrl: 'https://api', getToken: () => null, fetchImpl: noToken.impl });
  assert.equal(signedOut.ok, false);
  assert.equal(noToken.calls.length, 0, 'no request without a session');
  assert.match(accountDeletionFailure(401), /Log in again/);
  assert.match(accountDeletionFailure(429), /Too many attempts/);
});

test('local cleanup removes every LYO key and nothing else', () => {
  const storage = memoryStorage({ lyo_token: 'a', lyo_refresh_token: 'b', 'lyo_classroom_session:x': 'c', other_site: 'd' });
  clearLocalAccountData(storage);
  assert.deepEqual(storage.keys(), ['other_site']);
  clearLocalAccountData(null);
});

test('Settings deletes only after confirmation and clears data only after success', () => {
  const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
  const settings = read('../app/(main)/settings/page.tsx');
  const store = read('../stores/auth-store.ts');
  assert.ok(settings.includes('Delete account'));
  assert.ok(settings.includes('This is permanent and cannot be undone.'));
  assert.ok(settings.includes('setConfirmingDelete(true)'), 'the first button only opens the confirmation');
  assert.ok(settings.includes("router.replace('/auth/login')"));
  assert.ok(!settings.includes('does not currently expose a verified account-deletion endpoint'));
  const success = store.indexOf('if (result.ok)');
  assert.ok(success > 0 && store.indexOf('clearLocalAccountData(window.localStorage)') > success,
    'local data is cleared inside the success branch');
});
