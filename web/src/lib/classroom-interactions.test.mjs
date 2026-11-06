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
import * as inferredFractions from './infer-explicit-fraction-visual.mjs';
import * as boardPresentation from './board-presentation.mjs';
import * as commonsImage from './commons-image.mjs';
import * as classroomCast from './classroom-cast.mjs';

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
    constructor(url) { this.url = url; sockets.push(this); }
    send(message) { this.sent.push(JSON.parse(message)); }
    close() {}
    interrupt() { this.readyState = 3; this.onclose?.({ code: 1006 }); }
    receive(message) { this.onmessage({ data: JSON.stringify(message) }); }
  }
  const deps = {
    zustand: { create }, '@/lib/classroom-audio.mjs': audio,
    '@/lib/classroom-contract.mjs': contract, '@/lib/learner-model.mjs': learner,
    '@/lib/teaching-activity.mjs': visuals, '@/lib/board-presentation.mjs': boardPresentation, '@/lib/classroom-sounds': { playSound() {} },
    '@/lib/api': { getAccessToken: () => localStorage.getItem('lyo_token'), tryRefreshToken: async () => false },
    '@/lib/infer-explicit-fraction-visual.mjs': inferredFractions,
    '@/lib/stack': { updateCourseProgress: async () => {} },
    // The Commons lookup the board shares with Chat. The real module, not a
    // stub: no test drives a board image, so it is never called, and a stub
    // would hide the day one does.
    '@/lib/commons-image.mjs': commonsImage,
    '@/lib/classroom-cast.mjs': classroomCast,
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

test('diagnostic feedback is visible and spoken while the next scene is still pending', () => {
  const { store, sockets, tick } = classroom();
  const socket = sockets[0];
  socket.onopen();
  socket.receive(component('QuizCard', { component_id: 'probe', question: 'Which piece is larger?',
    options: [{ id: 'a', label: 'One half' }, { id: 'b', label: 'One third' }] }));
  store.getState().answerQuiz('probe', { id: 'a', label: 'One half' });
  const event = { event_type: 'answer_feedback', session_id: 'lesson', data: {
    component_id: 'probe', verdict: 'correct', language_code: 'en-US',
    feedback: "That's correct. Fewer equal pieces leave more on each one. Let's start with practice.",
  } };
  socket.receive(event);
  const result = taught(store)[0];
  assert.equal(result.wasCorrect, true);
  assert.equal(result.feedback, event.data.feedback);
  assert.equal(store.getState().caption.text, event.data.feedback);
  assert.equal(store.getState().waitingForScene, true);
  assert.equal(store.getState().canContinue, false);
  const transcriptLength = store.getState().transcript.length;
  socket.receive(event);
  socket.receive({ ...event, session_id: 'another-lesson', data: { ...event.data, feedback: 'Stale result' } });
  socket.receive({ ...event, data: { ...event.data, component_id: 'old-probe', feedback: 'Wrong question' } });
  assert.equal(store.getState().transcript.length, transcriptLength);
  assert.equal(taught(store)[0].feedback, event.data.feedback);
  tick(20);
  assert.equal(store.getState().stallPhase, 'slow');
  socket.receive({ event_type: 'scene_start', scene: {} });
  socket.receive(component('ExampleBlock', { content: 'Our next worked example.' }));
  assert.equal(store.getState().waitingForScene, false);
  assert.equal(store.getState().boardHistory.at(-1).find(item => item.id === 'probe').feedback, event.data.feedback);
  store.getState().disconnect();
});

test('incorrect and not-sure results keep their distinct server verdicts', () => {
  for (const [verdict, expected] of [['incorrect', false], ['declined', undefined]]) {
    const { store, sockets } = classroom();
    sockets[0].receive(component('QuizCard', { component_id: 'probe', question: 'Which piece?', options: [] }));
    store.getState().answerQuiz('probe', { id: 'b', label: 'My answer' });
    sockets[0].receive({ event_type: 'answer_feedback', session_id: 'lesson', data: {
      component_id: 'probe', verdict, feedback: 'Let us build this from the beginning.',
    } });
    assert.equal(taught(store)[0].wasCorrect, expected);
    assert.ok(taught(store)[0].feedback);
    store.getState().disconnect();
  }
});

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

test('explicit narrated fraction model draws a real five-part visual and yields to authored visual', () => {
  const { store, sockets } = classroom();
  const socket = sockets[0];
  socket.receive(component('TeacherMessage', {
    component_id: 'fraction-narration',
    text: 'Look at the rectangle divided into five equal parts, with three shaded parts.',
  }));
  const fallback = taught(store).filter(el => el.kind === 'teaching_visual');
  assert.equal(fallback.length, 1);
  assert.equal(fallback[0].visual.kind, 'fraction_bar');
  assert.equal(fallback[0].visual.parts, 5);
  assert.equal(fallback[0].visual.value, 3);

  socket.receive(component('LessonBlock', {
    component_id: 'real-visual', block_type: 'teaching_visual',
    block: { kind: 'fraction_bar', title: 'Authoritative model', caption: 'Two of four', description: 'Four equal parts', parts: 4, value: 2, whole: 1, unit: 'whole' },
  }));
  const visualsAfter = taught(store).filter(el => el.kind === 'teaching_visual');
  assert.equal(visualsAfter.length, 1);
  assert.equal(visualsAfter[0].id, 'real-visual');
  assert.equal(visualsAfter[0].visual.parts, 4);
  store.getState().disconnect();
});

test('ambiguous narration never fabricates a classroom diagram', () => {
  const { store, sockets } = classroom();
  sockets[0].receive(component('TeacherMessage', {
    text: 'Look at the bar model and decide which option is correct.',
  }));
  assert.equal(taught(store).filter(el => el.kind === 'teaching_visual').length, 0);
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

test('unavailable natural teacher audio advances captions and retries on future lines', async () => {
  const { store, sockets, timers } = classroom();
  // The harness begins muted to keep other teaching tests deterministic.
  store.getState().toggleVoice();
  sockets[0].onopen();
  sockets[0].receive(component('TeacherMessage', { text: 'Let us learn with one clear example.' }));
  await new Promise(resolve => setImmediate(resolve));

  assert.equal(store.getState().voiceOn, true, 'a transient failure must not permanently mute the next lesson turn');
  assert.match(store.getState().notice, /Teacher audio is temporarily unavailable/);
  assert.equal(store.getState().caption.text, 'Let us learn with one clear example.');
  assert.ok(timers.some(timer => !timer.canceled && timer.delay <= 4000),
    'the caption remains on screen before the next turn');
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

test('a slow step becomes recoverable without automatically sending another request', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  const socket = sockets[0];
  socket.onopen();
  assert.equal(store.getState().stallPhase, 'none');

  tick(13);
  assert.equal(store.getState().stallPhase, 'slow', 'a wait past the notice point says so');

  const sentBefore = socket.sent.length;
  tick(20);
  assert.equal(socket.sent.length, sentBefore, 'no unsolicited request can interfere with grading');
  assert.equal(store.getState().stallPhase, 'stalled', 'a recoverable stall is visible after the threshold');

  tick(31);
  assert.equal(store.getState().stallPhase, 'stalled');
  assert.equal(socket.sent.length, sentBefore, 'the class never retries by itself');
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

test('a stalled answer offers manual continue without resubmitting the graded response', () => {
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
  assert.equal(store.getState().stallPhase, 'stalled');
  assert.equal(socket.sent.at(-1).action_intent, 'submit_answer');
  store.getState().nudgeTeacher();
  assert.equal(socket.sent.at(-1).action_intent, 'continue');
  assert.equal(socket.sent.filter(m => m.action_intent === 'submit_answer').length, 1);
  store.getState().disconnect();
});

test('a dropped socket reattaches to the same lesson without replaying a submitted answer', () => {
  const { store, sockets, timers } = classroom({ connection: { topic: 'Algebra', courseId: 'course-algebra' } });
  const firstSocket = sockets[0];
  firstSocket.onopen();
  firstSocket.receive(component('QuizCard', {
    component_id: 'algebra-quiz-1', question: 'What is the variable?',
    options: [{ id: 'x', label: 'x' }],
  }));
  store.getState().answerQuiz('algebra-quiz-1', { id: 'x', label: 'x' });
  firstSocket.receive({ event_type: 'answer_feedback', session_id: store.getState().sessionId, data: {
    component_id: 'algebra-quiz-1', verdict: 'correct', feedback: 'Exactly: x is the variable.',
  } });
  const sessionId = store.getState().sessionId;
  const before = taught(store)[0];
  firstSocket.interrupt();
  assert.equal(store.getState().status, 'connecting');
  assert.match(store.getState().notice, /answers are saved/i);
  assert.equal(store.getState().board.find(el => el.id === before.id)?.feedback, before.feedback);
  assert.equal(firstSocket.sent.filter(message => message.action_intent === 'submit_answer').length, 1);

  const reconnect = timers.find(timer => !timer.canceled && timer.delay === 500);
  assert.ok(reconnect, 'bounded reconnect scheduled after the first disconnect');
  reconnect.fn();
  assert.equal(sockets.length, 2);
  const secondSocket = sockets[1];
  assert.equal(new URL(secondSocket.url).searchParams.get('session_id'), sessionId);
  assert.equal(new URL(secondSocket.url).searchParams.get('resume'), '1');
  secondSocket.onopen();
  secondSocket.receive({ event_type: 'scene_start', session_id: sessionId, scene: {} });
  secondSocket.receive(component('QuizCard', {
    component_id: 'algebra-quiz-1', question: 'What is the variable?', options: [{ id: 'x', label: 'x' }],
  }));
  assert.equal(taught(store)[0].answered, 'x', 'replayed question retains submission acknowledgement');
  assert.equal(taught(store)[0].feedback, before.feedback, 'correct feedback survives transport replay');
  store.getState().answerQuiz('algebra-quiz-1', { id: 'x', label: 'x' });
  assert.equal(secondSocket.sent.filter(message => message.action_intent === 'submit_answer').length, 0);
  assert.equal(store.getState().notice, null);
  store.getState().disconnect();
});

test('a repeated network failure eventually stops reconnecting and keeps student work visible', () => {
  const { store, sockets, timers } = classroom();
  sockets[0].onopen();
  sockets[0].receive(component('QuizCard', {
    component_id: 'q-1', question: 'What is one half?', options: [{ id: 'a', label: '1/2' }],
  }));
  for (const delay of [500, 1400, 3200]) {
    sockets.at(-1).interrupt();
    const retry = timers.find(timer => !timer.canceled && timer.delay === delay);
    assert.ok(retry, `retry scheduled at ${delay} ms`);
    retry.fn();
  }
  sockets.at(-1).interrupt();
  assert.equal(sockets.length, 4, 'three retries maximum');
  assert.equal(store.getState().status, 'error');
  assert.match(store.getState().error, /answers are saved/i);
  assert.equal(taught(store)[0].quiz.question, 'What is one half?');
  store.getState().disconnect();
});

test('an old component id cannot accidentally mark a different question answered', () => {
  const { store, sockets } = classroom();
  const first = component('QuizCard', {
    component_id: 'question', question: 'Which is larger?', options: [{ id: 'a', label: 'A' }],
  });
  sockets[0].receive(first);
  store.getState().answerQuiz('question', { id: 'a', label: 'A' });
  sockets[0].receive({ event_type: 'scene_start', scene: {} });
  sockets[0].receive(component('QuizCard', {
    component_id: 'question', question: 'Which is smaller?', options: [{ id: 'b', label: 'B' }],
  }));
  assert.equal(taught(store)[0].answered, undefined);
  store.getState().answerQuiz('question', { id: 'b', label: 'B' });
  assert.equal(sockets[0].sent.filter(message => message.action_intent === 'submit_answer').length, 2);
  store.getState().disconnect();
});

test('an intentional lesson restart cancels the previous socket retry', () => {
  const { store, sockets, timers } = classroom();
  sockets[0].onopen();
  sockets[0].interrupt();
  const staleRetry = timers.find(timer => timer.delay === 500);
  assert.ok(staleRetry && !staleRetry.canceled);
  store.getState().restartLesson();
  assert.ok(staleRetry.canceled);
  assert.equal(sockets.length, 2);
  assert.notEqual(store.getState().sessionId, 'lesson');
  store.getState().disconnect();
});

test('backend capacity recovery displays a pause and a real Retry CTA, not endless waiting', () => {
  const { store, sockets } = classroom();
  sockets[0].onopen();
  sockets[0].receive({ event_type: 'scene_start', scene: {} });
  sockets[0].receive(component('ExampleBlock', {
    component_id: 'classroom-recovery/notice', title: 'Your lesson is paused',
    content: 'The teacher cannot generate the next lesson step right now. Your work is saved.',
  }));
  sockets[0].receive(component('CTAButton', {
    component_id: 'classroom-recovery/retry', label: 'Retry this step', action_intent: 'retry',
  }));
  assert.equal(store.getState().waitingForScene, false);
  assert.equal(store.getState().stallPhase, 'none');
  assert.match(store.getState().notice, /cannot generate/i);
  assert.equal(store.getState().continueLabel, 'Retry this step');
  assert.equal(store.getState().nextActionIntent, 'retry');
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
