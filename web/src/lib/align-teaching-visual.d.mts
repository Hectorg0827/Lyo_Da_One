import type { TeachingVisual } from './teaching-activity.mjs';
export function alignTeachingVisualToExample(visual: TeachingVisual, exampleTitle: string, exampleContent?: string): TeachingVisual;
export function alignTeachingVisualsOnBoard<T extends { kind: string; title?: string; content?: string; visual?: TeachingVisual }>(board: T[]): T[];
