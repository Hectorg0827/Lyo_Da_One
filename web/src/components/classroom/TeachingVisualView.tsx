'use client';

import { useId, useState } from 'react';
import { ArrowRight, Minus, Plus } from 'lucide-react';
import type { TeachingVisual } from '@/lib/teaching-activity.mjs';
import { useClassroomStore } from '@/stores/classroom-store';
import { Explorable } from './Explorable';

export function TeachingVisualView({ id, visual }: { id: string; visual: TeachingVisual }) {
  const rangeId = useId();
  const [value, setValue] = useState(visual.value);
  const update = useClassroomStore(s => s.updateActivity);
  const spanish = useClassroomStore(s => s.languageCode.startsWith('es'));
  const change = (next: number) => {
    if (update(id, { value: next })) setValue(next);
  };
  return (
    <section aria-label={visual.title} className="overflow-hidden rounded-2xl border border-sky-300/20 bg-gradient-to-br from-sky-400/[0.08] via-slate-900/50 to-violet-400/[0.08] p-5 sm:p-6">
      <div className="mb-5 flex items-start justify-between gap-4">
        <div className="space-y-2">
          <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-sky-300">{spanish ? 'Explora la idea' : 'Explore the idea'}</p>
          <h3 className="text-lg font-semibold leading-snug text-white">{visual.title}</h3>
        </div>
        <span className="rounded-full border border-sky-300/20 bg-sky-300/5 px-3 py-1.5 text-xs text-sky-200">{spanish ? 'Interactivo' : 'Interactive'}</span>
      </div>
      <p className="mb-5 max-w-prose text-sm leading-relaxed text-slate-200">{visual.caption}</p>
      {visual.kind === 'fraction_bar' && (
        <div className="space-y-5">
          <div className="flex items-baseline justify-between gap-3 font-mono tabular-nums">
            <span className="text-3xl font-semibold text-sky-200">{value}<span className="text-xl text-slate-400">/{visual.parts}</span></span>
            <span className="text-lg text-white">{Number((visual.whole * value / visual.parts).toFixed(3))} <span className="font-sans text-sm text-slate-300">{visual.unit}</span></span>
          </div>
          <svg viewBox="0 0 600 64" className="h-16 w-full" role="img" aria-label={`${value}/${visual.parts} · ${visual.description}`}>
            {Array.from({ length: visual.parts }, (_, index) => (
              <rect key={index} x={index * 600 / visual.parts + 1.5} y={1} width={600 / visual.parts - 3} height={62} rx={5}
                fill={index < value ? '#7DD3FC' : '#1E293B'} stroke={index < value ? '#BAE6FD' : '#475569'} />
            ))}
          </svg>
          <div className="flex items-center gap-4">
            <button type="button" onClick={() => change(Math.max(0, value - 1))} disabled={value === 0} aria-label={spanish ? 'Quitar una parte' : 'Remove one part'} className="grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-white/15 text-slate-200 disabled:opacity-30"><Minus className="h-4 w-4" /></button>
            <input id={rangeId} type="range" min={0} max={visual.parts} step={1} value={value} onChange={e => change(Number(e.target.value))}
              aria-label={visual.title} aria-valuetext={`${value}/${visual.parts}`} className="h-11 min-w-0 flex-1 accent-sky-300" />
            <button type="button" onClick={() => change(Math.min(visual.parts, value + 1))} disabled={value === visual.parts} aria-label={spanish ? 'Añadir una parte' : 'Add one part'} className="grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-white/15 text-slate-200 disabled:opacity-30"><Plus className="h-4 w-4" /></button>
          </div>
        </div>
      )}
      {(visual.kind === 'comparison' || visual.kind === 'sequence') && (
        <div className="space-y-3">
          <div className={visual.kind === 'comparison' ? 'grid grid-cols-1 gap-2 sm:grid-cols-2' : 'flex flex-wrap gap-2'}>
            {visual.entries.map((item, index) => (
              <button key={index} type="button" aria-pressed={value === index} onClick={() => change(index)}
                className={`flex min-h-12 items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm transition-colors ${value === index ? 'border-sky-300/60 bg-sky-300/10 text-white' : 'border-white/10 bg-slate-950/30 text-slate-300 hover:border-white/30'}`}>
                {visual.kind === 'sequence' && <span className="font-mono text-sky-300">{index + 1}</span>}{item.label}
                {value === index && <ArrowRight className="ml-auto h-4 w-4 shrink-0 text-sky-300" />}
              </button>
            ))}
          </div>
          <p aria-live="polite" className="rounded-xl border border-sky-300/15 bg-slate-950/35 p-4 text-base leading-relaxed text-slate-100">{visual.entries[value]?.detail}</p>
        </div>
      )}
      {visual.kind === 'graph' && <Explorable expression={visual.expression} params={visual.params} xMin={visual.x_min} xMax={visual.x_max}
        yMin={visual.y_min} yMax={visual.y_max}
        onValuesChange={params => update(id, { params })} />}
      <p className="sr-only">{visual.description}</p>
    </section>
  );
}
