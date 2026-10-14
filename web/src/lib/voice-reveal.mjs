/**
 * Showing a spoken answer at the speed it is spoken.
 *
 * An answer streams in as fast as the network allows and is read aloud far
 * more slowly, so the whole reply lands on screen before the first word is
 * heard. These helpers turn playback progress into the words said so far, so
 * the text on screen is something to follow rather than something to read
 * ahead of.
 */

/**
 * The opening words of `segment` that playback has reached at `fraction`.
 *
 * Whole words only: revealing half of one is distracting in a way that
 * following along is not. The first word appears as soon as playback starts,
 * so a segment never shows as empty while it is audibly being read.
 */
export function spokenPrefix(segment, fraction) {
  const words = String(segment ?? '').split(/\s+/).filter(Boolean);
  if (words.length === 0) return '';
  const ratio = Number(fraction);
  const clamped = Number.isFinite(ratio) ? Math.min(1, Math.max(0, ratio)) : 0;
  if (clamped <= 0) return '';
  return words.slice(0, Math.max(1, Math.ceil(words.length * clamped))).join(' ');
}

/** Add what is being said now to everything said before it. */
export function joinSpoken(base, part) {
  const said = String(base ?? '').trim();
  const now = String(part ?? '').trim();
  if (!said) return now;
  if (!now) return said;
  return `${said} ${now}`;
}
