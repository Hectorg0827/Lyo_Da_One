'use client';

import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import { BookOpenCheck, CheckCircle2, FileText, ImageIcon, Send, XCircle } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { BoardElement, QuizOption } from '@/stores/classroom-store';
import { Explorable } from './Explorable';

let mermaidReady: Promise<typeof import('mermaid')> | null = null;
function loadMermaid() {
  if (!mermaidReady) {
    mermaidReady = import('mermaid').then((m) => {
      m.default.initialize({
        startOnLoad: false,
        theme: 'dark',
        darkMode: true,
        themeVariables: {
          background: 'transparent',
          primaryColor: '#1e2a52',
          primaryTextColor: '#e8ecff',
          primaryBorderColor: '#8B5CF6',
          lineColor: '#A78BFA',
          fontSize: '15px',
        },
      });
      return m;
    });
  }
  return mermaidReady;
}

// ─── Individual renderers ─────────────────────────────────────────────────────

function MermaidView({ source }: { source: string }) {
  const [svg, setSvg] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const idRef = useRef(`mmd_${Math.random().toString(36).slice(2)}`);

  useEffect(() => {
    let alive = true;
    loadMermaid()
      .then((m) => m.default.render(idRef.current, source))
      .then(({ svg }) => { if (alive) setSvg(svg); })
      .catch(() => { if (alive) setFailed(true); });
    return () => { alive = false; };
  }, [source]);

  if (failed) {
    return <pre className="text-[13px] text-white/70 font-mono whitespace-pre-wrap">{source}</pre>;
  }
  if (!svg) {
    return <div className="h-24 flex items-center justify-center text-white/30 text-sm">drawing…</div>;
  }
  return (
    <div
      className="mermaid-board flex justify-center [&_svg]:max-w-full [&_svg]:h-auto"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}

function LatexView({ latex }: { latex: string }) {
  let html = '';
  try {
    html = katex.renderToString(latex, { throwOnError: false, displayMode: true });
  } catch {
    return <pre className="text-white/80 font-mono text-sm">{latex}</pre>;
  }
  return (
    <div
      className="text-white text-lg overflow-x-auto py-1 [&_.katex]:text-white"
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}

function ChartView({ chartType, labels, values }: { chartType: 'bar' | 'line'; labels: string[]; values: number[] }) {
  const max = Math.max(...values, 1);
  const W = 560, H = 200, PAD = 30;
  const n = Math.min(labels.length, values.length);
  const step = (W - PAD * 2) / Math.max(n, 1);

  return (
    <svg
      viewBox={`0 0 ${W} ${H + 30}`}
      className="w-full max-w-xl mx-auto"
      role="img"
      aria-label={`${chartType} chart: ${labels.slice(0, n).map((label, index) => `${label} ${values[index]}`).join(', ')}`}
    >
      {chartType === 'bar' &&
        values.slice(0, n).map((v, i) => {
          const h = (v / max) * (H - PAD);
          return (
            <motion.rect
              key={i}
              x={PAD + i * step + step * 0.15}
              width={step * 0.7}
              initial={{ y: H, height: 0 }}
              animate={{ y: H - h, height: h }}
              transition={{ delay: i * 0.08, duration: 0.5, ease: 'easeOut' }}
              rx={4}
              fill="url(#chalkGrad)"
            />
          );
        })}
      {chartType === 'line' && (
        <motion.polyline
          fill="none"
          stroke="#A78BFA"
          strokeWidth={2.5}
          strokeLinecap="round"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 1.2 }}
          points={values.slice(0, n).map((v, i) =>
            `${PAD + i * step + step / 2},${H - (v / max) * (H - PAD)}`).join(' ')}
        />
      )}
      {labels.slice(0, n).map((label, i) => (
        <text key={i} x={PAD + i * step + step / 2} y={H + 18} textAnchor="middle"
          className="fill-white/60" fontSize={11}>
          {label.length > 9 ? label.slice(0, 8) + '…' : label}
        </text>
      ))}
      <defs>
        <linearGradient id="chalkGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#A78BFA" />
          <stop offset="100%" stopColor="#6366F1" />
        </linearGradient>
      </defs>
    </svg>
  );
}

function QuizView({
  el, onAnswer,
}: {
  el: Extract<BoardElement, { kind: 'quiz' }>;
  onAnswer: (elementId: string, option: QuizOption) => void;
}) {
  const quiz = el.quiz;
  return (
    <div className="space-y-3">
      <p className="text-[11px] font-black tracking-widest text-accent-gold uppercase">📝 On the board — checkpoint</p>
      <p className="text-white text-base font-medium">{quiz.question}</p>
      <div className="grid gap-2 sm:grid-cols-2">
        {(quiz.options ?? []).map((opt) => {
          const chosen = el.answered === opt.label;
          return (
            <button
              key={opt.id}
              disabled={!!el.answered}
              onClick={() => onAnswer(el.id, opt)}
              className={cn(
                'flex items-center justify-between px-4 py-3 rounded-xl text-sm text-left border transition-all',
                chosen && el.wasCorrect === true && 'bg-green-500/15 border-green-500/40 text-white',
                chosen && el.wasCorrect === false && 'bg-red-500/15 border-red-500/40 text-white',
                chosen && el.wasCorrect === undefined && 'bg-lyo-500/15 border-lyo-400/40 text-white',
                !el.answered && 'bg-white/5 border-white/15 text-white/85 hover:bg-lyo-500/15 hover:border-lyo-500/40',
                !chosen && el.answered && 'bg-white/[0.03] border-white/5 text-white/30',
              )}
            >
              <span>{opt.label}</span>
              {chosen && el.wasCorrect === true && (
                <CheckCircle2 className="w-4 h-4 text-green-400 shrink-0" />
              )}
              {chosen && el.wasCorrect === false && (
                <XCircle className="w-4 h-4 text-red-400 shrink-0" />
              )}
            </button>
          );
        })}
      </div>
      {el.feedback && (
        <p
          className={cn(
            'text-sm rounded-lg border px-3 py-2',
            el.wasCorrect
              ? 'text-green-200 bg-green-500/10 border-green-500/25'
              : 'text-amber-100 bg-amber-500/10 border-amber-500/25',
          )}
          role="status"
        >
          {el.feedback}
        </p>
      )}
    </div>
  );
}

function TransferView({
  el,
  onSubmit,
}: {
  el: Extract<BoardElement, { kind: 'transfer' }>;
  onSubmit: (elementId: string, response: string) => void;
}) {
  const [response, setResponse] = useState(el.response || '');
  const minWords = el.input.min_words ?? 6;
  const wordCount = response.trim().split(/\s+/).filter(Boolean).length;
  const ready = wordCount >= minWords && !el.submitted;
  return (
    <div className="space-y-3 rounded-xl border border-lyo-400/25 bg-lyo-500/10 p-4">
      <p className="text-[11px] font-black tracking-widest text-lyo-200 uppercase">
        ✍️ Show you can use it
      </p>
      <label htmlFor={`transfer-${el.id}`} className="block text-white text-base font-medium">
        {el.input.question || 'Explain and apply the idea in your own words.'}
      </label>
      <textarea
        id={`transfer-${el.id}`}
        value={response}
        disabled={el.submitted}
        maxLength={Math.max(200, (el.input.max_words ?? 120) * 10)}
        onChange={(event) => setResponse(event.target.value)}
        placeholder={el.input.placeholder || 'Explain your reasoning…'}
        className="w-full min-h-28 resize-y rounded-xl border border-white/15 bg-black/25 px-3 py-2 text-sm text-white placeholder:text-white/30 focus:outline-none focus:ring-2 focus:ring-lyo-400/60 disabled:opacity-60"
      />
      <div className="flex items-center justify-between gap-3">
        <span className={cn('text-xs', ready ? 'text-green-300' : 'text-white/45')}>
          {wordCount}/{minWords} minimum words
        </span>
        <button
          type="button"
          disabled={!ready}
          onClick={() => onSubmit(el.id, response)}
          className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
        >
          <Send className="h-4 w-4" />
          {el.submitted ? 'Submitted' : 'Submit application'}
        </button>
      </div>
    </div>
  );
}

// ─── Dispatcher ───────────────────────────────────────────────────────────────

export function BoardElementView({
  el, onQuizAnswer, onTransferSubmit, reducedMotion = false,
}: {
  el: BoardElement;
  onQuizAnswer: (elementId: string, option: QuizOption) => void;
  onTransferSubmit: (elementId: string, response: string) => void;
  reducedMotion?: boolean;
}) {
  return (
    <motion.div
      initial={reducedMotion ? false : { opacity: 0, y: 10, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: reducedMotion ? 0 : 0.45, ease: 'easeOut' }}
      className="board-element"
    >
      {el.kind === 'chalk' && (
        <p className="text-white/95 text-lg leading-relaxed font-medium whitespace-pre-wrap [text-shadow:0_0_14px_rgba(167,139,250,0.25)]">
          {el.text}
        </p>
      )}

      {el.kind === 'latex' && <LatexView latex={el.latex} />}

      {el.kind === 'mermaid' && <MermaidView source={el.source} />}

      {el.kind === 'code' && (
        <pre className="bg-black/40 border border-white/10 rounded-xl p-4 overflow-x-auto text-[13px] leading-relaxed text-lyo-300 font-mono">
          {el.code}
        </pre>
      )}

      {el.kind === 'image' && (
        el.url ? (
          <figure className="space-y-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={el.url}
              alt={el.caption || el.query}
              className="max-h-72 mx-auto rounded-xl border border-white/10 shadow-2xl object-contain"
            />
            <figcaption className="text-center text-xs text-white/50">
              <span className="italic">{el.caption || el.query}</span>
              {el.attribution && (
                <>
                  {' · '}
                  {el.sourceUrl ? (
                    <a
                      href={el.sourceUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="underline hover:text-white/75"
                    >
                      {el.attribution}
                    </a>
                  ) : el.attribution}
                </>
              )}
            </figcaption>
          </figure>
        ) : (
          <div className="h-40 flex flex-col items-center justify-center gap-2 text-white/30 border border-dashed border-white/15 rounded-xl">
            <ImageIcon className="w-6 h-6" />
            <span className="text-xs">finding a picture of “{el.query}”…</span>
          </div>
        )
      )}

      {el.kind === 'bullets' && (
        <ul className="space-y-2.5">
          {el.items.map((item, i) => (
            <motion.li
              key={i}
              initial={{ opacity: 0, x: -14 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.55, duration: 0.4 }}
              className="flex items-start gap-3 text-white/90 text-base"
            >
              <span className="mt-2 w-2 h-2 rounded-full bg-accent-gold shrink-0" />
              <span>{item}</span>
            </motion.li>
          ))}
        </ul>
      )}

      {el.kind === 'chart' && (
        <ChartView chartType={el.chartType} labels={el.labels} values={el.values} />
      )}

      {el.kind === 'explorable' && (
        <Explorable
          expression={el.expression}
          params={el.params}
          xMin={el.xMin}
          xMax={el.xMax}
          prompt={el.prompt}
        />
      )}

      {el.kind === 'quiz' && <QuizView el={el} onAnswer={onQuizAnswer} />}

      {el.kind === 'transfer' && <TransferView el={el} onSubmit={onTransferSubmit} />}

      {el.kind === 'summary' && (
        <section className="space-y-3 rounded-xl border border-green-400/20 bg-green-500/10 p-4">
          <h2 className="flex items-center gap-2 text-base font-bold text-green-100">
            <BookOpenCheck className="h-5 w-5" /> {el.title}
          </h2>
          {el.content && <p className="text-sm leading-relaxed text-white/80">{el.content}</p>}
          {el.items.length > 0 && (
            <ul className="list-disc space-y-1 pl-5 text-sm text-white/75">
              {el.items.map((item, index) => <li key={index}>{item}</li>)}
            </ul>
          )}
          {el.retrievalScheduled && (
            <p className="text-xs font-semibold text-lyo-200">Spaced retrieval scheduled</p>
          )}
        </section>
      )}

      {el.kind === 'source' && (
        <aside className="flex items-start gap-2 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white/55">
          <FileText className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <span className="font-semibold text-white/70">Source: </span>
            {el.labels.join(' · ')}
          </div>
        </aside>
      )}

      {el.kind === 'dismissal' && (
        <div className="text-center space-y-3 py-4">
          <p className="text-2xl">🔔</p>
          <p className="text-accent-gold font-bold text-lg">Class dismissed</p>
          {el.homework && (
            <p className="text-white/85 text-sm max-w-md mx-auto">
              <span className="font-semibold text-white">Homework:</span> {el.homework}
            </p>
          )}
          {el.nextHook && <p className="text-white/50 text-sm italic">{el.nextHook}</p>}
        </div>
      )}
    </motion.div>
  );
}
