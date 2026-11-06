import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

function createStackHarness(initial = []) {
  const items = initial.map(item => ({
    user_id: 12, item_type: 'course', title: 'Fractions', content_id: 'fractions',
    progress: 0, status: 'not_started', updated_at: '2026-11-05T20:00:00Z', ...item,
  }));
  const writes = [];
  const api = {
    ApiError: class ApiError extends Error {},
    getAccessToken: () => 'staging-test-token',
    request: async (endpoint, init = {}) => {
      if (init.method === 'POST') {
        const created = { id: items.length + 1, status: 'not_started', progress: 0, ...JSON.parse(init.body) };
        items.push(created);
        writes.push({ method: 'POST', body: JSON.parse(init.body) });
        return { ...created };
      }
      if (init.method === 'PUT') {
        const id = Number(endpoint.split('/').pop());
        const item = items.find(record => record.id === id);
        assert.ok(item, `missing item ${id}`);
        const body = JSON.parse(init.body);
        writes.push({ method: 'PUT', id, body });
        if (body.status) item.status = body.status;
        if (typeof body.progress === 'number') {
          item.progress = body.progress;
          if (item.progress === 1) item.status = 'completed';
          else if (item.progress > 0) item.status = 'in_progress';
        }
        return { ...item };
      }
      return { items: items.map(item => ({ ...item })), total: items.length, limit: 100, offset: 0 };
    },
  };
  const source = readFileSync(new URL('./stack.ts', import.meta.url), 'utf8');
  const context = { exports: {}, require: name => {
    if (name !== '@/lib/api') throw Error(`unexpected dependency ${name}`);
    return api;
  }, process: { env: {} }, URLSearchParams };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText, context);
  return { stack: context.exports, items, writes };
}

test('saved course stays not started until a successfully submitted checkpoint', async () => {
  const { stack, items, writes } = createStackHarness();
  const saved = await stack.upsertCourseOnStart('fractions', 'Fractions');
  assert.equal(saved.status, 'not_started');
  assert.equal(items[0].progress, 0);
  assert.deepEqual(writes.map(write => write.method), ['POST']);

  const started = await stack.markCourseInProgress('fractions');
  assert.equal(started.status, 'in_progress');
  assert.equal(started.progress, 0, 'a checkpoint is participation, not a completed skill');
  assert.deepEqual(JSON.parse(JSON.stringify(writes[1])), {
    method: 'PUT', id: 1, body: { status: 'in_progress' },
  });

  await stack.markCourseInProgress('fractions');
  assert.equal(writes.length, 2, 'later answers must not reissue status writes');
});

test('participation marker never rolls back completed or paused courses', async () => {
  const { stack, items, writes } = createStackHarness([
    { id: 1, content_id: 'finished', progress: 1, status: 'completed' },
    { id: 2, content_id: 'paused', progress: 0.2, status: 'paused' },
  ]);
  await stack.markCourseInProgress('finished');
  await stack.markCourseInProgress('paused');
  assert.deepEqual(items.map(item => item.status), ['completed', 'paused']);
  assert.equal(writes.length, 0);
});

test('unknown or invalid course marker does not create a duplicate card', async () => {
  const { stack, items, writes } = createStackHarness();
  assert.equal(await stack.markCourseInProgress('not-in-stacks'), null);
  assert.equal(await stack.markCourseInProgress('   '), null);
  assert.equal(items.length, 0);
  assert.equal(writes.length, 0);
});

test('later mastery updates preserve an in-progress zero-percent status', async () => {
  const { stack, items } = createStackHarness([{ id: 1 }]);
  await stack.markCourseInProgress('fractions');
  await stack.updateCourseProgress('fractions', 0);
  assert.equal(items[0].status, 'in_progress');
  await stack.updateCourseProgress('fractions', 0.25);
  assert.equal(items[0].progress, 0.25);
  await stack.updateCourseProgress('fractions', 1);
  assert.equal(items[0].status, 'completed');
});
