import type { ChatBlock } from '@/types';

export type StudyAsk = 'flashcards' | 'studyPlan' | 'notes' | 'unrelated';

export interface StudyCard {
  front: string;
  back: string;
}

export interface StudyExtraction {
  /** A lead `text` block plus the study block the reply was describing. */
  blocks: ChatBlock[];
  /** The prose left over once the material was lifted out. */
  displayText: string;
}

export const STUDY_ASKS: readonly StudyAsk[];
export const MIN_LABELLED_CARDS: number;
export const MIN_INLINE_CARDS: number;

export function classifyStudyAsk(userAsk: string | null | undefined): StudyAsk;

/** The first brace-balanced JSON object in the text, or null. */
export function balancedObject(text: string | null | undefined): string | null;

/**
 * The blocks a prose reply is describing, or null to leave the reply alone.
 * Returns null whenever restructuring would be a guess rather than a reading.
 */
export function extractStudyBlocks(
  reply: string | null | undefined,
  userAsk: string | null | undefined,
  idPrefix?: string,
): StudyExtraction | null;
