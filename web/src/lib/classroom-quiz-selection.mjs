/**
 * Visual selection must use the same stable option ID sent to Classroom.
 * AI-generated options can have duplicate labels; comparing labels would
 * incorrectly highlight both choices after the learner selects only one.
 *
 * Legacy saved boards stored only answeredLabel. We allow their unique label
 * to restore selection, but never claim which of two indistinguishable labels
 * was chosen without an ID.
 */
export function quizOptionIsSelected(option, options, answeredLabel, answeredOptionId) {
  if (answeredOptionId) return option?.id === answeredOptionId;
  if (!answeredLabel) return false;
  const matches = (options ?? []).filter((candidate) => candidate.label === answeredLabel);
  return matches.length === 1 && matches[0].id === option?.id;
}
