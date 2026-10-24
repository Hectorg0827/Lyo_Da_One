/**
 * The moderator page's rules, kept apart from the page so they can be tested.
 *
 * Three views of Discover: videos learners reported (most reporters first),
 * every video, and the ones a moderator removed. Keep closes a video's
 * reports and serves it again; Remove takes it out of Discover and its files
 * offline; Restore undoes a removal (LyoBackendJune clip_moderation.py).
 */
import { REPORT_REASONS } from './discover-report.mjs';

export const MODERATION_VIEWS = [
  { id: 'reported', label: 'Reported', empty: 'No reported videos right now. New reports from learners appear here.' },
  { id: 'all', label: 'All videos', empty: 'No videos match.' },
  { id: 'removed', label: 'Removed', empty: 'Nothing has been removed.' },
];

// Reasons the API accepts that the Discover report sheet does not offer.
const OTHER_REASON_LABELS = {
  hate_speech: 'Hate speech',
  impersonation: 'Impersonation',
  inappropriate: 'Inappropriate',
};

export function reasonLabel(value) {
  return REPORT_REASONS.find((reason) => reason.value === value)?.label ?? OTHER_REASON_LABELS[value] ?? value;
}

/** The decisions a clip offers, in order. Keep only means something when there is something to clear. */
export function actionsFor(clip) {
  const status = clip?.moderationStatus;
  if (status === 'removed') return ['restore'];
  const pending = clip?.reports?.pending ?? 0;
  return status === 'hidden' || pending > 0 ? ['keep', 'remove'] : ['remove'];
}

export function statusLabel(status) {
  return { active: 'Showing', hidden: 'Hidden until you decide', removed: 'Removed' }[status] ?? status;
}

export const DECISION_MESSAGES = {
  keep: 'Kept. The video is showing again.',
  remove: 'Removed. The video and its files are offline.',
  restore: 'Restored. The video is showing again.',
};

/** Whether a clip, as the server returned it after a decision, still belongs in a view. */
export function belongsIn(view, clip) {
  const status = clip?.moderationStatus;
  if (view === 'removed') return status === 'removed';
  if (view === 'all') return status !== 'removed';
  return status !== 'removed' && (clip?.reports?.pending ?? 0) > 0;
}
