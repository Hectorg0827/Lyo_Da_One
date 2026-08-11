/**
 * Shared contract for structured chat content blocks.
 *
 * The chat SSE stream carries a `smart_blocks` event whose payload is the
 * backend's SmartBlock envelope (lyo_app/ai/schemas/smart_block.py). Three
 * clients decode it independently — web, iOS (Sources/Models/SmartBlock.swift),
 * and Android — so the vocabulary lives here and is asserted by
 * scripts/verify-chat-blocks-parity.mjs.
 *
 * The existing verify-chat-continuity.mjs covers transport, history, and
 * layout. It would pass green with all three clients rendering completely
 * different content, which is what this file exists to prevent.
 */

/** Wire values of SmartBlockType. Note the camelCase outliers. */
export const CHAT_BLOCK_TYPES = Object.freeze([
  'text',
  'code',
  'quiz',
  'flashcard',
  'dataViz',
  'media',
  'progress',
  'interactive',
  'masteryMap',
  'unknown',
]);

/** Lesson beats, in the order a composed lesson renders them. */
export const LESSON_SECTION_KINDS = Object.freeze([
  'hook',
  'core',
  'representation',
  'example',
  'trap',
  'method',
  'reference',
]);

/** Styling variants a `text/callout` block may carry in content.style. */
export const CALLOUT_VARIANTS = Object.freeze(['trap', 'insight', 'warning']);

/** dataViz content.format values a client may be asked to render. */
export const DATA_VIZ_FORMATS = Object.freeze(['text', 'mermaid', 'chart', 'table', 'math']);

/** Endpoint that grades an in-chat check. */
export const CHAT_CHECK_ENDPOINT = '/api/v1/lyo2/chat/check';

/**
 * Fields a client sends when answering a check.
 *
 * Deliberately excludes the question and the answer key: correctness is
 * decided server-side from the block the server itself emitted. A client that
 * starts sending `correct_index` is asserting its own grade, which is the
 * exact failure this contract exists to prevent.
 */
export const CHECK_REQUEST_FIELDS = Object.freeze([
  'conversation_id',
  'block_id',
  'selected_index',
  'time_taken_ms',
  'hint_used',
]);

/** Fields the grading response returns. */
export const CHECK_RESPONSE_FIELDS = Object.freeze([
  'correct',
  'correct_index',
  'selected_index',
  'explanation',
  'misconception',
  'bailed_out',
  'skill_id',
  'mastery',
]);

/** Mastery rows written from chat carry this source, per LearnerMastery. */
export const CHAT_MASTERY_SOURCE = 'chat';

/**
 * A block type a client does not recognise must be skipped, never rendered as
 * raw JSON and never thrown on — this is what lets the backend add a block
 * type without shipping all three clients first.
 */
export const UNKNOWN_BLOCK_BEHAVIOR = 'skip';

export function isKnownBlockType(type) {
  return CHAT_BLOCK_TYPES.includes(type);
}

export function normalizeCalloutVariant(value) {
  return CALLOUT_VARIANTS.includes(value) ? value : 'trap';
}
