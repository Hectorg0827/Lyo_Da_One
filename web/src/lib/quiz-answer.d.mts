import type { QuizQuestion } from '@/types';

export function isPracticeAnswerCorrect(
  question: QuizQuestion | null | undefined,
  selected: string | number | null | undefined,
): boolean;
