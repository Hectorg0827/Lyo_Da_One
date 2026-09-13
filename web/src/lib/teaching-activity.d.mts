export interface TeachingVisual {
  kind: 'fraction_bar' | 'comparison' | 'sequence' | 'graph';
  title: string;
  caption: string;
  description: string;
  parts: number;
  whole: number;
  unit: string;
  value: number;
  entries: { label: string; detail: string }[];
  expression: string;
  params: { name: string; min: number; max: number; initial: number; step: number }[];
  x_min: number;
  x_max: number;
  y_min: number;
  y_max: number;
}
export function parseTeachingVisual(raw: unknown): TeachingVisual | null;
