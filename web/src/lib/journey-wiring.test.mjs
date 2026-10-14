import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = (relative) => readFileSync(new URL(relative, import.meta.url), 'utf8');

test('Home Coach and Test Prep use one shared handoff entry instead of separate AI routers', () => {
  const home = source('../components/home/CoachNextStep.tsx');
  const prep = source('../app/(main)/test-prep/page.tsx');
  const hero = source('../components/test-prep/CoachHero.tsx');
  const component = source('../components/coach/CoachMissionEntry.tsx');

  assert.match(home, /<CoachMissionEntry/);
  assert.match(prep, /<CoachHero/);
  assert.match(hero, /<CoachMissionEntry/);
  assert.match(prep, /profileId=\{profileId\}/);
  assert.match(component, /missionJourneyPlan/);
  assert.match(component, /api\.coach\.journeys/);
  assert.match(component, /NEXT_PUBLIC_LYO_JOURNEYS_ENABLED/);
  assert.match(component, /Open without tracking the transition/);
  assert.doesNotMatch(component, /mastery\s*=/i);
});

test('Classroom safely returns from the authenticated saved journey', () => {
  const classroom = source('../app/(main)/classroom/page.tsx');
  assert.match(classroom, /params\.get\('journeyId'\)/);
  assert.match(classroom, /api\.coach\.journeys\.get/);
  assert.match(classroom, /api\.coach\.journeys\.handoff/);
  assert.match(classroom, /returnFromJourney\(journey\)/);
  assert.match(classroom, /Leave without recording/);
  assert.match(classroom, /Journey.*?Reload|Reload context/s);
});

test('Journeys reuse authenticated backend API and do not change grading routes', () => {
  const api = source('./api.ts');
  assert.match(api, /\/api\/v1\/me\/coach\/journeys/);
  assert.match(api, /journeys: \{/);
  assert.doesNotMatch(source('./journey-handoff.mjs'), /\/(grade|mastery|assessments?)\b/);
});
