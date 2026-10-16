import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire, Module } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { hydrationFailureKind } from './auth-hydration.mjs';

const webRoot = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const sourcePath = path.join(webRoot, 'src/stores/auth-store.ts');
let token = 'access-original';
let currentMe = async () => ({ id: 7, email: 'learner7@example.test' });
const api = {
  auth: {
    me: async () => currentMe(),
    login: async () => ({ user: { id: 8, email: 'new@example.test' }, accessToken: 'new-token' }),
    register: async () => ({ user: { id: 8 }, accessToken: 'new-token' }),
    logout: async () => {},
  },
  gamification: { overview: async () => ({}) },
};
const mod = new Module(sourcePath);
mod.filename = sourcePath;
mod.paths = Module._nodeModulePaths(webRoot);
const mocks = {
  '@/lib/api': {
    api, getAccessToken: () => token,
    clearTokens: () => { token = null; },
  },
  '@/lib/auth-hydration.mjs': { hydrationFailureKind },
};
const originalRequire = mod.require.bind(mod);
mod.require = (name) => mocks[name] || originalRequire(name);
mod._compile(ts.transpileModule(readFileSync(sourcePath, 'utf8'), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText, sourcePath);
const store = mod.exports.useAuthStore;
const defaultState = {
  user: null, token: null, isAuthenticated: false,
  isLoading: false, authVerificationError: false,
};
const failure = (status) => Object.assign(new Error('temporary failure'), {status});
const deferred = () => {
  let resolve;
  const promise = new Promise(r => { resolve = r; });
  return {promise, resolve};
};
function reset() {
  store.setState(defaultState);
  token = 'access-original';
  currentMe = async () => ({ id: 7, email: 'learner7@example.test' });
}
test('429/503 keep a previously verified learner and their token', async () => {
  reset();
  await store.getState().hydrate();
  assert.equal(store.getState().user.id, 7);
  for (const code of [429, 503]) {
    currentMe = async () => { throw failure(code); };
    await store.getState().hydrate();
    assert.equal(store.getState().user.id, 7);
    assert.equal(store.getState().isAuthenticated, true);
    assert.equal(store.getState().authVerificationError, true);
    assert.equal(token, 'access-original');
  }
});
test('cold-start 429 retains token but does not invent an authenticated identity', async () => {
  reset();
  currentMe = async () => { throw failure(429); };
  await store.getState().hydrate();
  assert.equal(store.getState().user, null);
  assert.equal(store.getState().isAuthenticated, false);
  assert.equal(store.getState().authVerificationError, true);
  assert.equal(token, 'access-original');
  currentMe = async () => ({id:7,email:'learner7@example.test'});
  await store.getState().hydrate();
  assert.equal(store.getState().user.id, 7);
  assert.equal(store.getState().authVerificationError, false);
});
test('authoritative invalid session still clears old token and identity', async () => {
  reset();
  await store.getState().hydrate();
  currentMe = async () => { throw failure(401); };
  await store.getState().hydrate();
  assert.equal(token, null);
  assert.equal(store.getState().user, null);
  assert.equal(store.getState().isAuthenticated, false);
});
test('late hydration cannot overwrite an explicit newer login', async () => {
  reset();
  const pending = deferred();
  currentMe = () => pending.promise;
  const old = store.getState().hydrate();
  await store.getState().login('new@example.test', 'synthetic');
  assert.equal(store.getState().user.id, 8);
  pending.resolve({id:7});
  await old;
  assert.equal(store.getState().user.id, 8);
});
test('a late /auth/me result never restores a learner after logout', async () => {
  reset();
  const pending = deferred();
  currentMe = () => pending.promise;
  const loading = store.getState().hydrate();
  store.getState().logout();
  pending.resolve({id:7});
  await loading;
  assert.equal(store.getState().isAuthenticated, false);
  assert.equal(store.getState().user, null);
  assert.equal(token, null);
});
