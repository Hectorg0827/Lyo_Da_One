import type { ChatBlock } from '@/types';

export type StudyAsk = 'flashcards' | 'studyPlan' | 'notes' | 'slides' | 'unrelated';

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
export const DECK_BATCH_SIZE: number;
export const DECK_MAX_CARDS: number;
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

/** The request for the next batch of cards, naming what the learner already has. */
export function moreCardsPrompt(
  topic: string | null | undefined,
  seenFronts?: readonly string[],
  count?: number,
): string;

/** Cards from a reply to `moreCardsPrompt` — JSON or Markdown. */
export function parseMoreCards(reply: string | null | undefined): StudyCard[];

/** `existing` plus the incoming cards it does not already hold, capped at `max`. */
export function mergeCards(
  existing: readonly StudyCard[] | null | undefined,
  incoming: readonly StudyCard[] | null | undefined,
  max?: number,
): StudyCard[];

export interface DeckStepInput {
  index: number;
  revealed: number;
  total: number;
  loading?: boolean;
  exhausted?: boolean;
  max?: number;
}

/** Whether a deck should sit still, show more parsed cards, or fetch a batch. */
export function nextDeckStep(input: DeckStepInput): 'idle' | 'reveal' | 'fetch';

/** Whether a block is study material the backend already supplied. */
export function isStudyBlock(block: unknown): boolean;

/** Whether the turn already carries study material of its own. */
export function hasStudyBlock(blocks: readonly unknown[] | null | undefined): boolean;

/**
 * The blocks a turn should end up with once its deck has been lifted out,
 * or null when there is nothing to add. Replaces the text block the deck was
 * parsed from rather than leaving the same material on screen twice.
 */
export function mergeStudyBlocks(
  existingBlocks: readonly ChatBlock[] | null | undefined,
  extraction: StudyExtraction | null | undefined,
  reply: string | null | undefined,
): ChatBlock[] | null;

export interface LessonSlide {
  title: string;
  body: string;
}

/** The slides in a block worth drawing. Shared by the renderer and can-render. */
export function slideRows(content: unknown): LessonSlide[];
