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
 * `libraryTotal` is the same idea one level up. The clips endpoint is paged,
 * so a creator with 120 clips is handed 50 and the sum over them is not their
 * total — it is the total of one page, and without this it would be labelled
 * complete. Pass the server's own count and a partial page reads "from 50 of
 * 120 clips", which is what it is.
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
function total(clips, metric, libraryTotal) {
  let value = 0;
  let reporting = 0;
  for (const clip of clips) {
    const count = countOf(clip, metric);
    if (count === null) continue;
    value += count;
    reporting += 1;
  }
  return { metric, value, reporting, clips: libraryTotal };
}

/**
 * Every total, plus the clip count.
 *
 * `libraryTotal` is how many clips the creator has, which is not how many
 * arrived: the endpoint is paged. When it is larger than the page, the
 * totals are over the page and say so. When it is missing or smaller, the
 * page is all there is.
 */
export function creatorStats(clips, libraryTotal) {
  const list = Array.isArray(clips) ? clips : [];
  const library =
    typeof libraryTotal === 'number' && Number.isFinite(libraryTotal)
      ? Math.max(libraryTotal, list.length)
      : list.length;
  const totals = {};
  for (const metric of METRICS) totals[metric] = total(list, metric, library);
  return { clipCount: library, loadedCount: list.length, totals };
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
