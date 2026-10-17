import assert from 'node:assert/strict';
import test from 'node:test';

import {
  actionLabel,
  goalForTestProfile,
  missionEntryHref,
  readinessExplanation,
  readinessLabel,
} from './coach.mjs';

test('two same-subject exams select only the Coach goal linked to the chosen profile', () => {
  const goals = ['exam-a', 'exam-b'].map(id => ({
    id: `goal-${id}`, goal_type: 'test', subject: 'Algebra',
    source_ref_type: 'test_profile', source_ref_id: id,
  }));
  assert.equal(goalForTestProfile(goals, 'exam-a'), goals[0]);
  assert.equal(goalForTestProfile(goals, 'exam-b'), goals[1]);
  assert.equal(goalForTestProfile(goals, 'exam-missing'), null);
});

test('missing or ambiguous exam links never select a Coach goal by subject alone', () => {
  const unlinked = { id: 'legacy', goal_type: 'test', subject: 'Algebra' };
  const linked = { ...unlinked, source_ref_type: 'test_profile', source_ref_id: 'exam-a' };
  assert.equal(goalForTestProfile([unlinked], 'exam-a'), null);
  assert.equal(goalForTestProfile([linked, { ...linked, id: 'duplicate' }], 'exam-a'), null);
  assert.equal(goalForTestProfile(undefined, 'exam-a'), null);
  assert.equal(goalForTestProfile([linked], null), null);
});

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
