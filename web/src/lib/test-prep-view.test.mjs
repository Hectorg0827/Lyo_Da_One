import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildKpis,
  filterMaterials,
  hourLabel,
  materialFilters,
  materialKind,
  missionChecklist,
  planProgress,
  readinessRing,
  sessionDate,
  weekTimeline,
} from './test-prep-view.mjs';

const NY = 'America/New_York';
// A Tuesday. 2025-12-02T20:00Z is 3pm in New York.
const TUESDAY = new Date('2025-12-02T20:00:00Z');

function session(overrides) {
  return {
    id: 'session-1',
    scheduled_at: '2025-12-02T23:00:00',
    duration_minutes: 25,
    topic: 'Cellular respiration',
    session_type: 'learn',
    concept_id: 'concept-1',
    status: 'scheduled',
    performance_score: null,
    ...overrides,
  };
}

// ─── Instants ────────────────────────────────────────────────────────────────

test('a naive scheduled_at is read as UTC, not as local time', () => {
  assert.equal(sessionDate('2025-12-02T23:00:00').toISOString(), '2025-12-02T23:00:00.000Z');
});

test('an explicit offset is left alone', () => {
  assert.equal(sessionDate('2025-12-02T18:00:00-05:00').toISOString(), '2025-12-02T23:00:00.000Z');
});

// ─── The week ────────────────────────────────────────────────────────────────

test('the week runs Monday to Sunday around today', () => {
  const { days } = weekTimeline([], { timezone: NY, now: TUESDAY });
  assert.equal(days.length, 7);
  assert.deepEqual(days.map((d) => d.weekday), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
  assert.equal(days[0].key, '2025-12-01');
  assert.equal(days[6].key, '2025-12-07');
});

test('exactly one day is today, and it is the right one', () => {
  const { days } = weekTimeline([], { timezone: NY, now: TUESDAY });
  assert.deepEqual(days.filter((d) => d.isToday).map((d) => d.key), ['2025-12-02']);
});

test('a session lands on its day in the study timezone, not in UTC', () => {
  // 01:00Z Wednesday is 8pm Tuesday in New York. Bucketing on the UTC date
  // would push this session onto the wrong column.
  const { days } = weekTimeline([session({ scheduled_at: '2025-12-03T01:00:00' })], {
    timezone: NY, now: TUESDAY,
  });
  const tuesday = days.find((d) => d.key === '2025-12-02');
  const wednesday = days.find((d) => d.key === '2025-12-03');
  assert.equal(tuesday.blocks.length, 1);
  assert.equal(wednesday.blocks.length, 0);
  assert.equal(tuesday.blocks[0].startOfDayMinutes, 20 * 60);
});

test('the same instant lands a day later in Tokyo', () => {
  const { days } = weekTimeline([session({ scheduled_at: '2025-12-03T01:00:00' })], {
    timezone: 'Asia/Tokyo', now: TUESDAY,
  });
  assert.equal(days.find((d) => d.key === '2025-12-03').blocks.length, 1);
});

test('an unknown timezone falls back to UTC rather than blanking the week', () => {
  const { days } = weekTimeline([session()], { timezone: 'Not/AZone', now: TUESDAY });
  assert.equal(days.reduce((sum, day) => sum + day.blocks.length, 0), 1);
});

test('a session outside this week is dropped, not misfiled', () => {
  const { days } = weekTimeline([session({ scheduled_at: '2025-12-20T18:00:00' })], {
    timezone: NY, now: TUESDAY,
  });
  assert.equal(days.reduce((sum, day) => sum + day.blocks.length, 0), 0);
});

test('a day with only completed sessions reads done; one open session does not', () => {
  const { days } = weekTimeline(
    [
      session({ id: 'a', scheduled_at: '2025-12-01T23:00:00', status: 'completed' }),
      session({ id: 'b', scheduled_at: '2025-12-02T23:00:00', status: 'completed' }),
      session({ id: 'c', scheduled_at: '2025-12-02T23:40:00', status: 'scheduled' }),
    ],
    { timezone: NY, now: TUESDAY },
  );
  assert.equal(days.find((d) => d.key === '2025-12-01').status, 'done');
  assert.equal(days.find((d) => d.key === '2025-12-02').status, 'scheduled');
  assert.equal(days.find((d) => d.key === '2025-12-03').status, 'rest');
});

test('a day sums the minutes actually scheduled on it', () => {
  const { days } = weekTimeline(
    [
      session({ id: 'a', scheduled_at: '2025-12-02T23:00:00', duration_minutes: 25 }),
      session({ id: 'b', scheduled_at: '2025-12-02T23:40:00', duration_minutes: 20 }),
    ],
    { timezone: NY, now: TUESDAY },
  );
  assert.equal(days.find((d) => d.key === '2025-12-02').totalMinutes, 45);
});

test('blocks are positioned from the top of the window and sorted by time', () => {
  const { days, startHour } = weekTimeline(
    [
      session({ id: 'late', scheduled_at: '2025-12-02T23:40:00' }),
      session({ id: 'early', scheduled_at: '2025-12-02T23:00:00' }),
    ],
    { timezone: NY, now: TUESDAY },
  );
  const blocks = days.find((d) => d.key === '2025-12-02').blocks;
  assert.deepEqual(blocks.map((b) => b.id), ['early', 'late']);
  // 23:00Z is 18:00 in New York, so the window opens at 18.
  assert.equal(startHour, 18);
  assert.equal(blocks[0].startMinutes, 0);
  assert.equal(blocks[1].startMinutes, 40);
});

test('an empty week still draws a readable window', () => {
  const { hours, startHour, endHour } = weekTimeline([], { timezone: NY, now: TUESDAY });
  assert.equal(startHour, 16);
  assert.equal(endHour, 21);
  assert.equal(hours.length, 5);
});

test('a single short session is given at least four hours of grid', () => {
  const { startHour, endHour } = weekTimeline([session()], { timezone: NY, now: TUESDAY });
  assert.ok(endHour - startHour >= 4, `window was ${endHour - startHour}h`);
});

test('a malformed session cannot throw the whole schedule away', () => {
  const { days } = weekTimeline(
    [null, { scheduled_at: 'nonsense' }, {}, session()],
    { timezone: NY, now: TUESDAY },
  );
  assert.equal(days.reduce((sum, day) => sum + day.blocks.length, 0), 1);
});

test('hour labels read as a person says them', () => {
  assert.equal(hourLabel(0), '12 AM');
  assert.equal(hourLabel(9), '9 AM');
  assert.equal(hourLabel(12), '12 PM');
  assert.equal(hourLabel(18), '6 PM');
});

// ─── Materials ───────────────────────────────────────────────────────────────

test('a PDF and a text note are not both filed as documents', () => {
  assert.equal(materialKind({ mime_type: 'application/pdf', modality: 'DOCUMENT' }), 'pdf');
  assert.equal(materialKind({ mime_type: 'text/plain', modality: 'DOCUMENT' }), 'note');
});

test('an image is an image by mime type or by modality', () => {
  assert.equal(materialKind({ mime_type: 'image/png', modality: 'IMAGE' }), 'image');
  assert.equal(materialKind({ mime_type: '', modality: 'IMAGE' }), 'image');
});

test('a PDF with no mime type is still a PDF', () => {
  assert.equal(materialKind({ name: 'Bio ch. 7.PDF', mime_type: '' }), 'pdf');
});

test('filters count what they would show', () => {
  const materials = [
    { name: 'a.pdf', mime_type: 'application/pdf', modality: 'DOCUMENT' },
    { name: 'b.png', mime_type: 'image/png', modality: 'IMAGE' },
    { name: 'c.txt', mime_type: 'text/plain', modality: 'DOCUMENT' },
    { name: 'd.pdf', mime_type: 'application/pdf', modality: 'DOCUMENT' },
  ];
  assert.deepEqual(
    materialFilters(materials).map((f) => [f.key, f.count]),
    [['all', 4], ['pdf', 2], ['image', 1], ['note', 1]],
  );
  assert.equal(filterMaterials(materials, 'pdf').length, 2);
  assert.equal(filterMaterials(materials, 'all').length, 4);
  assert.equal(filterMaterials(materials, undefined).length, 4);
});

test('filters survive a missing materials list', () => {
  assert.deepEqual(materialFilters(undefined).map((f) => f.count), [0, 0, 0, 0]);
  assert.deepEqual(filterMaterials(null, 'pdf'), []);
});

// ─── KPIs ────────────────────────────────────────────────────────────────────

const NOW = new Date('2025-12-02T12:00:00Z');

function kpi(input, key) {
  return buildKpis({ now: NOW, ...input }).find((tile) => tile.key === key);
}

test('nothing assessed never renders as 0%', () => {
  const tile = kpi({ readiness: { topics_total: 6, topics_assessed: 0, readiness: 0 } }, 'readiness');
  assert.equal(tile.value, 'Not measured');
  assert.equal(tile.detail, '0 of 6 topics assessed');
  assert.equal(tile.tone, 'muted');
});

test('a coach goal with no assessed skill never renders as 0%', () => {
  const tile = kpi({
    coachReadiness: { readiness_index: 0, readiness_level: 'not_ready', assessed_skills: 0, total_skills: 14 },
  }, 'readiness');
  assert.equal(tile.value, 'Not measured');
  assert.equal(tile.detail, '0 of 14 skills assessed');
});

test('a readiness that could not be read says so rather than claiming zero', () => {
  assert.equal(kpi({}, 'readiness').value, 'Unavailable');
});

test('plan readiness is read as a 0-1 fraction, not a percentage', () => {
  // 0.8 is 80%. Reading the fraction as a percentage reported a learner at
  // 80% as "1%", which is how this test came to exist.
  assert.equal(kpi({ readiness: { topics_total: 1, topics_assessed: 1, readiness: 0.8 } }, 'readiness').value, '80%');
  assert.deepEqual(
    readinessRing(null, { topics_total: 1, topics_assessed: 1, readiness: 0.8 }),
    { kind: 'measured', percent: 80 },
  );
});

test('a measured readiness is reported as measured', () => {
  const tile = kpi({ readiness: { topics_total: 6, topics_assessed: 4, readiness: 0.644 } }, 'readiness');
  assert.equal(tile.value, '64%');
  assert.equal(tile.tone, 'plain');
});

test('the coach outranks the plan when both have something to say', () => {
  const tile = kpi({
    readiness: { topics_total: 6, topics_assessed: 4, readiness: 0.64 },
    coachReadiness: { readiness_index: 0.8, readiness_level: 'ready', assessed_skills: 12, total_skills: 14 },
  }, 'readiness');
  assert.equal(tile.value, 'Ready');
  assert.equal(tile.tone, 'good');
});

test('days left prefers the server count and falls back to the test date', () => {
  assert.equal(kpi({ readiness: { days_remaining: 12 } }, 'days').value, '12');
  assert.equal(kpi({ profile: { test_date: '2025-12-12' } }, 'days').value, '10');
});

test('the day of the test says Today, and a past test says Passed', () => {
  assert.equal(kpi({ profile: { test_date: '2025-12-02' } }, 'days').value, 'Today');
  assert.equal(kpi({ profile: { test_date: '2025-11-02' } }, 'days').value, 'Passed');
});

test('a test with no date shows a dash, not a zero', () => {
  const tile = kpi({ profile: { test_date: '' } }, 'days');
  assert.equal(tile.value, '—');
  assert.equal(tile.detail, 'No date set');
});

test('a streak of nothing invites a first day instead of boasting zero', () => {
  const tile = kpi({ streak: { current: 0, best: 0 } }, 'streak');
  assert.equal(tile.value, 'Day 1');
  assert.equal(tile.tone, 'muted');
});

test('a streak reads in days and names the best', () => {
  assert.equal(kpi({ streak: { current: 1, best: 9 } }, 'streak').value, '1 day');
  assert.equal(kpi({ streak: { current: 7, best: 12 } }, 'streak').detail, 'Your best is 12');
  assert.equal(kpi({ streak: { current: 12, best: 12 } }, 'streak').detail, 'Your best yet');
});

test('today reports the mission, then the schedule, then nothing', () => {
  assert.equal(kpi({ missionMinutes: 45, missionCount: 3 }, 'today').value, '45 min');
  assert.equal(kpi({ missionMinutes: 45, missionCount: 3 }, 'today').detail, '3 steps on your mission');
  assert.equal(kpi({ dueCount: 2 }, 'today').value, '2 sessions');
  assert.equal(kpi({}, 'today').value, 'Clear');
});

test('the strip is always the same four tiles in the same order', () => {
  assert.deepEqual(buildKpis({}).map((tile) => tile.key), ['days', 'readiness', 'streak', 'today']);
});

// ─── The coach ring ──────────────────────────────────────────────────────────

test('a ring is not drawn at zero when nothing was assessed', () => {
  assert.deepEqual(
    readinessRing({ readiness_index: 0, readiness_level: 'not_ready', assessed_skills: 0, total_skills: 14 }),
    { kind: 'unmeasured', percent: null },
  );
  assert.deepEqual(
    readinessRing(null, { topics_total: 6, topics_assessed: 0, readiness: 0 }),
    { kind: 'unmeasured', percent: null },
  );
});

test('a readiness that could not be read is unknown, not unmeasured', () => {
  assert.deepEqual(readinessRing(null, null), { kind: 'unknown', percent: null });
});

test('a 0-1 index and a 0-100 index both read as the same percentage', () => {
  const asFraction = { readiness_index: 0.64, assessed_skills: 8, total_skills: 14 };
  const asPercent = { readiness_index: 64, assessed_skills: 8, total_skills: 14 };
  assert.deepEqual(readinessRing(asFraction), { kind: 'measured', percent: 64 });
  assert.deepEqual(readinessRing(asPercent), { kind: 'measured', percent: 64 });
});

test('a full index is 100%, not 10000%', () => {
  assert.deepEqual(
    readinessRing({ readiness_index: 1, assessed_skills: 14, total_skills: 14 }),
    { kind: 'measured', percent: 100 },
  );
});

// ─── The mission checklist ───────────────────────────────────────────────────

test('a mission step is done when a session for its concept is done', () => {
  const mission = [
    { skill_id: 's1', concept_id: 'c1', title: 'Cellular respiration' },
    { skill_id: 's2', concept_id: 'c2', title: 'Photosynthesis' },
  ];
  const sessions = [
    { id: 'a', concept_id: 'c1', status: 'completed' },
    { id: 'b', concept_id: 'c2', status: 'scheduled' },
  ];
  assert.deepEqual(missionChecklist(mission, sessions).map((item) => item.done), [true, false]);
});

test('a mission step with no concept is never silently marked done', () => {
  const done = missionChecklist([{ skill_id: 's1', title: 'Loose step' }], [{ status: 'completed' }]);
  assert.equal(done[0].done, false);
});

test('a missing mission or session list is not an error', () => {
  assert.deepEqual(missionChecklist(undefined, undefined), []);
  assert.deepEqual(missionChecklist([{ skill_id: 's1', concept_id: 'c1' }], null)[0].done, false);
});

// ─── Plan progress ───────────────────────────────────────────────────────────

test('plan progress counts completed sessions out of all of them', () => {
  assert.deepEqual(
    planProgress([{ status: 'completed' }, { status: 'scheduled' }, { status: 'completed' }]),
    { done: 2, total: 3 },
  );
  assert.deepEqual(planProgress(undefined), { done: 0, total: 0 });
});
