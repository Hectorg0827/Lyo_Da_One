'use client';

import { useId, useRef, useState } from 'react';
import { RotateCcw } from 'lucide-react';
import { fractionReadout, fractionSlicePath, isFractionState, resizeFraction, toggleFractionSlice } from '@/lib/fraction-pie.mjs';
import type { FractionState } from '@/lib/fraction-pie';

/** Shared by Chat, Classroom, and Test Prep. Controls are exploratory, never grades. */
export function FractionPie({ initial, whole = 1, unit = '', spanish = false, onChange }: {
  initial: FractionState;
  whole?: number;
  unit?: string;
  spanish?: boolean;
  onChange?: (state: FractionState) => void;
}) {
  const controlId = useId();
  const safeInitial = isFractionState(initial) ? initial : { parts: 1, value: 0 };
  const original = useRef(safeInitial);
  const [state, setState] = useState(safeInitial);
  const [selected, setSelected] = useState(() => Array.from({ length: safeInitial.value }, (_, i) => i));
  const readout = fractionReadout(state);
  if (!isFractionState(initial) || !readout) return null;

  const change = (next: FractionState, slices = Array.from({ length: next.value }, (_, i) => i)) => {
    setState(next);
    setSelected(slices);
    onChange?.(next);
  };
  const numerator = spanish ? 'Numerador · partes sombreadas' : 'Numerator · shaded slices';
  const denominator = spanish ? 'Denominador · partes iguales' : 'Denominator · equal slices';
  const format = (n: number) => new Intl.NumberFormat(spanish ? 'es' : 'en', { maximumFractionDigits: 3 }).format(n);

  return (
    <div className="space-y-5" data-fraction-pie>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <output aria-live="polite" aria-atomic="true" className="font-mono text-4xl font-semibold tabular-nums text-sky-200">
          {readout.fraction}
          <span className="ml-3 text-base font-normal text-slate-300">= {format(readout.decimal)} · {format(readout.percent)}%</span>
        </output>
        <button type="button" onClick={() => change(original.current)}
          className="flex min-h-11 items-center gap-2 rounded-xl border border-white/15 px-3 text-xs text-slate-200 hover:bg-white/5">
          <RotateCcw className="h-3.5 w-3.5" />{spanish ? 'Reiniciar' : 'Reset'}
        </button>
      </div>
      <p className="text-sm text-slate-300">
        {spanish ? 'Forma simplificada' : 'Simplest form'}: <span className="font-mono text-sky-200">{readout.reduced}</span>
        {whole !== 1 && <> · {format(whole * readout.decimal)} {unit}</>}
      </p>
      <svg viewBox="0 0 240 240" className="mx-auto w-full max-w-[280px] touch-manipulation" role="group"
        aria-label={spanish ? 'Diagrama de fracciones. Toca las partes para sombrearlas.' : 'Fraction pie. Tap slices to shade or clear them.'}>
        {Array.from({ length: state.parts }, (_, index) => {
          const shaded = selected.includes(index);
          return <path key={`${state.parts}-${index}`} d={fractionSlicePath(index, state.parts)} role="button" tabIndex={0}
            aria-pressed={shaded}
            aria-label={spanish ? `Parte ${index + 1} de ${state.parts}` : `Slice ${index + 1} of ${state.parts}`}
            onClick={() => {
              const slices = toggleFractionSlice(selected, index, state.parts);
              if (slices) change({ ...state, value: slices.length }, slices);
            }}
            onKeyDown={event => {
              if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                const slices = toggleFractionSlice(selected, index, state.parts);
                if (slices) change({ ...state, value: slices.length }, slices);
              }
            }}
            fill={shaded ? '#7dd3fc' : '#1e293b'} stroke="#0f172a" strokeWidth={2}
            className="cursor-pointer transition-colors hover:fill-sky-400 focus:fill-sky-400 focus:outline-none" />;
        })}
      </svg>
      <div className="space-y-4">
        <div>
          <label htmlFor={`${controlId}-numerator`} className="mb-2 flex justify-between text-sm text-slate-200">
            {numerator}<span className="font-mono text-sky-200">{state.value}</span>
          </label>
          <input id={`${controlId}-numerator`} type="range" min={0} max={state.parts} step={1} value={state.value}
            aria-valuetext={readout.fraction} className="h-11 w-full accent-sky-300"
            onChange={event => change({ ...state, value: Number(event.target.value) })} />
        </div>
        <div>
          <label htmlFor={`${controlId}-denominator`} className="mb-2 flex justify-between text-sm text-slate-200">
            {denominator}<span className="font-mono text-sky-200">{state.parts}</span>
          </label>
          <input id={`${controlId}-denominator`} type="range" min={1} max={20} step={1} value={state.parts}
            className="h-11 w-full accent-violet-300"
            onChange={event => {
              const next = resizeFraction(state, Number(event.target.value));
              if (next) change(next);
            }} />
        </div>
      </div>
      <p className="text-xs leading-relaxed text-slate-400">
        {spanish ? 'El entero permanece igual. Cambiar el denominador cambia el tamaño de cada parte.' : 'The whole stays the same. Changing the denominator changes the size of each slice.'}
      </p>
    </div>
  );
}
