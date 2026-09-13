/** Validate the public, non-grading teaching-tool payload before rendering. */
export function parseTeachingVisual(raw) {
  if (!raw || typeof raw !== 'object' || !['fraction_bar', 'comparison', 'sequence', 'graph'].includes(raw.kind)) return null;
  if (typeof raw.title !== 'string' || typeof raw.caption !== 'string' || typeof raw.description !== 'string') return null;
  if (raw.kind === 'fraction_bar' && (!Number.isInteger(raw.parts) || raw.parts < 2 || raw.parts > 20 || !Number.isFinite(raw.whole) || raw.whole <= 0 || !Number.isInteger(raw.value) || raw.value < 0 || raw.value > raw.parts)) return null;
  if (['comparison', 'sequence'].includes(raw.kind) && (!Array.isArray(raw.entries) || raw.entries.length < 2 || raw.entries.length > 6 || !Number.isInteger(raw.value) || raw.value < 0 || raw.value >= raw.entries.length || raw.entries.some(i => !i || typeof i.label !== 'string' || typeof i.detail !== 'string'))) return null;
  if (raw.kind === 'graph' && (typeof raw.expression !== 'string' || !raw.expression.trim() || !Array.isArray(raw.params) || !raw.params.length || raw.params.length > 3 || raw.params.some(p => !p || typeof p.name !== 'string' || ![p.min, p.max, p.initial, p.step].every(Number.isFinite) || p.step <= 0 || p.min >= p.max || p.initial < p.min || p.initial > p.max) || new Set(raw.params.map(p => p.name)).size !== raw.params.length || ![raw.x_min, raw.x_max, raw.y_min, raw.y_max].every(Number.isFinite) || raw.x_min >= raw.x_max || raw.y_min >= raw.y_max)) return null;
  return raw;
}
