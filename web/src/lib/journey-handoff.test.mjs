import test from 'node:test';
import assert from 'node:assert/strict';
import { withJourneyId, returnFromJourney, missionJourneyPlan, beginMissionJourney } from './journey-handoff.mjs';

const mission = { goal_id: 'goal-A', title: 'Covalent bonding', concept_id: 'covalent', action: 'guide' };
const exam = { id: 'goal-A', source_ref_type: 'test_profile', source_ref_id: 'exam-A' };
const general = { id: 'goal-A', source_ref_type: null, source_ref_id: null };

test('returns to the original exam profile, never a default stale exam', () => {
  const result = returnFromJourney({
    origin_surface: 'test_prep',
    context: { test_profile_id: 'exam & 2' },
  });
  assert.equal(result, '/test-prep?profileId=exam%20%26%202');
  assert.equal(returnFromJourney({ origin_surface: 'coach', context: {} }), '/');
  assert.equal(returnFromJourney({ origin_surface: 'chat', context: {} }), '/chat');
});

test('a saved navigation ID can only be appended to a Classroom URL', () => {
  const href = withJourneyId('/classroom?topic=acids%20%26%20bases', 'journey-123');
  const uri = new URL(href, 'https://lyo.test');
  assert.equal(uri.searchParams.get('topic'), 'acids & bases');
  assert.equal(uri.searchParams.get('journeyId'), 'journey-123');
  assert.equal(withJourneyId('https://evil.example/steal', 'journey-123'), null);
  assert.equal(withJourneyId('/test-prep', 'journey-123'), null);
  assert.equal(withJourneyId('/classroom', '../evil'), null);
});

test('Coach mission only binds matching goal and its canonical test profile', () => {
  assert.equal(missionJourneyPlan(mission, { id: 'other-goal' }), null);
  const coach = missionJourneyPlan(mission, exam);
  assert.equal(coach.start.goal_id, 'goal-A');
  assert.equal(coach.start.context.test_profile_id, 'exam-A');
  assert.equal(coach.start.origin_surface, 'coach');
  assert.equal(coach.handoff.target_surface, 'classroom');
  assert.equal(coach.start.context.concept_id, 'covalent');

  assert.equal(missionJourneyPlan(mission, exam, 'test_prep', 'exam-B'), null);
  assert.equal(missionJourneyPlan(mission, general, 'test_prep', 'exam-A'), null);
  const matching = missionJourneyPlan(mission, exam, 'test_prep', 'exam-A');
  assert.equal(matching.start.origin_ref, 'exam-A');
  assert.equal(matching.start.context.test_profile_id, 'exam-A');
});

test('general goal can teach an unrestricted topic without an exam profile', () => {
  const plan = missionJourneyPlan({ ...mission, title: 'World music theory' }, general);
  assert.equal(plan.start.context.test_profile_id, undefined);
  assert.equal(new URL(plan.href, 'https://lyo.test').searchParams.get('topic'), 'World music theory');
});

test('journey start and handoff occur in order and return a resumeable Classroom link', async () => {
  const events = [];
  const api = {
    start: async body => {
      events.push(['start', body]);
      return { id: 'journey-21', revision: 0, context: body.context };
    },
    handoff: async (id, body) => {
      events.push(['handoff', id, body]);
      return { id: 'event-1', revision: 1 };
    },
  };
  const href = await beginMissionJourney(missionJourneyPlan(mission, exam, 'test_prep', 'exam-A'), api, {
    start: 'same-start-key', handoff: 'same-handoff-key',
  });
  assert.equal(events[0][0], 'start');
  assert.equal(events[1][0], 'handoff');
  assert.equal(events[1][1], 'journey-21');
  assert.equal(events[1][2].expected_revision, 0);
  assert.equal(events[0][1].request_id, 'same-start-key');
  assert.equal(events[1][2].request_id, 'same-handoff-key');
  assert.equal(new URL(href, 'https://lyo.test').searchParams.get('journeyId'), 'journey-21');
});

test('a backend handoff failure cannot pretend that navigation was saved', async () => {
  const api = {
    start: async () => ({ id: 'journey-21', revision: 0 }),
    handoff: async () => { throw Error('503 from journey service'); },
  };
  await assert.rejects(
    beginMissionJourney(missionJourneyPlan(mission, exam), api, {
      start: 'stable-start-key', handoff: 'stable-handoff-key',
    }),
    /503 from journey service/,
  );
});

test('Coach vs Test Prep handoffs never redirect through user-supplied URLs', () => {
  assert.equal(returnFromJourney({
    origin_surface: 'coach',
    origin_ref: 'https://malicious.example/login',
    context: { test_profile_id: 'exam-A' },
  }), '/');
  assert.equal(returnFromJourney({
    origin_surface: 'test_prep',
    origin_ref: 'https://malicious.example/login',
    context: { test_profile_id: 'exam-A' },
  }), '/test-prep?profileId=exam-A');
  assert.equal(withJourneyId('/classroom?topic=x&journeyId=old', 'new-id').includes('journeyId=new-id'), true);
});

test('malformed plan and IDs never navigate', async () => {
  await assert.rejects(beginMissionJourney(null, {}, { start: 'a', handoff: 'b' }), /Missing journey plan/);
  await assert.rejects(
    beginMissionJourney(missionJourneyPlan(mission, exam), {}, {}),
    /Missing journey idempotency keys/,
  );
});
