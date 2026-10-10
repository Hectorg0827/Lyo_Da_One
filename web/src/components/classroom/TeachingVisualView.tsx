'use client';

import { useId, useState } from 'react';
import { ArrowRight, Minus, Plus } from 'lucide-react';
import type { TeachingVisual } from '@/lib/teaching-activity.mjs';
import { useClassroomStore } from '@/stores/classroom-store';
import { Explorable } from './Explorable';
import { FractionPie } from '@/components/shared/FractionPie';

export function TeachingVisualView({ id, visual }: { id: string; visual: TeachingVisual }) {
  const update = useClassroomStore(s => s.updateActivity);
  const spanish = useClassroomStore(s => s.languageCode.startsWith('es'));
  return <TeachingVisualCard id={id} visual={visual} spanish={spanish} onUpdate={values => { update(id, values); }} />;
}

/** Surface-independent renderer; only its caller decides where updates go. */
export function TeachingVisualCard({ id, visual, spanish = false, onUpdate }: {
  id: string;
  visual: TeachingVisual;
  spanish?: boolean;
  onUpdate?: (values: Record<string, unknown>) => void;
}) {
  const rangeId = useId();
  const [value, setValue] = useState(visual.value);
  const change = (next: number) => {
    setValue(next);
    onUpdate?.({ value: next });
  };

  const entryButtons = (numbered = false) => (
    <div className="space-y-2">
      {visual.entries.map((item, index) => (
        <button key={index} type="button" aria-pressed={value === index} onClick={() => change(index)}
          className={`flex min-h-12 w-full items-start gap-3 rounded-xl border px-4 py-3 text-left text-sm transition-colors ${value === index ? 'border-sky-300/60 bg-sky-300/10 text-white' : 'border-white/10 bg-slate-950/30 text-slate-300 hover:border-white/30'}`}>
          {numbered && <span className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full border border-sky-300/30 font-mono text-xs text-sky-300">{index + 1}</span>}
          <span className="min-w-0">
            <span className="block font-medium">{item.label}</span>
            {value === index && <span className="mt-1 block leading-relaxed text-slate-200">{item.detail}</span>}
          </span>
          {value === index && <ArrowRight className="ml-auto mt-1 h-4 w-4 shrink-0 text-sky-300" />}
        </button>
      ))}
    </div>
  );

  return (
    <section aria-label={visual.title} className="overflow-hidden rounded-2xl border border-sky-300/20 bg-gradient-to-br from-sky-400/[0.08] via-slate-900/50 to-violet-400/[0.08] p-5 sm:p-6">
      <div className="mb-5 flex items-start justify-between gap-4">
        <div className="space-y-2">
          <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-sky-300">{spanish ? 'Mira y explora' : 'See and explore'}</p>
          <h3 className="text-lg font-semibold leading-snug text-white">{visual.title}</h3>
        </div>
        <span className="rounded-full border border-sky-300/20 bg-sky-300/5 px-3 py-1.5 text-xs text-sky-200">{spanish ? 'Visual' : 'Visual'}</span>
      </div>
      <p className="mb-5 max-w-prose text-sm leading-relaxed text-slate-200">{visual.caption}</p>

      {visual.kind === 'fraction_pie' && <FractionPie key={visual.visual_id || id}
        initial={{ parts: visual.parts, value: visual.value }} whole={visual.whole} unit={visual.unit} spanish={spanish}
        onChange={next => onUpdate?.({ parts: next.parts, value: next.value })} />}

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

      {visual.kind === 'process_flow' && (
        <div className="space-y-3">
          <div className="flex flex-col gap-2">
            {visual.entries.map((item, index) => (
              <div key={index}>
                <button type="button" onClick={() => change(index)} aria-pressed={value === index}
                  className={`w-full rounded-xl border px-4 py-3 text-left ${value === index ? 'border-sky-300/60 bg-sky-300/10' : 'border-white/10 bg-slate-950/30'}`}>
                  <span className="font-medium text-white">{item.label}</span>
                  {value === index && <span className="mt-1 block text-sm leading-relaxed text-slate-200">{item.detail}</span>}
                </button>
                {index < visual.entries.length - 1 && <div aria-hidden className="mx-auto h-5 w-px bg-sky-300/35" />}
              </div>
            ))}
          </div>
        </div>
      )}

      {visual.kind === 'timeline' && (
        <div className="relative space-y-3 before:absolute before:bottom-2 before:left-3 before:top-2 before:w-px before:bg-sky-300/25">
          {visual.entries.map((item, index) => (
            <button key={index} type="button" onClick={() => change(index)} aria-pressed={value === index}
              className="relative flex w-full gap-4 pl-1 text-left">
              <span className={`z-10 mt-3 h-5 w-5 shrink-0 rounded-full border-2 ${value === index ? 'border-sky-200 bg-sky-300' : 'border-slate-500 bg-slate-900'}`} />
              <span className={`flex-1 rounded-xl border p-3 ${value === index ? 'border-sky-300/50 bg-sky-300/10' : 'border-white/10 bg-slate-950/25'}`}>
                <span className="font-medium text-white">{item.label}</span>
                {value === index && <span className="mt-1 block text-sm leading-relaxed text-slate-200">{item.detail}</span>}
              </span>
            </button>
          ))}
        </div>
      )}

      {visual.kind === 'number_line' && (
        <div className="space-y-4">
          <div className="relative h-28 overflow-visible px-4">
            <div className="absolute left-4 right-4 top-14 h-0.5 bg-slate-500" />
            {visual.entries.map((item, index) => {
              const position = item.position ?? visual.x_min;
              const pct = ((position - visual.x_min) / (visual.x_max - visual.x_min)) * 100;
              return (
                <button key={index} type="button" onClick={() => change(index)}
                  style={{ left: `calc(${pct}% - 0.75rem)` }}
                  className="absolute top-8 flex w-6 flex-col items-center gap-1" aria-label={`${item.label}: ${position}`}>
                  <span className={`h-6 w-6 rounded-full border-2 ${value === index ? 'border-sky-100 bg-sky-300' : 'border-slate-400 bg-slate-900'}`} />
                  <span className="whitespace-nowrap font-mono text-xs text-slate-200">{item.label}</span>
                </button>
              );
            })}
            <span className="absolute bottom-0 left-4 font-mono text-xs text-slate-400">{visual.x_min}</span>
            <span className="absolute bottom-0 right-4 font-mono text-xs text-slate-400">{visual.x_max}</span>
          </div>
          <p className="rounded-xl border border-sky-300/15 bg-slate-950/35 p-4 text-sm text-slate-100">{visual.entries[value]?.detail}</p>
        </div>
      )}

      {visual.kind === 'annotated_image' && (
        <div className="space-y-3">
          {visual.image_url ? (
            <div className="relative overflow-hidden rounded-xl border border-white/10 bg-slate-950/40">
              <img src={visual.image_url} alt={visual.description} className="max-h-[460px] w-full object-contain" />
              {visual.entries.map((item, index) => item.x != null && item.y != null ? (
                <button key={index} type="button" onClick={() => change(index)} aria-label={item.label}
                  style={{ left: `${item.x * 100}%`, top: `${item.y * 100}%` }}
                  className={`absolute -translate-x-1/2 -translate-y-1/2 grid h-8 w-8 place-items-center rounded-full border-2 text-xs font-semibold shadow-lg ${value === index ? 'border-white bg-sky-400 text-slate-950' : 'border-white/80 bg-slate-950/80 text-white'}`}>
                  {index + 1}
                </button>
              ) : null)}
            </div>
          ) : (
            <div className="rounded-xl border border-dashed border-white/15 bg-slate-950/30 p-5 text-sm leading-relaxed text-slate-200">{visual.description}</div>
          )}
          {visual.entries.length > 0 && entryButtons(true)}
          {visual.attribution && (
            <p className="text-xs text-slate-400">
              {visual.source_url ? <a href={visual.source_url} target="_blank" rel="noreferrer" className="underline decoration-slate-600 underline-offset-2">{visual.attribution}</a> : visual.attribution}
            </p>
          )}
        </div>
      )}

      {visual.kind === 'graph' && <Explorable expression={visual.expression} params={visual.params} xMin={visual.x_min} xMax={visual.x_max}
        yMin={visual.y_min} yMax={visual.y_max}
        onValuesChange={params => onUpdate?.({ params })} />}

      <p className="sr-only">{visual.description}</p>
    </section>
  );
}
