import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import Module, { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { JSDOM } from 'jsdom';

const webRoot = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const dom = new JSDOM('<!doctype html><body></body>', { url: 'http://localhost/test-prep' });
Object.assign(globalThis, { window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, IS_REACT_ACT_ENVIRONMENT: true });
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');
const api = {};
const mocks = {
  '@/lib/api': { api },
  '@/stores/auth-store': { useAuthStore: () => ({ isAuthenticated: true, isLoading: false }) },
  'next/link': { default: ({ children, ...props }) => React.createElement('a', props, children) },
  'next/navigation': { useRouter: () => ({ push: () => {}, replace: () => {}, back: () => {} }) },
};
const modules = new Map();
// Render the actual page, reducer, controls and schedule. Only network and
// sign-in state are replaced, so async selection defects are observable.
function load(filename) {
  if (modules.has(filename)) return modules.get(filename).exports;
  const mod = new Module(filename);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(webRoot);
  modules.set(filename, mod);
  mod.require = name => {
    if (mocks[name]) return mocks[name];
    if (name.startsWith('@/') || name.startsWith('./')) {
      const base = name.startsWith('@/') ? path.join(webRoot, 'src', name.slice(2))
        : path.resolve(path.dirname(filename), name);
      if (base.endsWith('.mjs')) return require(base);
      const file = ['.tsx', '.ts'].map(ext => base + ext).find(existsSync);
      if (file) return load(file);
    }
    return require(name);
  };
  mod._compile(ts.transpileModule(readFileSync(filename, 'utf8'), { compilerOptions: {
    jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, filename);
  return mod.exports;
}
const Page = load(path.join(webRoot, 'src/app/(main)/test-prep/page.tsx')).default;

function exam(id, subject, hasPlan = true) {
  return { profile: { id, subject, test_date: '2026-12-01', topics: [{ name: subject, weight: 1, confidence: 5 }],
    materials: [], intake_complete: hasPlan, intake_transcript: [], daily_minutes_available: 25,
    study_days_per_week: 5 }, timezone: 'UTC', revision: 0,
    plan: hasPlan ? { id: `${id}-plan`, status: 'active', weekly_milestones: [] } : null,
    sessions: hasPlan ? [{ id: `${id}-session`, topic: `${subject} practice`, status: 'scheduled',
      scheduled_at: '2026-11-01T17:00:00', duration_minutes: 25, session_type: 'practice',
      concept_id: `${id}-concept` }] : [] };
}
function setup() {
  window.history.replaceState({}, '', '/test-prep');
  const exams = { algebra: exam('algebra', 'Algebra'), biology: exam('biology', 'Biology'),
    chemistry: exam('chemistry', 'Chemistry', false) };
  const calls = { state: [], intake: [], start: [], generate: [] };
  api.testPrep = {
    state: async id => { calls.state.push(id); return exams[id ?? 'algebra']; },
    profiles: async () => Object.values(exams).map(s => s.profile),
    readiness: async id => ({ subject: exams[id.replace('-plan', '')].profile.subject,
      readiness: 0.8, topics_assessed: 1, topics_total: 1, days_remaining: 15,
      topics: [], focus_next: [] }),
    todaySessions: async () => Object.values(exams).flatMap(s => s.sessions),
    startNew: async requestId => { calls.start.push(requestId); return { profile_id: 'chemistry', created: true }; },
    intakeTurn: async (...args) => { calls.intake.push(args); return {
      test_profile_id: args[1], message_to_user: 'What date is your test?', intake_complete: false }; },
    generatePlan: async id => { calls.generate.push(id); return { plan_id: `${id}-plan` }; },
    editProfile: async () => ({ needs_plan: false }),
  };
  api.coach = { today: async () => ({ active_goals: [], mission: [], readiness: {} }) };
  api.media = { upload: async () => ({ url: '/notes.pdf' }) };
  return { exams, calls };
}
async function mount(t) {
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  let closed = false;
  const close = async () => { if (!closed) { await act(async () => root.unmount()); container.remove(); closed = true; } };
  t.after(close);
  await act(async () => root.render(React.createElement(Page)));
  return { container, close };
}
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; });
  return { promise, resolve, reject }; };
const newButton = view => [...view.container.querySelectorAll('button')].find(b => b.textContent === '+ New test');
const title = view => view.container.querySelector('h1')?.textContent;
function selectEvent(control, id) { control.value = id; control.dispatchEvent(new window.Event('change', { bubbles: true })); }
async function choose(view, id) { await act(async () => selectEvent(view.container.querySelector('select'), id)); }
async function answer(view, value) {
  const input = view.container.querySelector('[aria-label="Your answer"]');
  await act(async () => {
    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, value);
    input.dispatchEvent(new window.Event('input', { bubbles: true }));
  });
}
async function send(view) { await act(async () => view.container.querySelector('[aria-label="Send"]').click()); }

test('New test creates an independent intake and sends its explicit profile ID', async t => {
  const { calls } = setup();
  const view = await mount(t);
  assert.equal(title(view), 'Algebra');
  await act(async () => newButton(view).click());
  assert.equal(title(view), 'Tell me about your test');
  assert.equal(new URL(window.location.href).searchParams.get('profileId'), 'chemistry');
  assert.equal(calls.start.length, 1);
  assert.ok(!view.container.textContent.includes('Algebra practice'));
  await answer(view, 'My test is chemistry');
  await send(view);
  assert.equal(calls.intake[0][1], 'chemistry');
});

test('switching exam cannot retain the old readiness or session on detail failures', async t => {
  setup();
  const view = await mount(t);
  api.testPrep.readiness = async () => { throw new Error('offline'); };
  api.testPrep.todaySessions = async () => { throw new Error('offline'); };
  await choose(view, 'biology');
  assert.equal(title(view), 'Biology');
  assert.equal(new URL(window.location.href).searchParams.get('profileId'), 'biology');
  assert.ok(!view.container.textContent.includes('Algebra practice'));
  assert.ok(!view.container.textContent.includes('80%'));
  assert.ok(view.container.textContent.includes('could not load today'));
});

test('refresh restores a selected exam before making the first state request', async t => {
  const { calls } = setup();
  window.history.replaceState({}, '', '/test-prep?profileId=biology');
  const view = await mount(t);
  assert.equal(calls.state[0], 'biology');
  assert.equal(title(view), 'Biology');
});

test('selected completed or archived history keeps its schedule without reopening old sessions', async t => {
  const { exams } = setup();
  exams.algebra.plan.status = 'completed';
  exams.biology.plan.status = 'archived';
  const view = await mount(t);
  assert.equal(title(view), 'Algebra');
  assert.ok(view.container.textContent.includes('Algebra practice'));
  assert.ok(![...view.container.querySelectorAll('a')].some(a => a.textContent === 'Start session'));
  await choose(view, 'biology');
  assert.equal(title(view), 'Biology');
  assert.ok(view.container.textContent.includes('Biology practice'));
  assert.ok(![...view.container.querySelectorAll('a')].some(a => a.textContent === 'Start session'));
});

test('ordinary entry upgrades a legacy completed-profile snapshot to explicit history', async t => {
  const { exams, calls } = setup();
  exams.algebra.plan.status = 'completed';
  api.testPrep.state = async id => {
    calls.state.push(id);
    return id ? exams[id] : { ...exams.algebra, plan: null, sessions: [] };
  };
  const view = await mount(t);
  assert.deepEqual(calls.state, [undefined, 'algebra']);
  assert.equal(title(view), 'Algebra');
  assert.ok(view.container.textContent.includes('Algebra practice'));
  assert.equal(view.container.querySelector('[aria-label="Your answer"]'), null);
});

test('late state from a rapid earlier selection cannot overwrite the latest exam', async t => {
  const { exams } = setup();
  const view = await mount(t);
  const biology = deferred(), chemistry = deferred();
  api.testPrep.state = id => id === 'biology' ? biology.promise : chemistry.promise;
  await choose(view, 'biology');
  await choose(view, 'chemistry');
  await act(async () => chemistry.resolve(exams.chemistry));
  await act(async () => biology.resolve(exams.biology));
  assert.equal(title(view), 'Tell me about your test');
  assert.equal(view.container.querySelector('select').value, 'chemistry');
  assert.equal(new URL(window.location.href).searchParams.get('profileId'), 'chemistry');
  assert.ok(!view.container.textContent.includes('Biology practice'));
});

test('a failed selected state blocks intake rather than repainting the prior exam', async t => {
  const { calls } = setup();
  const view = await mount(t);
  api.testPrep.state = async id => { calls.state.push(id); throw new Error('not found'); };
  await choose(view, 'biology');
  assert.equal(title(view), 'Tell me about your test');
  assert.ok(!view.container.textContent.includes('Algebra practice'));
  assert.equal(view.container.querySelector('[aria-label="Your answer"]').disabled, true);
  await act(async () => [...view.container.querySelectorAll('button')].find(b => b.textContent === 'Try again').click());
  assert.equal(calls.state.at(-1), 'biology');
});

test('switching is blocked while an intake mutation is pending', async t => {
  const { calls } = setup();
  const view = await mount(t);
  await choose(view, 'chemistry');
  const reply = deferred();
  api.testPrep.intakeTurn = async (...args) => { calls.intake.push(args); return reply.promise; };
  await answer(view, 'Chemistry');
  await send(view);
  const control = view.container.querySelector('select');
  assert.equal(control.disabled, true);
  await act(async () => selectEvent(control, 'biology'));
  assert.equal(calls.state.at(-1), 'chemistry');
  await act(async () => reply.resolve({ test_profile_id: 'chemistry', message_to_user: 'Chemistry reply', intake_complete: false }));
  assert.ok(view.container.textContent.includes('Chemistry reply'));
});

test('late intake after navigation cannot generate or overwrite the reopened exam', async t => {
  const { calls } = setup();
  const view = await mount(t);
  await choose(view, 'chemistry');
  const reply = deferred();
  api.testPrep.intakeTurn = () => reply.promise;
  await answer(view, 'Chemistry');
  await send(view);
  await view.close();
  window.history.replaceState({}, '', '/test-prep?profileId=biology');
  const reopened = await mount(t);
  await act(async () => reply.resolve({ test_profile_id: 'chemistry', message_to_user: 'Wrong exam reply', intake_complete: true }));
  assert.equal(title(reopened), 'Biology');
  assert.ok(!reopened.container.textContent.includes('Wrong exam reply'));
  assert.deepEqual(calls.generate, []);
});

test('retrying a timed-out new test reuses the creation key', async t => {
  const { calls } = setup();
  const view = await mount(t);
  api.testPrep.startNew = async id => {
    calls.start.push(id);
    if (calls.start.length === 1) throw new Error('response lost');
    return { profile_id: 'chemistry', created: false };
  };
  await act(async () => newButton(view).click());
  assert.equal(title(view), 'Algebra');
  await act(async () => newButton(view).click());
  assert.equal(calls.start.length, 2);
  assert.equal(calls.start[0], calls.start[1]);
  assert.equal(title(view), 'Tell me about your test');
});

test('unsent draft and attached material do not carry to another exam', async t => {
  const { exams, calls } = setup();
  exams.biology = exam('biology', 'Biology', false);
  const view = await mount(t);
  await choose(view, 'chemistry');
  await answer(view, 'Chemistry draft');
  const upload = view.container.querySelector('input[type="file"]');
  Object.defineProperty(upload, 'files', { value: [new window.File(['notes'], 'chemistry.pdf', { type: 'application/pdf' })] });
  await act(async () => upload.dispatchEvent(new window.Event('change', { bubbles: true })));
  assert.ok(view.container.textContent.includes('chemistry.pdf'));
  await choose(view, 'biology');
  assert.equal(view.container.querySelector('[aria-label="Your answer"]').value, '');
  assert.ok(!view.container.textContent.includes('chemistry.pdf'));
  await answer(view, 'Biology');
  await send(view);
  assert.equal(calls.intake.at(-1)[1], 'biology');
  assert.deepEqual(calls.intake.at(-1)[2], []);
});
