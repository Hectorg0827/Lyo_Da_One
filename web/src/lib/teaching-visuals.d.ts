import type { ChatBlock } from '@/types';

export type VisualSegment =
  | { kind: 'text'; text: string }
  | { kind: 'mermaid'; source: string }
  | { kind: 'chart'; source: string }
  | { kind: 'image'; url: string; alt: string };

/** The reply split into prose and the visuals in it, or null when it has none. */
export function segmentVisuals(text: string | null | undefined): VisualSegment[] | null;

/** Whether a chart payload is one the chart renderer will actually draw. */
export function isDrawableChart(body: string | null | undefined): boolean;

/**
 * The blocks a turn should end up with once its visuals are drawable, or null
 * when nothing needed lifting. Prose around each visual keeps its position.
 */
export function expandVisualBlocks(
  blocks: readonly ChatBlock[] | null | undefined,
  idPrefix?: string,
): ChatBlock[] | null;
