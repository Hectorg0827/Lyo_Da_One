export interface FractionState { parts: number; value: number; }
export const MAX_FRACTION_PARTS: 20;
export function isFractionState(state: unknown): state is FractionState;
export function resizeFraction(state: FractionState, parts: number): FractionState | null;
export function fractionReadout(state: FractionState): { fraction: string; reduced: string; decimal: number; percent: number } | null;
export function toggleFractionSlice(selected: number[], index: number, parts: number): number[] | null;
export function fractionSlicePath(index: number, parts: number): string;
