import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  TEST_PREP_OPENING_TURN,
  classroomEntryHref,
  reviewEntryHref,
  shouldShowLearnerDashboard,
  testPrepEntryHref,
  practiceEntryHref,
  CLASSROOM_LEVELS,
  SESSION_LENGTHS,
  CLASSROOM_LANGUAGES,
  normalizeLevel,
  normalizeLanguage,
  normalizeSessionMinutes,
} from './entry-contract.mjs';

const query = (href) => new URL(href, 'https://lyo.test').searchParams;

test('the front door opens the Classroom on what the learner typed', () => {
  const params = query(classroomEntryHref({ topic: 'AP Chemistry' }));
  assert.equal(params.get('topic'), 'AP Chemistry');
  // The Director always receives an intent, even when the learner gave none.
  assert.equal(params.get('objective'), 'Understand and apply AP Chemistry');
});

test('an empty topic is not a destination', () => {
  // The CTA stays disabled rather than pushing a Classroom with nothing to
  // teach.
  assert.equal(classroomEntryHref({ topic: '   ' }), null);
  assert.equal(classroomEntryHref({}), null);
});

test('surrounding whitespace never reaches the Classroom', () => {
  const params = query(classroomEntryHref({ topic: '  fractions \n' }));
  assert.equal(params.get('topic'), 'fractions');
  assert.equal(params.get('objective'), 'Understand and apply fractions');
});

test('a topic with a URL-significant character survives intact', () => {
  const params = query(classroomEntryHref({ topic: 'acids & bases: pH' }));
  assert.equal(params.get('topic'), 'acids & bases: pH');
});

test('no mode is pinned unless one was asked for', () => {
  // Absent a request, the Classroom's own default applies rather than this
  // module second-guessing it.
  assert.equal(query(classroomEntryHref({ topic: 'Fractions' })).get('mode'), null);
  assert.equal(
    query(classroomEntryHref({ topic: 'Fractions', mode: 'challenge' })).get('mode'),
    'challenge',
  );
});

test('an unrecognised mode fails safely to solo teaching', () => {
  const params = query(classroomEntryHref({ topic: 'Fractions', mode: 'party' }));
  assert.equal(params.get('mode'), 'solo');
});

test('course and lesson identity is carried through when present', () => {
  const params = query(
    classroomEntryHref({ topic: 'Fractions', courseId: 'course-7', lessonId: 'lesson-3' }),
  );
  assert.equal(params.get('courseId'), 'course-7');
  assert.equal(params.get('lessonId'), 'lesson-3');

  const bare = query(classroomEntryHref({ topic: 'Fractions' }));
  assert.equal(bare.get('courseId'), null);
  assert.equal(bare.get('lessonId'), null);
});

test('a due review enters review mode, carrying no stored question', () => {
  const href = reviewEntryHref('Quadratic Functions');
  const params = query(href);
  assert.equal(params.get('mode'), 'review');
  assert.equal(params.get('topic'), 'Quadratic Functions');
  assert.equal(params.get('objective'), 'Retrieve and re-apply Quadratic Functions');
  // Retrieval is generated fresh: replaying the exact question the learner
  // already saw tests recall of that question, not of the concept.
  assert.equal(params.get('question'), null);
  assert.equal(params.get('last_question'), null);
});

test('"I have a test" opens the resumable account-owned workflow', () => {
  const href = testPrepEntryHref();
  assert.equal(href, '/test-prep');
  // The router matches on "have a test"; losing that phrasing silently
  // downgrades the entry to a generic explanation.
  assert.match(TEST_PREP_OPENING_TURN, /have a test/i);
});

// ─── Front door vs learner dashboard ─────────────────────────────────────────

test('a signed-out visitor never sees the dashboard, even mid-hydration', () => {
  // The regression this guards: isLoading starts true, so treating "still
  // loading" as "known learner" rendered Level 1 / 0 XP / 0 courses to a
  // guest for as long as the auth request took — the zero dashboard the front
  // door exists to replace, just briefer.
  assert.equal(
    shouldShowLearnerDashboard({ authLoading: true, isAuthenticated: false, hasRealActivity: false }),
    false,
  );
  assert.equal(
    shouldShowLearnerDashboard({ authLoading: false, isAuthenticated: false, hasRealActivity: false }),
    false,
  );
});

test('the dashboard waits for auth even when activity is already known', () => {
  // Cached activity must not let the dashboard render before we know who is
  // looking at it.
  assert.equal(
    shouldShowLearnerDashboard({ authLoading: true, isAuthenticated: true, hasRealActivity: true }),
    false,
  );
});

test('a signed-in learner with real activity gets their dashboard', () => {
  assert.equal(
    shouldShowLearnerDashboard({ authLoading: false, isAuthenticated: true, hasRealActivity: true }),
    true,
  );
});

test('a signed-in learner with nothing yet still gets the front door', () => {
  // Signed in is not the same as having something to show. An account with no
  // activity is exactly who the front door is for.
  assert.equal(
    shouldShowLearnerDashboard({ authLoading: false, isAuthenticated: true, hasRealActivity: false }),
    false,
  );
});

test('missing state is treated as nothing known, not as a learner', () => {
  assert.equal(shouldShowLearnerDashboard({}), false);
  assert.equal(shouldShowLearnerDashboard(), false);
});

// ─── Practice is not review ──────────────────────────────────────────────────

test('a weak concept is practised, not retrieved', () => {
  // Review asks the learner to retrieve something they already learned, and
  // success there is retention evidence. A concept on the weak list has not
  // been learned yet: retrieval tests a memory that was never formed, and any
  // success would be recorded as durable recall it is not.
  const params = new URLSearchParams(
    practiceEntryHref('Compare fractions').split('?')[1]
  );
  assert.equal(params.get('mode'), null);
  assert.ok(!(params.get('objective') ?? '').includes('Retrieve'));
});

test('practice leaves the mode to the Classroom', () => {
  assert.ok(!practiceEntryHref('Compare fractions').includes('mode='));
});

test('practice still names an objective so the Director has an intent', () => {
  // Parsed rather than string-matched: URLSearchParams encodes spaces as `+`,
  // which decodeURIComponent leaves alone, so a substring check on the raw
  // href tests the encoding rather than the objective.
  const params = new URLSearchParams(practiceEntryHref('Compare fractions').split('?')[1]);
  assert.equal(params.get('objective'), 'Practise and apply Compare fractions');
  assert.equal(params.get('topic'), 'Compare fractions');
});

test('review still enters review mode', () => {
  assert.ok(reviewEntryHref('Compare fractions').includes('mode=review'));
});

test('practice with no concept is not a destination', () => {
  assert.equal(practiceEntryHref(''), null);
  assert.equal(practiceEntryHref(null), null);
});

// ── The optional lesson questions ───────────────────────────────────────────

test('a learner who answers nothing gets exactly the URL they always did', () => {
  // The whole point of the options being optional. Typing a topic and pressing
  // Enter must not start sending a level nobody chose.
  const params = query(classroomEntryHref({ topic: 'Fractions' }));
  assert.equal(params.get('difficulty'), null);
  assert.equal(params.get('duration'), null);
  assert.equal(params.get('language'), null);
});

test('the answers the learner does give reach the Classroom', () => {
  const params = query(classroomEntryHref({
    topic: 'Fractions', level: 'beginner', minutes: 30, language: 'es',
  }));
  assert.equal(params.get('difficulty'), 'beginner');
  assert.equal(params.get('duration'), '30');
  assert.equal(params.get('language'), 'es');
});

test('an unrecognised answer is dropped rather than guessed at', () => {
  const params = query(classroomEntryHref({
    topic: 'Fractions', level: 'wizard', minutes: 7, language: 'klingon',
  }));
  assert.equal(params.get('difficulty'), null);
  assert.equal(params.get('duration'), null);
  assert.equal(params.get('language'), null);
});

test('"match my topic" is carried as no language, not as a choice', () => {
  // `auto` is what the Classroom already does. Sending it would claim the
  // learner picked a language when they declined to.
  assert.equal(normalizeLanguage('auto'), null);
  assert.equal(query(classroomEntryHref({ topic: 'Fractions', language: 'auto' })).get('language'), null);
});

test('a goal the learner picked becomes the objective the Director receives', () => {
  const params = query(classroomEntryHref({
    topic: 'Fractions', objective: 'Prepare for an exam on Fractions',
  }));
  assert.equal(params.get('objective'), 'Prepare for an exam on Fractions');
});

test('every session length the front door offers is one the Classroom honours', () => {
  // The Classroom parses `duration` with this same list. If the two ever
  // diverge, a learner asks for 45 minutes and is taught a 10-minute lesson
  // with nothing on screen admitting it.
  const classroom = readFileSync(
    new URL('../app/(main)/classroom/page.tsx', import.meta.url), 'utf8',
  );
  assert.match(classroom, /normalizeSessionMinutes\(params\.get\('duration'\)\)/);
  assert.match(classroom, /SESSION_LENGTHS\.map/);
  // And the server clamps to 3-60, so nothing offered may fall outside it.
  for (const minutes of SESSION_LENGTHS) {
    assert.ok(minutes >= 3 && minutes <= 60, `${minutes} is outside the server's 3-60 clamp`);
  }
});

test('normalisers accept exactly what is offered and nothing else', () => {
  for (const { value } of CLASSROOM_LEVELS) assert.equal(normalizeLevel(value), value);
  assert.equal(normalizeLevel('BEGINNER '), 'beginner');
  assert.equal(normalizeLevel(''), null);
  assert.equal(normalizeLevel(undefined), null);

  for (const minutes of SESSION_LENGTHS) assert.equal(normalizeSessionMinutes(minutes), minutes);
  assert.equal(normalizeSessionMinutes('30'), 30);
  assert.equal(normalizeSessionMinutes(0), null);

  for (const { value } of CLASSROOM_LANGUAGES) {
    assert.equal(normalizeLanguage(value), value === 'auto' ? null : value);
  }
});
