/**
 * What a creator's clips add up to.
 *
 * People need to see their numbers moving before they will believe there is
 * anything to build here, so this is the scoreboard. Which makes it exactly
 * the place where a number must not be invented: a creator deciding whether
 * this is worth their time is the last person who should be shown a figure
 * the server never sent.
 *
 * Every count on a clip is optional — `viewCount`, `likeCount`,
 * `commentCount` and `shareCount` all arrive null when the backend has
 * nothing to say. Summing them with `|| 0` would silently understate a
 * creator's reach and look exactly like a real total, so each total carries
 * how many clips actually reported it. A total covering 7 of 10 clips says
 * so; one covering none is not a zero.
 *
 * Mirrors iOS `CreatorStats` and Android `CreatorStats`.
 */

/** The metrics a clip can report, in the order they are shown. */
export const METRICS = Object.freeze(['views', 'likes', 'comments', 'shares']);

export const METRIC_LABELS = Object.freeze({
  views: 'Views',
  likes: 'Likes',
  comments: 'Comments',
  shares: 'Shares',
});

const FIELDS = Object.freeze({
  views: ['viewCount', 'view_count'],
  likes: ['likeCount', 'like_count'],
  comments: ['commentCount', 'comment_count'],
  shares: ['shareCount', 'share_count'],
});

/** A count on one clip, or null when the clip did not report it. */
function countOf(clip, metric) {
  for (const field of FIELDS[metric]) {
    const value = clip?.[field];
    if (typeof value === 'number' && Number.isFinite(value)) return value;
  }
  return null;
}

/**
 * One total across a creator's clips.
 *
 * `reporting` is the honest part: `value` is the sum of what was reported,
 * and `reporting` says how much of the library that covers.
 */
function total(clips, metric) {
  let value = 0;
  let reporting = 0;
  for (const clip of clips) {
    const count = countOf(clip, metric);
    if (count === null) continue;
    value += count;
    reporting += 1;
  }
  return { metric, value, reporting, clips: clips.length };
}

/** Every total, plus the clip count — which is always known. */
export function creatorStats(clips) {
  const list = Array.isArray(clips) ? clips : [];
  const totals = {};
  for (const metric of METRICS) totals[metric] = total(list, metric);
  return { clipCount: list.length, totals };
}

/**
 * Whether this total has anything behind it at all.
 *
 * False means no clip reported the figure. The surface shows that as "Not
 * reported" rather than 0, because a creator whose views are not being
 * counted needs to know that, not be told nobody watched.
 */
export function isReported(total) {
  return (total?.reporting ?? 0) > 0;
}

/** Whether every clip reported this figure. */
export function isComplete(total) {
  return (total?.clips ?? 0) > 0 && (total?.reporting ?? 0) === total.clips;
}

/**
 * The qualifier shown under a partial total, or null when there is none.
 *
 * A total that covers the whole library needs no note. One that does not says
 * what it covers, so the number is readable as the floor it is.
 */
export function coverageNote(total) {
  if (!isReported(total) || isComplete(total)) return null;
  return `from ${total.reporting} of ${total.clips} clips`;
}
