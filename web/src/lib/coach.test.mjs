import assert from 'node:assert/strict';
import test from 'node:test';

import {
  actionLabel,
  missionEntryHref,
  readinessExplanation,
  readinessLabel,
} from './coach.mjs';

test('readiness uses calibrated language, not a fake grade percentage', () => {
  assert.equal(readinessLabel({ readiness_level: 'getting_there' }), 'Getting there');
  assert.equal(readinessExplanation({
    total_skills: 4, assessed_skills: 2, critical_gaps: 2,
  }), '2 skills still need application evidence.');
});

test('retention missions enter the canonical review path', () => {
  const href = missionEntryHref({
    title: 'Mitosis', concept_id: 'mitosis', action: 'review',
    target_evidence_type: 'retention',
  });
  assert.match(href, /^\/classroom\?/);
  assert.match(href, /mode=review/);
  assert.match(href, /reviewConceptId=mitosis/);
});

test('checks reuse the teaching runtime rather than inventing a client quiz', () => {
  const href = missionEntryHref({
    title: 'Stoichiometry', concept_id: 'stoich', action: 'check_transfer',
    target_evidence_type: 'transfer',
  });
  assert.match(href, /^\/classroom\?/);
  assert.doesNotMatch(href, /mode=review/);
  assert.equal(actionLabel('check_transfer'), 'Challenge');
});


test('mission handoffs carry the server-owned session duration', () => {
  const href = missionEntryHref({
    title: 'Mitosis',
    concept_id: 'mitosis',
    action: 'guide',
    target_evidence_type: 'application',
    estimated_minutes: 10,
  });
  assert.match(href, /duration=10/);
});

test('review handoffs keep both retention identity and duration', () => {
  const href = missionEntryHref({
    title: 'Cell division',
    concept_id: 'cell-division',
    action: 'review',
    target_evidence_type: 'retention',
    estimated_minutes: 5,
  });
  assert.match(href, /mode=review/);
  assert.match(href, /reviewConceptId=cell-division/);
  assert.match(href, /duration=5/);
});
