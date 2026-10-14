/** Bounded, exact state shared by fraction-pie controls and rendering. */
export const MAX_FRACTION_PARTS = 20;

export function isFractionState(state) {
  return !!state && Number.isInteger(state.parts) && state.parts >= 1
    && state.parts <= MAX_FRACTION_PARTS && Number.isInteger(state.value)
    && state.value >= 0 && state.value <= state.parts;
}

export function resizeFraction(state, parts) {
  if (!isFractionState(state) || !Number.isInteger(parts) || parts < 1 || parts > MAX_FRACTION_PARTS) return null;
  // Preserve the number of shaded pieces, bounded by the new whole. The
  // fraction's value intentionally changes when its denominator changes.
  return { parts, value: Math.min(state.value, parts) };
}

export function fractionReadout(state) {
  if (!isFractionState(state)) return null;
  let a = state.value, b = state.parts;
  while (b) { const remainder = a % b; a = b; b = remainder; }
  return {
    fraction: `${state.value}/${state.parts}`,
    reduced: `${state.value / a}/${state.parts / a}`,
    decimal: state.value / state.parts,
    percent: 100 * state.value / state.parts,
  };
}

export function toggleFractionSlice(selected, index, parts) {
  if (!Number.isInteger(parts) || parts < 1 || parts > MAX_FRACTION_PARTS
      || !Number.isInteger(index) || index < 0 || index >= parts) return null;
  const next = new Set(selected.filter(i => Number.isInteger(i) && i >= 0 && i < parts));
  if (next.has(index)) next.delete(index); else next.add(index);
  return [...next].sort((a, b) => a - b);
}

export function fractionSlicePath(index, parts) {
  if (!Number.isInteger(index) || !Number.isInteger(parts) || parts < 1
      || parts > MAX_FRACTION_PARTS || index < 0 || index >= parts) return '';
  if (parts === 1) return 'M 120 20 A 100 100 0 1 1 120 220 A 100 100 0 1 1 120 20 Z';
  const angle = 2 * Math.PI / parts;
  const start = index * angle - Math.PI / 2, end = start + angle;
  const point = a => `${(120 + 100 * Math.cos(a)).toFixed(4)} ${(120 + 100 * Math.sin(a)).toFixed(4)}`;
  return `M 120 120 L ${point(start)} A 100 100 0 0 1 ${point(end)} Z`;
}
