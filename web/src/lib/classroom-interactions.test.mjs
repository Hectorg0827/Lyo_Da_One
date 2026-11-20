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
import * as alignedFractions from './align-teaching-visual.mjs';
import * as boardPresentation from './board-presentation.mjs';
import * as commonsImage from './commons-image.mjs';
import * as classroomCast from './classroom-cast.mjs';
import * as recovery from './classroom-websocket-recovery.mjs';

function classroom({ storage = {}, tabStorage = {}, connection = { topic: 'Fractions', sessionId: 'lesson' }, refreshToken = async () => false, fetcher, speechPlayer } = {}) {
  const sockets = [], timers = [], canceled = [], intervals = [];
  const markedCourses = [];
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
    drop(code = 1006) { this.readyState = 3; this.onclose?.({ code }); }
  }
  const deps = {
    zustand: { create }, '@/lib/classroom-audio.mjs': speechPlayer ? { ...audio, playSpeechResponse: speechPlayer } : audio,
    '@/lib/classroom-contract.mjs': contract, '@/lib/learner-model.mjs': learner,
    '@/lib/teaching-activity.mjs': visuals, '@/lib/board-presentation.mjs': boardPresentation, '@/lib/classroom-sounds': { playSound() {} },
    '@/lib/api': { getAccessToken: () => localStorage.getItem('lyo_token'), tryRefreshToken: refreshToken },
    '@/lib/infer-explicit-fraction-visual.mjs': inferredFractions,
    '@/lib/align-teaching-visual.mjs': alignedFractions,
    '@/lib/stack': { updateCourseProgress: async () => {}, markCourseInProgress: async (courseId) => { markedCourses.push(courseId); } },
    // The Commons lookup the board shares with Chat. The real module, not a
    // stub: no test drives a board image, so it is never called, and a stub
    // would hide the day one does.
    '@/lib/commons-image.mjs': commonsImage,
    '@/lib/classroom-cast.mjs': classroomCast,
    '@/lib/classroom-websocket-recovery.mjs': recovery,
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
  const sessionStorage = {
    getItem: key => (key in tabStorage ? tabStorage[key] : null),
    setItem: (key, value) => { tabStorage[key] = String(value); },
    removeItem: key => { delete tabStorage[key]; },
  };
  const context = {
    exports: {}, require: name => { if (!deps[name]) throw Error(name); return deps[name]; },
    process: { env: {} }, AbortController, performance, URL, CustomEvent,
    WebSocket: Socket, localStorage,
    ...(fetcher ? { fetch: fetcher } : {}),
    window: {
      speechSynthesis: { cancel() { canceled.push(true); } },
      dispatchEvent() {},
      localStorage,
      sessionStorage,
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
  return { store: useClassroomStore, sockets, timers, canceled, intervals, markedCourses, storage: store, tabStorage, tick };
}

/** Everything the teacher has actually put on the board, without the cover
    page the class opens on. */
const taught = store => store.getState().board.filter(el => el.kind !== 'opening');
const component = (type, rest) => ({ event_type: 'component_render', component: { type, component_id: type, ...rest } });

test('successful checkpoint participation marks a saved course in progress before any skill completes', () => {
  const { store, sockets, markedCourses } = classroom({ connection: {
    topic: 'Fractions', courseId: 'fractions-qa', sessionId: 'lesson',
  } });
  sockets[0].receive(component('QuizCard', { component_id: 'diagnostic', question: 'Denominator?', options: [
    { id: 'a', label: 'Eight' },
  ] }));
  store.getState().answerQuiz('diagnostic', { id: 'a', label: 'Eight' });
  assert.deepEqual(markedCourses, ['fractions-qa']);
  sockets[0].receive(component('InputField', { component_id: 'transfer', question: 'Explain the fraction' }));
  store.getState().answerTransfer('transfer', 'Eight equal parts make the whole.');
  assert.deepEqual(markedCourses, ['fractions-qa', 'fractions-qa']);
  store.getState().disconnect();
});

test('a checkpoint action that fails to reach the classroom never marks a course in progress', () => {
  const { store, sockets, markedCourses } = classroom({ connection: {
    topic: 'Fractions', courseId: 'fractions-qa', sessionId: 'lesson',
  } });
  sockets[0].receive(component('QuizCard', { component_id: 'diagnostic', question: 'Denominator?', options: [] }));
  sockets[0].readyState = 3;
  store.getState().answerQuiz('diagnostic', { id: 'a', label: 'Eight' });
  assert.deepEqual(markedCourses, []);
  store.getState().disconnect();
});

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

test('next teacher scene speaks only new teaching when it repeats immediate answer feedback', () => {
  const { store, sockets } = classroom();
  const socket = sockets[0];
  socket.onopen();
  socket.receive(component('QuizCard', { component_id: 'pizza-probe', question: 'How many sixths?',
    options: [{ id: 'wrong', label: '2/6' }] }));
  store.getState().answerQuiz('pizza-probe', { id: 'wrong', label: '2/6' });
  const feedback = 'Not quite. Two thirds becomes four sixths because both parts are doubled.';
  socket.receive({ event_type: 'answer_feedback', session_id: 'lesson', data: {
    component_id: 'pizza-probe', verdict: 'incorrect', feedback,
  } });
  assert.equal(store.getState().caption.text, feedback);
  socket.receive(component('TeacherMessage', { text: `${feedback} Now compare the two pizza diagrams.` }));
  // The feedback can still be playing. Advancing the queued teacher turn
  // proves neither the saved transcript nor spoken caption repeats it.
  store.getState().skipTurn();
  assert.equal(store.getState().caption.text, 'Now compare the two pizza diagrams.');
  assert.equal(store.getState().transcript.filter(line => line.text === feedback).length, 1);
  assert.equal(store.getState().transcript.filter(line => line.text.includes('Now compare')).length, 1);
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

test('an adjacent chocolate-bar example converts a mismatched pie to a bar while a pizza example keeps its pie', () => {
  const { store, sockets } = classroom();
  const socket = sockets[0];
  const fraction = { kind: 'fraction_pie', title: '3 out of 6 slices', caption: '3 of 6 slices',
    description: '3 equal slices from 6', parts: 6, value: 3, whole: 1, unit: 'whole' };
  socket.receive(component('ExampleBlock', { component_id: 'chocolate', title: 'Chocolate Bar Analogy',
    content: 'Three of six equal mini-squares make half a chocolate bar.' }));
  socket.receive(component('LessonBlock', { component_id: 'chocolate-visual', block_type: 'teaching_visual', block: fraction }));
  assert.equal(taught(store).find(el => el.id === 'chocolate-visual').visual.kind, 'fraction_bar');
  socket.receive(component('ExampleBlock', { component_id: 'pizza', title: 'Pizza cut into six slices',
    content: 'Three equal pizza slices make half a circle.' }));
  socket.receive(component('LessonBlock', { component_id: 'pizza-visual', block_type: 'teaching_visual', block: fraction }));
  assert.equal(taught(store).find(el => el.id === 'pizza-visual').visual.kind, 'fraction_pie');
  socket.receive({ event_type: 'scene_start', scene: {} });
  socket.receive(component('LessonBlock', { component_id: 'new-scene-visual', block_type: 'teaching_visual', block: fraction }));
  assert.equal(taught(store).find(el => el.id === 'new-scene-visual').visual.kind, 'fraction_pie',
    'stale examples from the previous scene may not reclassify a new diagram');
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

test('autoplay refusal never cools down an otherwise healthy natural teacher voice', async () => {
  let requests = 0;
  const blocked = Object.assign(new Error('User activation required'), {
    name: 'NotAllowedError', playbackStarted: false,
  });
  const { store, sockets } = classroom({
    fetcher: async () => {
      requests += 1;
      return new Response('mp3 audio', { headers: { 'Content-Type': 'audio/mpeg' } });
    },
    speechPlayer: async () => { throw blocked; },
  });
  store.getState().toggleVoice();
  const socket = sockets[0];
  socket.onopen();
  socket.receive(component('TeacherMessage', { text: 'The first explanation.' }));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(requests, 1);
  assert.match(store.getState().notice, /browser blocked teacher audio/);

  // A learner gesture and the next spoken line can arrive under 15 seconds.
  // A browser-level denial must not turn that next natural-voice request into
  // a synthetic server failure and send it to the robotic fallback again.
  socket.receive(component('TeacherMessage', { text: 'Now a different explanation.' }));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(requests, 2, 'the next voice request must reach the healthy server');
  store.getState().disconnect();
});

test('written application verdict is shown and spoken, including an incorrect answer', () => {
  const { store, sockets } = classroom();
  sockets[0].receive(component('InputField', { component_id: 'missing-numerator', question: '1/2 = ?/10' }));
  store.getState().answerTransfer('missing-numerator', '4');
  sockets[0].receive({ event_type: 'answer_feedback', session_id: 'lesson', data: {
    component_id: 'missing-numerator', verdict: 'incorrect', feedback: 'Not quite: one half of ten is five.',
  } });
  const answer = store.getState().board.find(el => el.kind === 'transfer' && el.input.component_id === 'missing-numerator');
  assert.equal(answer.submitted, true);
  assert.equal(answer.wasCorrect, false);
  assert.match(answer.feedback, /one half of ten is five/);
  assert.equal(store.getState().caption.text, 'Not quite: one half of ten is five.');
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

test('a resumed lesson restores the selected history board when its replay arrives', () => {
  const tabStorage = { 'lyo_classroom_board_view:Minecraft~2': '1' };
  const { store, sockets } = classroom({
    connection: { topic: 'Minecraft', resume: true },
    storage: { 'lyo_classroom_session:Minecraft': JSON.stringify({
      id: 'Minecraft~2', startedAt: Date.now(), generation: 2,
    }) },
    tabStorage,
  });
  assert.equal(store.getState().viewingBoard, -1, 'wait until the saved board exists');
  sockets[0].receive({ event_type: 'scene_start', scene: {} });
  sockets[0].receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'First replayed board' }]) }));
  sockets[0].receive({ event_type: 'scene_start', scene: {} });
  sockets[0].receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'Second replayed board' }]) }));
  assert.equal(store.getState().viewingBoard, 1);
  store.getState().viewBoard(-1);
  assert.equal(tabStorage['lyo_classroom_board_view:Minecraft~2'], undefined);
  store.getState().disconnect();
});

test('a new lesson ignores the board view of the previous session', () => {
  const tabStorage = { 'lyo_classroom_board_view:Minecraft~2': '1' };
  const { store } = classroom({ connection: { topic: 'Minecraft' }, tabStorage });
  assert.equal(store.getState().viewingBoard, -1);
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
  tick(50);
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

test('a stalled answer reattaches to the same scene without resubmitting the graded response', () => {
  const { store, sockets, tick } = classroom({ connection: { topic: 'Minecraft' } });
  const socket = sockets[0];
  socket.onopen();
  socket.receive(component('QuizCard', {
    question: 'Which key walks forward?', options: [{ id: 'a', label: 'W' }],
  }));
  store.getState().answerQuiz(taught(store)[0].id, { id: 'a', label: 'W' });
  assert.equal(socket.sent.at(-1).action_intent, 'submit_answer');

  tick(61);
  // The grader must not see this learner's answer twice because the first
  // one was slow coming back.
  assert.equal(store.getState().stallPhase, 'stalled');
  assert.equal(socket.sent.at(-1).action_intent, 'submit_answer');
  store.getState().nudgeTeacher();
  assert.equal(sockets.length, 2);
  assert.match(sockets[1].url, /[?&]resume=1(?:&|$)/);
  assert.equal(socket.sent.at(-1).action_intent, 'submit_answer');
  assert.equal(socket.sent.filter(m => m.action_intent === 'submit_answer').length, 1);
  store.getState().disconnect();
});

test('replayed checkpoint components do not duplicate the saved teacher transcript', () => {
  const { store, sockets } = classroom();
  const socket = sockets[0];
  socket.onopen();
  const prompt = component('InputField', {
    component_id: 'fraction-check-1', question: 'Explain why 2/4 equals 1/2.',
  });
  socket.receive(prompt);
  socket.receive(prompt);
  const lines = store.getState().transcript.filter(line =>
    line.text.includes('Explain why 2/4 equals 1/2.'));
  assert.equal(lines.length, 1);
  socket.receive(component('InputField', {
    component_id: 'fraction-check-2', question: 'Explain why 2/4 equals 1/2.',
  }));
  assert.equal(store.getState().transcript.filter(line =>
    line.text.includes('Explain why 2/4 equals 1/2.')).length, 1,
  'consecutive identical transcript lines are still collapsed');
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

test('a rejected WebSocket handshake refreshes the token before resuming', async () => {
  let refreshes = 0;
  const { store, sockets, timers, storage } = classroom({
    storage: { lyo_token: 'expired-access-token' },
    refreshToken: async () => {
      refreshes += 1;
      storage.lyo_token = 'renewed-access-token';
      return true;
    },
  });
  sockets[0].interrupt();
  const retry = timers.find(timer => !timer.canceled && timer.delay === 500);
  assert.ok(retry);
  await retry.fn();
  assert.equal(refreshes, 1);
  assert.equal(sockets.length, 2);
  assert.equal(new URL(sockets[1].url).searchParams.get('token'), 'renewed-access-token');
  sockets[1].onopen();
  assert.equal(store.getState().status, 'live');
  store.getState().disconnect();
});

test('a repeated network failure eventually stops reconnecting and keeps student work visible', async () => {
  const { store, sockets, timers } = classroom();
  sockets[0].onopen();
  sockets[0].receive(component('QuizCard', {
    component_id: 'q-1', question: 'What is one half?', options: [{ id: 'a', label: '1/2' }],
  }));
  for (const delay of [500, 1400, 3200]) {
    sockets.at(-1).interrupt();
    const retry = timers.find(timer => !timer.canceled && timer.delay === delay);
    assert.ok(retry, `retry scheduled at ${delay} ms`);
    await retry.fn();
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
  tick(61);
  tick(61);
  assert.equal(store.getState().stallPhase, 'stalled');
  store.getState().nudgeTeacher();
  assert.equal(sockets.length, 2);
  assert.match(sockets[1].url, /[?&]resume=1(?:&|$)/);
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
  assert.match(sockets[1].url, /[?&]resume=1(?:&|$)/);
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


test('unexpected disconnect reconnects the exact same lesson without clearing its board', async () => {
  const { store, sockets, timers } = classroom();
  const old = sockets[0];
  old.receive(component('TeacherMessage', { text: JSON.stringify([{ type: 'board', content: 'The fraction 2/3 is two parts out of three.' }]) }));
  const priorBoard = taught(store);
  assert.ok(priorBoard.length > 0);

  old.drop(1006);
  assert.equal(store.getState().status, 'connecting');
  assert.equal(taught(store).length, priorBoard.length);
  const retry = timers.find(t => t.delay === 500 && !t.canceled);
  assert.ok(retry, 'first reconnect should be scheduled, not mark lesson ended');
  await retry.fn();

  assert.equal(sockets.length, 2);
  assert.equal(new URL(sockets[0].url).searchParams.has('resume'), false, 'new lesson must not request stale scene');
  assert.equal(new URL(sockets[1].url).searchParams.get('session_id'), 'lesson');
  assert.equal(new URL(sockets[1].url).searchParams.get('resume'), '1', 'rejoin must restore persisted teacher scene');
  assert.equal(sockets[1].sent.length, 0, 'never replay previously submitted answers');
  assert.equal(taught(store).length, priorBoard.length);
  sockets[1].onopen();
  assert.equal(store.getState().status, 'live');
  store.getState().disconnect();
});

test('leaving a lesson cancels pending reconnect and rejects stale timer callbacks', async () => {
  const { store, sockets, timers } = classroom();
  sockets[0].drop();
  const retry = timers.find(t => t.delay === 500 && !t.canceled);
  assert.ok(retry);
  store.getState().disconnect();
  assert.ok(retry.canceled);
  await retry.fn(); // even a timer racing cancellation must not reopen
  assert.equal(sockets.length, 1);
  assert.equal(store.getState().status, 'idle');
});

