import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import * as audio from './classroom-audio.mjs';
import * as contract from './classroom-contract.mjs';
import * as learner from './learner-model.mjs';
import * as visuals from './teaching-activity.mjs';

function classroom() {
  const sockets = [], timers = [], canceled = [];
  let state;
  const create = init => {
    const store = { getState: () => state };
    state = init(update => { state = { ...state, ...(typeof update === 'function' ? update(state) : update) }; }, () => state);
    return store;
  };
  class Socket {
    static OPEN = 1;
    readyState = 1;
    sent = [];
    constructor() { sockets.push(this); }
    send(message) { this.sent.push(JSON.parse(message)); }
    close() {}
    receive(message) { this.onmessage({ data: JSON.stringify(message) }); }
  }
  const deps = {
    zustand: { create }, '@/lib/classroom-audio.mjs': audio,
    '@/lib/classroom-contract.mjs': contract, '@/lib/learner-model.mjs': learner,
    '@/lib/teaching-activity.mjs': visuals, '@/lib/classroom-sounds': { playSound() {} },
    '@/lib/stack': { updateCourseProgress: async () => {} },
  };
  const context = {
    exports: {}, require: name => { if (!deps[name]) throw Error(name); return deps[name]; },
    process: { env: {} }, AbortController, performance, URL, CustomEvent,
    WebSocket: Socket, localStorage: { getItem: () => 'test-session-token' },
    window: { speechSynthesis: { cancel() { canceled.push(true); } }, dispatchEvent() {} },
    setTimeout: (fn, delay) => { const timer = { fn, delay, canceled: false }; timers.push(timer); return timer; },
    clearTimeout: timer => { if (timer) timer.canceled = true; },
  };
  const source = readFileSync(new URL('../stores/classroom-store.ts', import.meta.url), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText, context);
  const store = context.exports.useClassroomStore;
  store.getState().toggleVoice();
  store.getState().connect({ topic: 'Fractions', sessionId: 'lesson' });
  return { store, sockets, timers, canceled };
}
const component = (type, rest) => ({ event_type: 'component_render', component: { type, component_id: type, ...rest } });

test('new speech preserves the current board until replacement board content arrives', () => {
  const { store, sockets } = classroom(); const socket = sockets[0];
  socket.receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'Current example' }]) }));
  assert.equal(store.getState().board.length, 1);
  socket.receive({ event_type: 'scene_start', scene: {} });
  socket.receive(component('TeacherMessage', { text: 'Let us compare a second example.' }));
  assert.equal(store.getState().board[0].text, 'Current example');
  socket.receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'Next example' }]) }));
  store.getState().skipTurn();
  assert.equal(store.getState().board.length, 1);
  assert.equal(store.getState().board[0].text, 'Next example');
  store.getState().disconnect();
});

test('board rendering no longer inserts seconds of delay before narration', () => {
  const { store, sockets, timers } = classroom();
  sockets[0].receive(component('TeacherMessage', { text: JSON.stringify([
    { type: 'board', action: 'bullets', items: ['One', 'Two'] },
    { type: 'speech', text: 'Here is how these ideas connect.' },
  ]) }));
  assert.equal(timers.at(-1).delay, 0);
  timers.at(-1).fn();
  assert.equal(store.getState().caption.text, 'Here is how these ideas connect.');
  store.getState().disconnect();
});

test('taking the floor immediately stops the teacher and preserves the board', () => {
  const { store, sockets, canceled } = classroom();
  sockets[0].receive(component('TeacherMessage', { text: 'A teacher explanation.' }));
  const before = canceled.length;
  store.getState().takeFloor();
  assert.equal(store.getState().lyoState, 'listening');
  assert.equal(store.getState().isNarrating, false);
  assert.equal(store.getState().caption, null);
  assert.ok(canceled.length > before);
  store.getState().disconnect();
});

test('late events from a disconnected classroom cannot replace the current lesson', () => {
  const { store, sockets } = classroom(); const old = sockets[0];
  store.getState().connect({ topic: 'Geometry', sessionId: 'new-lesson' });
  old.receive(component('TeacherMessage', { text: 'Obsolete answer' }));
  assert.equal(store.getState().caption, null);
  sockets[1].receive(component('TeacherMessage', { text: 'Current answer' }));
  assert.equal(store.getState().caption.text, 'Current answer');
  store.getState().disconnect();
});

test('submitting a quiz acknowledges the selection without inventing correctness or mastery', () => {
  const { store, sockets } = classroom();
  sockets[0].receive(component('QuizCard', { question: 'Which fraction is larger?', options: [{ id: 'a', label: 'One half' }] }));
  const quiz = store.getState().board[0];
  store.getState().answerQuiz(quiz.id, { id: 'a', label: 'One half' });
  assert.equal(store.getState().board[0].answered, 'One half');
  assert.equal(store.getState().waitingForScene, true);
  assert.equal(store.getState().progressCurrent, 0);
  assert.equal(sockets[0].sent.at(-1).action_intent, 'submit_answer');
  store.getState().disconnect();
});
