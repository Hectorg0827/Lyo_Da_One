import { test } from 'node:test';
import assert from 'node:assert/strict';

import { buildLearnerStats, streakFrom } from './learner-stats.mjs';

const byKey = (result) => Object.fromEntries(result.stats.map((s) => [s.key, s]));

test('leads with concepts once one has reached a rung worth naming', () => {
  const result = buildLearnerStats({
    conceptSummary: { total: 9, learned: 4, mastered: 1, retained: 2, exploring: 3 },
  });
  assert.equal(result.kind, 'concepts');
  const stats = byKey(result);
  assert.equal(stats.learned.value, '4');
  assert.equal(stats.mastered.value, '1');
  assert.equal(stats.retained.value, '2');
  assert.equal(stats.learned.trend, '3 exploring');
});

test('a learner with evidence but nothing named falls back to activity', () => {
  // Three concepts merely met. Showing "0 learned / 0 mastered / 0 retained"
  // as a headline would be a worse claim than showing their XP.
  const result = buildLearnerStats({
    conceptSummary: { total: 3, learned: 0, mastered: 0, retained: 0 },
    gamification: { xp_summary: { total: 800 } },
  });
  assert.equal(result.kind, 'activity');
  assert.equal(byKey(result).xp.value, '800');
});

test('no payloads at all still yields four stats, all honest zeroes', () => {
  const result = buildLearnerStats();
  assert.equal(result.kind, 'activity');
  assert.equal(result.stats.length, 4);
  assert.deepEqual(result.stats.map((s) => s.value), ['0', '0', '0', '0d']);
});

test('server-reported hours are used, not silently replaced by the XP estimate', () => {
  // The regression this guards: `(total_hours || xp) ? round(xp / 100) : 0`
  // displayed "0" for a learner with 40 recorded hours and no XP.
  const result = buildLearnerStats({
    gamification: { user_level: { total_hours: 40 }, xp_summary: { total: 0 } },
  });
  assert.equal(byKey(result).hours.value, '40');
});

test('hours fall back to the XP estimate only when the server sends none', () => {
  const result = buildLearnerStats({ gamification: { xp_summary: { total: 1250 } } });
  assert.equal(byKey(result).hours.value, '13');
});

test('XP and level fall back to the user profile', () => {
  const result = buildLearnerStats({ user: { xp: 300, level: 2 } });
  const stats = byKey(result);
  assert.equal(stats.xp.value, '300');
  assert.equal(stats.xp.trend, 'Level 2');
});

test('level is never reported as 0', () => {
  const result = buildLearnerStats({ gamification: { user_level: { level: 0 } } });
  assert.equal(byKey(result).xp.trend, 'Level 1');
});

test('streak prefers gamification over the user profile', () => {
  assert.deepEqual(streakFrom({ streaks: { current: 7, longest: 12 } }, { streak: 2 }), {
    current: 7,
    best: 12,
  });
});

test('streak falls back to the user profile, and best never trails current', () => {
  assert.deepEqual(streakFrom(undefined, { streak: 5 }), { current: 5, best: 5 });
  assert.deepEqual(streakFrom({ streaks: { current: 9, longest: 3 } }, null), {
    current: 9,
    best: 9,
  });
});

test('the best-streak trend is shown only when it beats the current one', () => {
  const beaten = buildLearnerStats({ gamification: { streaks: { current: 3, longest: 11 } } });
  assert.equal(byKey(beaten).streak.trend, 'Best: 11d');

  const tied = buildLearnerStats({ gamification: { streaks: { current: 11, longest: 11 } } });
  assert.equal(byKey(tied).streak.trend, '');
});

test('an explicit null is no reading, not a reading of zero', () => {
  // `Number(null)` is 0, so a guard written as `Number.isFinite(Number(v))`
  // turns every null the server sends into a real zero. FastAPI serialises
  // `Optional[int] = None` as exactly that, and the learner below is on a
  // seven-day streak.
  assert.deepEqual(streakFrom({ streaks: { current: null, longest: null } }, { streak: 7 }), {
    current: 7,
    best: 7,
  });

  const result = buildLearnerStats({
    gamification: { user_level: { total_hours: null }, xp_summary: { total: 1250 } },
    user: { xp: 1250 },
  });
  // Null hours must fall through to the XP estimate, not display "0".
  assert.equal(byKey(result).hours.value, '13');
});

test('blank and non-numeric shapes are no reading either', () => {
  for (const absent of ['', '   ', true, false, [], {}, 'twelve']) {
    assert.deepEqual(streakFrom({ streaks: { current: absent } }, { streak: 4 }), {
      current: 4,
      best: 4,
    });
  }
});

test('a numeric string is still a reading', () => {
  assert.deepEqual(streakFrom({ streaks: { current: '6', longest: '9' } }, null), {
    current: 6,
    best: 9,
  });
});

test('a real zero is still reported as zero', () => {
  // The fix must not swing the other way: a learner whose streak genuinely
  // lapsed has a streak of 0, and that is a reading.
  assert.deepEqual(streakFrom({ streaks: { current: 0, longest: 14 } }, { streak: 7 }), {
    current: 0,
    best: 14,
  });
});

test('garbage readings do not become numbers', () => {
  const result = buildLearnerStats({
    gamification: { xp_summary: { total: 'lots' }, user_level: { total_hours: NaN } },
  });
  const stats = byKey(result);
  assert.equal(stats.xp.value, '0');
  assert.equal(stats.hours.value, '0');
});

test('every stat carries a short label for the one-line strip', () => {
  for (const payload of [{}, { conceptSummary: { total: 2, learned: 2 } }]) {
    for (const stat of buildLearnerStats(payload).stats) {
      assert.ok(stat.short && stat.short.length <= 8, `short label for ${stat.key}`);
      assert.ok(stat.label, `label for ${stat.key}`);
      assert.ok(stat.sub, `sub for ${stat.key}`);
    }
  }
});
