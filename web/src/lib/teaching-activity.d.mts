export interface TeachingVisualItem {
  label: string;
  detail: string;
  position?: number | null;
  x?: number | null;
  y?: number | null;
}
export interface TeachingVisual {
  visual_id: string;
  kind: 'fraction_bar' | 'comparison' | 'sequence' | 'graph' | 'process_flow' | 'timeline' | 'number_line' | 'annotated_image';
  title: string;
  caption: string;
  description: string;
  parts: number;
  whole: number;
  unit: string;
  value: number;
  entries: TeachingVisualItem[];
  expression: string;
  params: { name: string; min: number; max: number; initial: number; step: number }[];
  x_min: number;
  x_max: number;
  y_min: number;
  y_max: number;
  image_query: string;
  image_url?: string | null;
  source_url?: string | null;
  attribution?: string | null;
}
export function parseTeachingVisual(raw: unknown): TeachingVisual | null;
