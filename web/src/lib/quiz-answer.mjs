/**
 * Local practice-quiz scoring. This never substitutes for the server's
 * authenticated Classroom grade or mastery evidence.
 *
 * Saved multiple-choice questions may encode correctAnswer as the option
 * text, a zero-based option index, or an A/B/C/D key. Compare selection and
 * feedback through the SAME function to prevent green feedback + zero score.
 */
const normalized = (value) =>
  typeof value === "string" ? value.trim().toLocaleLowerCase("en") : null;

export function isPracticeAnswerCorrect(question, selected) {
  if (!question || selected === null || selected === undefined) return false;
  const answer = question.correctAnswer;
  if (answer === null || answer === undefined) return false;

  if (question.type === "multiple_choice") {
    if (!Array.isArray(question.options) || question.options.length === 0) return false;
    const options = question.options;
    const selectedIndex = typeof selected === "number"
      ? selected
      : options.findIndex((option) => option === selected);
    if (!Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex >= options.length) {
      return false;
    }

    if (typeof answer === "number") {
      return Number.isInteger(answer) && selectedIndex === answer;
    }
    if (typeof answer !== "string" || !answer.trim()) return false;
    const normalizedAnswer = normalized(answer);

    // Prefer literal option text over interpreting "A" or "1" as a key.
    const exactTextIndices = options.flatMap((option, index) =>
      normalized(option) === normalizedAnswer ? [index] : []);
    if (exactTextIndices.length) return exactTextIndices.includes(selectedIndex);

    const letter = answer.trim().toUpperCase();
    if (/^[A-Z]$/.test(letter)) return selectedIndex === letter.charCodeAt(0) - 65;

    // Numeric-string answer keys are zero-based, matching numeric keys.
    if (/^\d+$/.test(answer.trim())) return selectedIndex === Number(answer.trim());
    return false;
  }

  if (question.type === "true_false") {
    const actual = normalized(selected);
    const expected = typeof answer === "number"
      ? (answer === 1 ? "true" : answer === 0 ? "false" : null)
      : normalized(answer);
    return (actual === "true" || actual === "false") && actual === expected;
  }

  if (question.type === "fill_blank") {
    const actual = normalized(selected);
    const expected = normalized(answer);
    return Boolean(actual) && actual === expected;
  }

  // Exact string equality cannot grade code semantics or AI explanations.
  return false;
}
