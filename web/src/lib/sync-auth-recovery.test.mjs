import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire, Module } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { readFileSync } from 'node:fs';

const webRoot = fileURLToPath(new URL('../..', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const syncPath = path.join(webRoot, 'src/lib/sync.ts');

class FakeWebSocket {
  static OPEN = 1;
  static instances = [];
  readyState = 0;
  onopen = null;
  onmessage = null;
  onclose = null;
  onerror = null;
  constructor(url) { this.url = url; FakeWebSocket.instances.push(this); }
  open() { this.readyState = 1; this.onopen?.(); }
  closeWith(code) { this.readyState = 3; this.onclose?.({ code }); }
  message(value) { this.onmessage?.({ data: JSON.stringify(value) }); }
  close() { this.readyState = 3; }
}

function loadSync({ getAccessToken, refreshAccessToken }) {
  const source = readFileSync(syncPath, 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const mod = new Module(syncPath);
  mod.filename = syncPath;
  mod.paths = Module._nodeModulePaths(webRoot);
  const originalRequire = mod.require.bind(mod);
  mod.require = (name) => name === '@/lib/api'
    ? { getAccessToken, refreshAccessToken }
    : originalRequire(name);
  mod._compile(compiled, syncPath);
  return mod.exports.SyncClient;
}

function installBrowser() {
  const listeners = new Map();
  globalThis.window = {
    addEventListener: (name, callback) => listeners.set(name, callback),
    dispatchEvent: (event) => { listeners.get(event.type)?.(event); },
  };
  globalThis.navigator = { userAgent: 'Lyo test browser' };
  globalThis.WebSocket = FakeWebSocket;
  FakeWebSocket.instances = [];
}

test('expired sync auth refreshes once and reconnects with the new token', async () => {
  installBrowser();
  let token = 'expired-access';
  const SyncClient = loadSync({
    getAccessToken: () => token,
    refreshAccessToken: async () => {
      token = 'fresh-access';
      window.dispatchEvent(new Event('lyo:auth-token-updated'));
      return true;
    },
  });
  const client = new SyncClient();
  client.connect();
  const first = FakeWebSocket.instances[0];
  first.open();
  first.closeWith(4001);
  await new Promise(resolve => setImmediate(resolve));

  assert.equal(FakeWebSocket.instances.length, 2);
  assert.equal(new URL(FakeWebSocket.instances[1].url).searchParams.get('token'), 'fresh-access');
  client.disconnect();
});

test('failed sync auth refresh pauses stale-token reconnect until credentials update', async () => {
  installBrowser();
  let token = 'expired-access';
  const SyncClient = loadSync({
    getAccessToken: () => token,
    refreshAccessToken: async () => false,
  });
  const client = new SyncClient();
  client.connect();
  FakeWebSocket.instances[0].open();
  FakeWebSocket.instances[0].closeWith(4001);
  await new Promise(resolve => setImmediate(resolve));

  assert.equal(FakeWebSocket.instances.length, 1);
  token = 'new-login-access';
  window.dispatchEvent(new Event('lyo:auth-token-updated'));
  assert.equal(FakeWebSocket.instances.length, 2);
  client.disconnect();
});
