import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import * as audio from './classroom-audio.mjs';
import * as contract from './classroom-contract.mjs';
import { canResumeClassroom } from './classroom-contract.mjs';
import * as learner from './learner-model.mjs';
import * as visuals from './teaching-activity.mjs';

function classroom({ storage = {}, connection = { topic: 'Fractions', sessionId: 'lesson' } } = {}) {
  const sockets = [], timers = [], canceled = [], intervals = [];
  let clockMs = Date.now();
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
  // A real key/value store, not a stub that answers every key with a token:
  // the classroom now reads the session it last started out of the same
  // storage the auth token lives in, and a mock that cannot tell them apart
  // cannot see a resume go wrong.
  const store = { lyo_token: 'test-session-token', ...storage };
  const localStorage = {
    getItem: key => (key in store ? store[key] : null),
    setItem: (key, value) => { store[key] = String(value); },
  };
  const context = {
    exports: {}, require: name => { if (!deps[name]) throw Error(name); return deps[name]; },
    process: { env: {} }, AbortController, performance, URL, CustomEvent,
    WebSocket: Socket, localStorage,
    window: {
      speechSynthesis: { cancel() { canceled.push(true); } },
      dispatchEvent() {},
      localStorage,
    },
    setTimeout: (fn, delay) => { const timer = { fn, delay, canceled: false }; timers.push(timer); return timer; },
    clearTimeout: timer => { if (timer) timer.canceled = true; },
    // The wait watchdog ticks rather than arming a timer wherever a wait
    // begins, so the harness drives those ticks by hand.
    setInterval: (fn, delay) => { const interval = { fn, delay, canceled: false }; intervals.push(interval); return interval; },
    clearInterval: interval => { if (interval) interval.canceled = true; },
    // A clock the test owns. The watchdog measures a wait against wall
    // time, so a harness that cannot move the clock cannot reach the
    // moment where the class admits a step is not coming.
    Date: class extends Date { static now() { return clockMs; } },
  };
  const source = readFileSync(new URL('../stores/classroom-store.ts', import.meta.url), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText, context);
  const useClassroomStore = context.exports.useClassroomStore;
  useClassroomStore.getState().toggleVoice();
  useClassroomStore.getState().connect(connection);
  /** Run the watchdog as if `seconds` of wall clock had passed. */
  const tick = seconds => {
    for (let i = 0; i < seconds; i += 1) {
      clockMs += 1000;
      intervals.filter(interval => !interval.canceled).forEach(interval => interval.fn());
    }
  };
  return { store: useClassroomStore, sockets, timers, canceled, intervals, storage: store, tick };
}

/** Everything the teacher has actually put on the board, without the cover
    page the class opens on. */
const taught = store => store.getState().board.filter(el => el.kind !== 'opening');
const component = (type, rest) => ({ event_type: 'component_render', component: { type, component_id: type, ...rest } });

test('new speech preserves the current board until replacement board content arrives', () => {
  const { store, sockets } = classroom(); const socket = sockets[0];
  socket.receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'Current example' }]) }));
  assert.equal(taught(store).length, 1);
  socket.receive({ event_type: 'scene_start', scene: {} });
  socket.receive(component('TeacherMessage', { text: 'Let us compare a second example.' }));
  assert.equal(taught(store)[0].text, 'Current example');
  socket.receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'Next example' }]) }));
  store.getState().skipTurn();
  assert.equal(taught(store).length, 1);
  assert.equal(taught(store)[0].text, 'Next example');
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
  const quiz = taught(store)[0];
  store.getState().answerQuiz(quiz.id, { id: 'a', label: 'One half' });
  assert.equal(taught(store)[0].answered, 'One half');
  assert.equal(store.getState().waitingForScene, true);
  assert.equal(store.getState().progressCurrent, 0);
  assert.equal(sockets[0].sent.at(-1).action_intent, 'submit_answer');
  store.getState().disconnect();
});

// ─── The class has a beginning ───────────────────────────────────────────────

test('a class opens on what it is, before anything is taught', () => {
  const { store } = classroom({ connection: {
    topic: 'Minecraft', objective: 'Survive a first night', durationMinutes: 20,
    difficulty: 'beginner',
  } });
  const [cover, ...rest] = store.getState().board;
  assert.equal(cover.kind, 'opening');
  assert.equal(cover.opening.title, 'Today: Minecraft');
  assert.equal(cover.opening.objective, 'Survive a first night');
  assert.deepEqual(cover.opening.facts, ['20 min', 'beginner level']);
  assert.equal(cover.opening.resumed, false);
  // The cover is the whole board until the teacher says something.
  assert.deepEqual(rest, []);
  store.getState().disconnect();
});

test('the cover page stays out of the way of the teaching', () => {
  const { store, sockets } = classroom({ connection: { topic: 'Minecraft' } });
  sockets[0].receive({ event_type: 'scene_start', scene: {} });
  sockets[0].receive(component('TeacherMessage', {
    text: JSON.stringify([{ type: 'board', content: 'Right-click to break a block' }]),
  }));
  // Erased with the opening scene, and still reachable by flipping back.
  assert.equal(store.getState().board.some(el => el.kind === 'opening'), false);
  assert.equal(store.getState().boardHistory[0][0].kind, 'opening');
  store.getState().disconnect();
});

// ─── A second class is a second class ────────────────────────────────────────

test('a first class creates a clean session even when the backend retains the old topic ID', () => {
  const { store } = classroom({ connection: { topic: 'Minecraft' } });
  assert.match(store.getState().sessionId, /^Minecraft~1-\d+$/);
  assert.equal(store.getState().resumedSession, false);
  store.getState().disconnect();
});

test('opening the same topic again teaches it again instead of resuming', () => {
  const started = Date.now();
  const { store } = classroom({
    connection: { topic: 'Minecraft' },
    storage: {
      'lyo_classroom_session:Minecraft': JSON.stringify({
        id: 'Minecraft', startedAt: started, generation: 1,
      }),
    },
  });
  assert.notEqual(store.getState().sessionId, 'Minecraft');
  assert.equal(store.getState().resumedSession, false);
  // The seat they left is offered, not imposed.
  assert.equal(store.getState().resumable.id, 'Minecraft');
  store.getState().disconnect();
});

test('a learner who asks to resume gets the session they left', () => {
  const { store } = classroom({
    connection: { topic: 'Minecraft', resume: true },
    storage: {
      'lyo_classroom_session:Minecraft': JSON.stringify({
        id: 'Minecraft~2', startedAt: Date.now(), generation: 2,
      }),
    },
  });
  assert.equal(store.getState().sessionId, 'Minecraft~2');
  assert.equal(store.getState().resumedSession, true);
  assert.equal(store.getState().resumable, null);
  assert.equal(store.getState().board[0].opening.title, 'Back to Minecraft');
  store.getState().disconnect();
});

test('starting a lesson over leaves the stuck session behind', () => {
  const { store, sockets } = classroom({ connection: { topic: 'Minecraft' } });
  const first = store.getState().sessionId;
  store.getState().restartLesson();
  assert.equal(sockets.length, 2);
  assert.notEqual(store.getState().sessionId, first);
  assert.equal(store.getState().resumedSession, false);
  store.getState().disconnect();
});

// ─── A step that never arrives ───────────────────────────────────────────────

test('a slow step is said out loud, asked after once, and then handed over', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  const socket = sockets[0];
  socket.onopen();
  assert.equal(store.getState().stallPhase, 'none');

  tick(13);
  assert.equal(store.getState().stallPhase, 'slow', 'a wait past the notice point says so');

  const sentBefore = socket.sent.length;
  tick(20);
  assert.equal(socket.sent.length, sentBefore + 1, 'the class asks after the step itself, once');
  assert.equal(socket.sent.at(-1).action_intent, 'continue');
  assert.equal(store.getState().stallPhase, 'slow');

  tick(31);
  assert.equal(store.getState().stallPhase, 'stalled', 'the second wait is the admission');
  assert.equal(socket.sent.length, sentBefore + 1, 'and it does not keep asking');
  store.getState().disconnect();
});

test('a step that arrives clears the wait rather than leaving the warning up', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  sockets[0].onopen();
  tick(13);
  assert.equal(store.getState().stallPhase, 'slow');
  sockets[0].receive(component('TeacherMessage', { text: 'Press W to walk forward.' }));
  assert.equal(store.getState().stallPhase, 'none');
  assert.equal(store.getState().waitingForScene, false);
  store.getState().disconnect();
});

test('a stalled answer is asked after with continue, never resubmitted', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  const socket = sockets[0];
  socket.onopen();
  socket.receive(component('QuizCard', {
    question: 'Which key walks forward?', options: [{ id: 'a', label: 'W' }],
  }));
  store.getState().answerQuiz(taught(store)[0].id, { id: 'a', label: 'W' });
  assert.equal(socket.sent.at(-1).action_intent, 'submit_answer');

  tick(31);
  // The grader must not see this learner's answer twice because the first
  // one was slow coming back.
  assert.equal(socket.sent.at(-1).action_intent, 'continue');
  assert.equal(socket.sent.filter(m => m.action_intent === 'submit_answer').length, 1);
  store.getState().disconnect();
});

test('the learner can ask again by hand without resubmitting their answer', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  const socket = sockets[0];
  socket.onopen();
  tick(31);
  tick(31);
  assert.equal(store.getState().stallPhase, 'stalled');
  store.getState().nudgeTeacher();
  assert.equal(socket.sent.at(-1).action_intent, 'continue');
  assert.equal(store.getState().stallPhase, 'slow');
  store.getState().disconnect();
});

test('a paused class is not accused of stalling', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  sockets[0].onopen();
  store.getState().togglePause();
  tick(60);
  assert.equal(store.getState().stallPhase, 'none');
  assert.equal(sockets[0].sent.length, 0);
  store.getState().disconnect();
});

test('a problem the classroom reports reaches the learner, not just the drawer', () => {
  const { store, sockets } = classroom({ connection: { topic: 'Minecraft' } });
  sockets[0].receive({ event_type: 'error', message: 'Could not prepare the next step.' });
  assert.equal(store.getState().notice, 'Could not prepare the next step.');
  assert.equal(store.getState().status === 'error', false, 'a snag is not the end of the class');
  store.getState().dismissNotice();
  assert.equal(store.getState().notice, null);
  store.getState().disconnect();
});

test('picking up where you left off returns to that class, not the one just opened', () => {
  const left = { id: 'Minecraft', startedAt: Date.now(), generation: 1 };
  const { store, sockets } = classroom({
    connection: { topic: 'Minecraft' },
    storage: { 'lyo_classroom_session:Minecraft': JSON.stringify(left) },
  });
  // Opening the topic started a new class and offered the old seat back.
  const fresh = store.getState().sessionId;
  assert.notEqual(fresh, left.id);
  assert.equal(store.getState().resumable.id, left.id);

  store.getState().resumeLesson();
  assert.equal(sockets.length, 2);
  // Not `fresh`: starting this class overwrote the stored record, so the
  // offer has to carry the session it is actually about.
  assert.equal(store.getState().sessionId, left.id);
  assert.equal(store.getState().resumedSession, true);
  store.getState().disconnect();
});

test('a web entry that names only its course still gets a session of its own', () => {
  // The classroom route knows which course was opened, never which server
  // session the learner should land in. It used to pass the course id as
  // `sessionId`, which took the explicit-session branch on every entry and
  // left classroomSessionStart unreachable in the running app: repeat visits
  // kept sending the original id, `resume=1` did nothing, and every connect
  // reset the saved generation to 1. The store tests passed throughout,
  // because they had never sent the shape the page actually sends.
  const left = { id: 'course-7', startedAt: Date.now(), generation: 1 };
  const { store } = classroom({
    connection: { topic: 'Fractions', courseId: 'course-7' },
    storage: { 'lyo_classroom_session:course-7': JSON.stringify(left) },
  });
  assert.match(store.getState().sessionId, /^course-7~2-\d+$/);
  assert.equal(store.getState().courseId, 'course-7');
  assert.equal(store.getState().resumable.id, 'course-7');
  store.getState().disconnect();
});

test('a class taught to its end stops being offered back as unfinished', () => {
  const { store, sockets, storage } = classroom({ connection: { topic: 'Minecraft' } });
  sockets[0].receive(component('TeacherMessage', {
    text: JSON.stringify([{ type: 'session_end', homework: 'Build a shelter' }]),
  }));
  const saved = JSON.parse(storage['lyo_classroom_session:Minecraft']);
  assert.equal(saved.finished, true);
  assert.equal(canResumeClassroom(saved), false);
  store.getState().disconnect();

  // Reopening the topic treats it as a new class with nothing to resume.
  const next = classroom({
    connection: { topic: 'Minecraft' },
    storage: { 'lyo_classroom_session:Minecraft': JSON.stringify(saved) },
  });
  assert.equal(next.store.getState().resumable, null);
  next.store.getState().disconnect();
});

test('durably completed guided scenes stop being offered back without a director turn', () => {
  const { store, sockets, storage } = classroom({ connection: { topic: 'Fractions' } });
  sockets[0].receive({ event_type: 'scene_start', scene: { metadata: { course_complete: false } } });
  assert.equal(JSON.parse(storage['lyo_classroom_session:Fractions']).finished, undefined);
  sockets[0].receive({ event_type: 'scene_start', scene: { metadata: { course_complete: true } } });
  const saved = JSON.parse(storage['lyo_classroom_session:Fractions']);
  assert.equal(saved.finished, true);
  assert.equal(canResumeClassroom(saved), false);
  assert.equal(store.getState().resumable, null);
  store.getState().disconnect();
});
