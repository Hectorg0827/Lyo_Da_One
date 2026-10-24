/**
 * Reporting a Discover video.
 *
 * Videos from learners go live as soon as they are published, so reports are
 * what catches the bad ones. Each reason is one the API stores
 * (POST /api/v1/clips/{id}/report). A reported video leaves the reporter's
 * feed at once, and once three different learners report it, it is hidden
 * from everyone until a moderator decides.
 */

export const REPORT_REASONS = [
  { value: 'sexual_content', label: 'Sexual or inappropriate' },
  { value: 'violence', label: 'Violent or dangerous' },
  { value: 'harassment', label: 'Hate or bullying' },
  { value: 'spam', label: 'Spam or misleading' },
  { value: 'misinformation', label: 'Wrong or false science' },
  { value: 'copyright', label: 'Copyright' },
  { value: 'other', label: 'Something else' },
];

/** The longest note the API accepts with a report. */
export const REPORT_NOTE_LIMIT = 1000;

/**
 * A learner cannot report their own video; the API refuses it. When either id
 * is unknown the button stays, and the server decides.
 */
export function canReport(ownerId, viewerId) {
  if (ownerId === null || ownerId === undefined || ownerId === '') return true;
  if (viewerId === null || viewerId === undefined || viewerId === '') return true;
  return String(ownerId) !== String(viewerId);
}

/**
 * Whether to offer blocking a video's owner. Blocking hides both people from
 * each other in Discover, so it needs an owner who is someone else; with
 * either id unknown it is not offered. Library videos are uploaded by Lyo's
 * own account and credited to their source, so blocking that account would
 * empty the library: it is not offered there either.
 */
export function canBlock(ownerId, viewerId, isLibrary) {
  if (isLibrary) return false;
  if (ownerId === null || ownerId === undefined || ownerId === '') return false;
  if (viewerId === null || viewerId === undefined || viewerId === '') return false;
  return String(ownerId) !== String(viewerId);
}

/**
 * What a finished block attempt means. Blocked (201) takes every video by
 * that person out of the feed; 404 means the account is gone. Anything else
 * is a failure the learner can retry.
 */
export function blockOutcome(status, name) {
  if (status === 200 || status === 201) {
    return { blocked: true, message: `Blocked ${name}. You won't see each other's videos or comments.` };
  }
  if (status === 404) return { blocked: false, message: 'This account no longer exists.' };
  return { blocked: false, message: "Couldn't block this account. Please try again." };
}

/**
 * What a finished report attempt means for the feed. Reported (201) and
 * already reported (200) both take the video out of this learner's feed, as
 * does 404: the video is gone or already hidden. Anything else is a failure
 * the learner can retry, and the video stays.
 */
export function reportOutcome(status) {
  if (status === 200 || status === 201) {
    return { leaveFeed: true, message: "Thanks. We'll review this video." };
  }
  if (status === 404) {
    return { leaveFeed: true, message: 'This video is no longer available.' };
  }
  return { leaveFeed: false, message: "Your report couldn't be sent. Please try again." };
}

/**
 * The pages to request for feed page `page` after `removed` loaded videos
 * left the feed, by a report or a block. The server stops sending them to
 * this learner, so every later page starts that many places earlier and the
 * videos at the old page boundary move onto the page before. Asking for that
 * page too, and merging without duplicates, keeps them from being skipped.
 */
export function pagesToFetch(page, removed, perPage) {
  const back = Math.ceil(Math.max(0, removed) / perPage);
  const first = Math.max(1, page - back);
  return Array.from({ length: page - first + 1 }, (_, index) => first + index);
}
