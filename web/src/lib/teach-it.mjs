/**
 * Teach-it prompt — what the app says when a learner finishes something, and
 * how long the clip it asks for may run.
 *
 * A new video feed's hardest problem is supply, not demand: an empty Discover
 * is a dead Discover. Finishing a lesson is the one moment a learner has
 * something specific to say and feels good enough to say it, and the app
 * already knows what they just covered — so the invitation can name it
 * instead of asking into the void.
 *
 * Mirrors iOS `ClipPrompt` and Android `ClipPrompt`.
 */

/**
 * How long a single-take clip may run, in seconds.
 *
 * Shared with the recorder, so the invitation cannot promise a length the
 * camera will not allow.
 */
export const QUICK_TAKE_SECONDS = 60;

/** What the finish screen offers. */
export const CALL_TO_ACTION = 'Teach it';

function trimmed(value) {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text.length > 0 ? text : null;
}

/**
 * The sentence above the button.
 *
 * A known topic is named, because "teach Organic Chemistry" is far easier to
 * act on than "teach something". An unknown one is not invented — a prompt
 * that confidently names the wrong course is worse than one naming none.
 */
export function invitation(topic) {
  const name = trimmed(topic);
  if (name) return `You just finished ${name}. Teach it in ${QUICK_TAKE_SECONDS} seconds?`;
  return `Teach what you just learned in ${QUICK_TAKE_SECONDS} seconds?`;
}

/**
 * The title the composer opens with, or null to leave it empty.
 *
 * Null rather than a placeholder when the topic is unknown: a title the
 * learner did not write and did not mean is published under their name.
 */
export function draftTitle(topic) {
  const name = trimmed(topic);
  return name ? `What I learned about ${name}` : null;
}

/** The subject the composer tags the clip with, or null when unknown. */
export function draftSubject(topic) {
  return trimmed(topic);
}
