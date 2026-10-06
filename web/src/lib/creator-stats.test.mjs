import test from 'node:test';
import assert from 'node:assert/strict';

import {
  METRICS,
  coverageNote,
  creatorStats,
  isComplete,
  isReported,
} from './creator-stats.mjs';

const clip = (counts = {}) => ({ id: Math.random().toString(36), ...counts });

test('totals add up what every clip reported', () => {
  const { clipCount, totals } = creatorStats([
    clip({ viewCount: 100, likeCount: 5, commentCount: 2, shareCount: 1 }),
    clip({ viewCount: 40, likeCount: 3, commentCount: 0, shareCount: 4 }),
  ]);
  assert.equal(clipCount, 2);
  assert.equal(totals.views.value, 140);
  assert.equal(totals.likes.value, 8);
  assert.equal(totals.comments.value, 2);
  assert.equal(totals.shares.value, 5);
  for (const metric of METRICS) assert.ok(isComplete(totals[metric]), `${metric} should be complete`);
});

test('a count the server did not send is not a zero', () => {
  // Summing with `|| 0` would understate the creator's reach and look
  // exactly like a real total.
  const { totals } = creatorStats([
    clip({ viewCount: 100 }),
    clip({ viewCount: null }),
    clip({}),
  ]);
  assert.equal(totals.views.value, 100);
  assert.equal(totals.views.reporting, 1);
  assert.equal(totals.views.clips, 3);
  assert.equal(isComplete(totals.views), false);
  assert.equal(coverageNote(totals.views), 'from 1 of 3 clips');
});

test('a real zero still counts as reported', () => {
  // A clip genuinely watched zero times reported its figure; that is not the
  // same as a clip whose views are not being counted.
  const { totals } = creatorStats([clip({ viewCount: 0 })]);
  assert.equal(totals.views.value, 0);
  assert.equal(isReported(totals.views), true);
  assert.equal(isComplete(totals.views), true);
  assert.equal(coverageNote(totals.views), null);
});

test('nothing reported is not a zero either', () => {
  const { totals } = creatorStats([clip({}), clip({})]);
  assert.equal(isReported(totals.views), false);
  assert.equal(isComplete(totals.views), false);
  // No note: the surface says "Not reported" instead of a qualified number.
  assert.equal(coverageNote(totals.views), null);
});

test('a complete total carries no qualifier', () => {
  const { totals } = creatorStats([clip({ viewCount: 7 }), clip({ viewCount: 3 })]);
  assert.equal(totals.views.value, 10);
  assert.equal(coverageNote(totals.views), null);
});

test('no clips is no stats, not zeroes', () => {
  const { clipCount, totals } = creatorStats([]);
  assert.equal(clipCount, 0);
  assert.equal(isReported(totals.views), false);
  assert.equal(isComplete(totals.views), false);
});

test('snake_case counts are read too', () => {
  const { totals } = creatorStats([{ view_count: 12, like_count: 1 }]);
  assert.equal(totals.views.value, 12);
  assert.equal(totals.likes.value, 1);
});

test('a non-numeric count is treated as unreported', () => {
  const { totals } = creatorStats([clip({ viewCount: 'lots' }), clip({ viewCount: 5 })]);
  assert.equal(totals.views.value, 5);
  assert.equal(totals.views.reporting, 1);
});
