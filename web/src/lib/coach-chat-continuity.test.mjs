import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { missionEntryHref } from './coach.mjs';
import { missionJourneyPlan, returnFromJourney } from './journey-handoff.mjs';
import { normalizeServerSessionMinutes, classroomEntryHref } from './entry-contract.mjs';

const params = (href) => new URL(href, 'https://lyo.test').searchParams;
const source = (relative) => readFileSync(new URL(relative, import.meta.url), 'utf8');

test('Coach time boxes respect precise server minutes without changing Home presets', () => {
  assert.equal(normalizeServerSessionMinutes(7), 7);
  assert.equal(normalizeServerSessionMinutes(2), null);
  assert.equal(normalizeServerSessionMinutes(61), null);
  assert.equal(normalizeServerSessionMinutes(7.5), null);
  assert.equal(params(classroomEntryHref({ topic: 'Mitosis', minutes: 7 })).get('duration'), null);
  assert.equal(params(classroomEntryHref({ topic: 'Mitosis', serverMinutes: 7 })).get('duration'), '7');
});

test('structured Coach mission opens Classroom with requested time and no duplicate quiz engine', () => {
  for (const action of ['diagnose', 'guide', 'check_transfer', 'review']) {
    const href = missionEntryHref({
      action, title: 'Jazz harmony', concept_id: 'jazz-harmony', estimated_minutes: 7,
    });
    assert.equal(params(href).get('duration'), '7');
    assert.equal(params(href).get('topic'), 'Jazz harmony');
    assert.equal(href.startsWith('/classroom?'), true);
  }
});

test('Coach can return from Chat to Chat without an arbitrary URL redirect', () => {
  const mission = { goal_id: 'goal-chat', skill_id: 's1', concept_id: 'harmony', title: 'Harmony', action: 'guide', estimated_minutes: 7 };
  const goal = { id: 'goal-chat', goal_type: 'mastery', source_ref_type: null, source_ref_id: null };
  const plan = missionJourneyPlan(mission, goal, 'chat');
  assert.equal(plan.start.origin_surface, 'chat');
  assert.equal(plan.handoff.target_surface, 'classroom');
  assert.equal(returnFromJourney({ origin_surface: 'chat', origin_ref: 'https://not-lyo.example', context: {} }), '/chat');
});

test('Chat uses the one Coach SSE event and mission display, not another AI', () => {
  const store = source('../stores/chat-store.ts');
  const bubble = source('../components/chat/MessageBubble.tsx');
  const card = source('../components/chat/CoachMissionCard.tsx');
  assert.match(store, /chunk\.type === 'coach_mission'/);
  assert.match(store, /patchAiMessage\(\{\s*metadata:/);
  assert.match(bubble, /<CoachMissionCard/);
  assert.match(card, /<CoachMissionEntry/);
  assert.match(card, /origin="chat"/);
});

test('new entries preserve server-origin exam identity while defaulting off safely', () => {
  const mission = { goal_id: 'goal-test', title: 'Reaction types', action: 'guide', estimated_minutes: 7, concept_id: 'react' };
  const goal = { id: 'goal-test', source_ref_type: 'test_profile', source_ref_id: 'exam-42' };
  assert.equal(missionJourneyPlan(mission, goal, 'test_prep', 'exam-43'), null);
  const plan = missionJourneyPlan(mission, goal, 'test_prep', 'exam-42');
  assert.equal(plan.start.context.test_profile_id, 'exam-42');
  assert.equal(params(plan.href).get('duration'), '7');
  assert.match(source('../components/coach/CoachMissionEntry.tsx'), /NEXT_PUBLIC_LYO_JOURNEYS_ENABLED === '1'/);
});
