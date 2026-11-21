/** The classroom already offers a separate skip/help action for uncertainty.
 * Suppress an equivalent LLM-generated answer option to avoid two ways of
 * saying the same thing and accidentally grading uncertainty as a mistake.
 */
export function isUncertainAnswerLabel(value) {
  const label = String(value ?? '').trim().toLowerCase().replace(/[.!?]+$/, '');
  return /^(?:i(?: am|'m) not sure(?: yet)?|todav[ií]a no lo s[eé]|a[uú]n no lo s[eé]|no estoy segur[oa])$/.test(label);
}
