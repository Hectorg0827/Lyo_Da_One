import test from 'node:test';
import assert from 'node:assert/strict';
import { returnFromJourney, studySessionJourneyPlan, beginMissionJourney } from './journey-handoff.mjs';

const goal = { id: 'goal-exam', source_ref_type: 'test_profile', source_ref_id: 'exam-one' };
const session = { id: 'session-one', topic: 'Chemistry bonds', session_type: 'practice', duration_minutes: 10, status: 'scheduled' };

test('a planned study session binds to the correct owned exam context', () => {
  const plan = studySessionJourneyPlan(session, goal, 'exam-one');
  assert.equal(plan.start.origin_surface, 'test_prep');
  assert.equal(plan.start.context.test_profile_id, 'exam-one');
  assert.equal(plan.start.context.study_session_id, 'session-one');
  assert.equal(plan.handoff.target_surface, 'classroom');
  assert.equal(new URL(plan.href, 'https://lyo.example').pathname, '/classroom');
});

test('cannot attach wrong exam or malformed study session', () => {
  assert.equal(studySessionJourneyPlan(session, goal, 'exam-two'), null);
  assert.equal(studySessionJourneyPlan({ ...session, id: '../../steal' }, goal, 'exam-one'), null);
  assert.equal(studySessionJourneyPlan({ ...session, topic: '' }, goal, 'exam-one'), null);
  assert.equal(studySessionJourneyPlan(session, { id: 'goal-exam', source_ref_type: null }, 'exam-one'), null);
});

test('Classroom return includes the exact session on the original exam URL', () => {
  assert.equal(
    returnFromJourney({ origin_surface: 'test_prep', context: { test_profile_id: 'exam-one', study_session_id: 'session-one' } }),
    '/test-prep?profileId=exam-one&sessionId=session-one'
  );
  assert.equal(
    returnFromJourney({ origin_surface: 'test_prep', context: { test_profile_id: 'exam-one', study_session_id: '../../evil' } }),
    '/test-prep?profileId=exam-one'
  );
});

test('real exam session uses the same idempotent journey API, never awards mastery', async () => {
  const calls = [];
  const api = {
    async start(body) { calls.push(['start', body]); return { id: 'journey-123', revision: 0 }; },
    async handoff(id, body) { calls.push(['handoff', id, body]); return { id: 'handoff-1', revision: 1 }; },
  };
  const href = await beginMissionJourney(studySessionJourneyPlan(session, goal, 'exam-one'), api,
    { start: 'start-exam-session-1', handoff: 'handoff-exam-session-1' });
  assert.equal(calls.length, 2);
  assert.equal(calls[0][1].context.study_session_id, 'session-one');
  assert.equal(calls[1][2].expected_revision, 0);
  assert.equal(new URL(href, 'https://lyo.example').searchParams.get('journeyId'), 'journey-123');
});
