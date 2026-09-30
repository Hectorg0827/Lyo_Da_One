/** Validate the public, non-grading teaching-tool payload before rendering. */
export function parseTeachingVisual(raw) {
  const kinds = ['fraction_bar', 'comparison', 'sequence', 'graph', 'process_flow', 'timeline', 'number_line', 'annotated_image'];
  if (!raw || typeof raw !== 'object' || !kinds.includes(raw.kind)) return null;
  if (typeof raw.title !== 'string' || typeof raw.caption !== 'string' || typeof raw.description !== 'string') return null;
  if (raw.visual_id != null && (typeof raw.visual_id !== 'string' || raw.visual_id.length < 8)) return null;

  const entriesValid = Array.isArray(raw.entries)
    && raw.entries.every(i => i && typeof i.label === 'string' && typeof i.detail === 'string');

  if (raw.kind === 'fraction_bar' && (
    !Number.isInteger(raw.parts) || raw.parts < 2 || raw.parts > 20
    || !Number.isFinite(raw.whole) || raw.whole <= 0
    || !Number.isInteger(raw.value) || raw.value < 0 || raw.value > raw.parts
  )) return null;

  if (['comparison', 'sequence', 'process_flow', 'timeline'].includes(raw.kind) && (
    !entriesValid || raw.entries.length < 2 || raw.entries.length > 8
    || !Number.isInteger(raw.value) || raw.value < 0 || raw.value >= raw.entries.length
  )) return null;

  if (raw.kind === 'number_line' && (
    !entriesValid || raw.entries.length < 2 || raw.entries.length > 8
    || !Number.isFinite(raw.x_min) || !Number.isFinite(raw.x_max) || raw.x_min >= raw.x_max
    || !Number.isInteger(raw.value) || raw.value < 0 || raw.value >= raw.entries.length
    || raw.entries.some(i => !Number.isFinite(i.position) || i.position < raw.x_min || i.position > raw.x_max)
  )) return null;

  if (raw.kind === 'annotated_image' && (
    typeof raw.image_query !== 'string' || !raw.image_query.trim()
    || !entriesValid
    || raw.entries.some(i => (i.x == null) !== (i.y == null)
      || (i.x != null && (!Number.isFinite(i.x) || i.x < 0 || i.x > 1))
      || (i.y != null && (!Number.isFinite(i.y) || i.y < 0 || i.y > 1)))
    || (raw.image_url != null && (typeof raw.image_url !== 'string' || !raw.image_url.startsWith('https://upload.wikimedia.org/')))
    || (raw.source_url != null && (typeof raw.source_url !== 'string' || !raw.source_url.startsWith('https://commons.wikimedia.org/')))
  )) return null;

  if (raw.kind === 'graph' && (
    typeof raw.expression !== 'string' || !raw.expression.trim()
    || !Array.isArray(raw.params) || !raw.params.length || raw.params.length > 3
    || raw.params.some(p => !p || typeof p.name !== 'string'
      || ![p.min, p.max, p.initial, p.step].every(Number.isFinite)
      || p.step <= 0 || p.min >= p.max || p.initial < p.min || p.initial > p.max)
    || new Set(raw.params.map(p => p.name)).size !== raw.params.length
    || ![raw.x_min, raw.x_max, raw.y_min, raw.y_max].every(Number.isFinite)
    || raw.x_min >= raw.x_max || raw.y_min >= raw.y_max
  )) return null;
  return raw;
}
