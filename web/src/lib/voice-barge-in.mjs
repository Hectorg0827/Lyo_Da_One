/**
 * Deciding whether Lyo has actually been interrupted.
 *
 * While Lyo is speaking, its own voice reaches the microphone through the
 * speaker, and the recognizer transcribes it like anything else. Rejecting
 * those words by comparing them to what Lyo is saying catches the clean
 * cases, but speaker bleed is distorted: the engine frequently returns words
 * that are not in Lyo's answer at all. Those are not echoes by any text
 * comparison, so words alone cannot decide — on that rule Lyo hears a
 * stranger in its own voice and hangs up on itself.
 *
 * Loudness is the signal that tells them apart, because Lyo's bleed cannot be
 * meaningfully louder than Lyo currently is. So an interruption needs both:
 * speech the recognizer resolved, and a microphone that rose above Lyo's own
 * level while it did.
 */

/**
 * Whether recognized speech during playback should end Lyo's turn.
 *
 * `monitorState` says what the volume monitor can contribute:
 * - `ready`: measuring, so its verdict is required.
 * - `pending`: still being granted the microphone. Playback has only just
 *   begun — the moment self-interruption is most likely — so the turn is
 *   held rather than ended on words that cannot yet be corroborated.
 * - `unavailable`: refused or unsupported. Words are the only evidence there
 *   will be, and barge-in has to keep working without it.
 */
export function shouldEndTurnOnSpeech({ isEcho, loudEnough, monitorState } = {}) {
  if (isEcho) return false;
  if (monitorState === 'unavailable') return true;
  return Boolean(loudEnough);
}
