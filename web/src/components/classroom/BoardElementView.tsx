'use client';

import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { motion } from 'framer-motion';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import {
  BookOpenCheck, CheckCircle2, FileText, HelpCircle, ImageIcon, Mic, Send, XCircle,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  createBrowserSpeechRecognition,
  type BrowserSpeechRecognition,
} from '@/lib/browser-speech';
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

/** The Teacher circling/underlining a term on the board — a chalk ellipse
    draws itself around the word, mirroring "circle or color the variable"
    instead of the board sitting inert while it's discussed. */
function HighlightView({ term }: { term: string }) {
  return (
    <div className="flex justify-center py-1">
      <div className="relative inline-flex items-center justify-center">
        <svg
          viewBox="0 0 220 84"
          className="pointer-events-none absolute -inset-3 h-[calc(100%+24px)] w-[calc(100%+24px)]"
          preserveAspectRatio="none"
        >
          <motion.ellipse
            cx={110} cy={42} rx={104} ry={34}
            fill="none"
            stroke="#FBBF24"
            strokeWidth={4}
            strokeLinecap="round"
            initial={{ pathLength: 0, opacity: 0 }}
            animate={{ pathLength: 1, opacity: 1 }}
            transition={{ duration: 0.7, ease: 'easeOut' }}
          />
        </svg>
        <span className="relative z-10 px-5 py-2 text-xl font-black text-accent-gold [text-shadow:0_0_16px_rgba(251,191,36,0.5)]">
          {term}
        </span>
      </div>
    </div>
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

// ─── Chalk: one idea at a time, with expressions colour-coded by role ────────

type MathRole = 'coefficient' | 'variable' | 'constant' | 'operator' | 'plain';

// Each part of an expression gets its own hue, so "3x + 5" reads as
// coefficient / variable / constant at a glance rather than as flat text.
const MATH_ROLE_CLASS: Record<MathRole, string> = {
  coefficient: 'text-accent-gold',
  variable: 'text-accent-teal',
  constant: 'text-accent-violet',
  operator: 'text-white/45',
  plain: '',
};

// An operand is a bare number, a variable, or a coefficient glued to a variable
// ("3x", "mx"). An expression is two or more of those joined by operators.
const OPERAND = String.raw`(?:\d+(?:\.\d+)?[a-zA-Z]*|[a-zA-Z]+)`;
const EXPRESSION = new RegExp(`${OPERAND}(?:\\s*[+\\-*/=^]\\s*${OPERAND})+`, 'g');

/**
 * Guards against colouring ordinary prose. "input/output" and "read/write"
 * match the operand grammar but are not maths; real algebra either contains a
 * digit or uses single-letter variables ("y = mx + b").
 */
function looksLikeMath(expression: string): boolean {
  if (/\d/.test(expression)) return true;
  return /(^|[^a-zA-Z])[a-zA-Z]([^a-zA-Z]|$)/.test(expression);
}

function tokenizeExpression(expression: string): { text: string; role: MathRole }[] {
  const raw = expression.match(/\d+(?:\.\d+)?|[a-zA-Z]+|[+\-*/=^]|\s+/g) ?? [];
  return raw.map((text, i) => {
    if (/^\s+$/.test(text)) return { text, role: 'plain' };
    if (/^\d/.test(text)) {
      // A number immediately followed by a variable is a coefficient, not a
      // standalone constant — that's what makes 3 and 5 read differently.
      const next = raw[i + 1];
      return { text, role: next && /^[a-zA-Z]/.test(next) ? 'coefficient' : 'constant' };
    }
    if (/^[a-zA-Z]+$/.test(text)) return { text, role: 'variable' };
    return { text, role: 'operator' };
  });
}

function ColouredExpression({ expression }: { expression: string }) {
  return (
    <span className="font-mono font-semibold tracking-tight">
      {tokenizeExpression(expression).map((token, i) => (
        <span key={i} className={MATH_ROLE_CLASS[token.role]}>{token.text}</span>
      ))}
    </span>
  );
}

/** Splits a line into plain prose and colour-coded expressions. */
function withExpressions(line: string): ReactNode[] {
  const parts: ReactNode[] = [];
  let last = 0;
  EXPRESSION.lastIndex = 0;
  for (let match = EXPRESSION.exec(line); match; match = EXPRESSION.exec(line)) {
    if (!looksLikeMath(match[0])) continue;
    if (match.index > last) parts.push(line.slice(last, match.index));
    parts.push(<ColouredExpression key={match.index} expression={match[0]} />);
    last = match.index + match[0].length;
  }
  if (last < line.length) parts.push(line.slice(last));
  return parts.length ? parts : [line];
}

/**
 * Breaks a block into one-idea beats. Splits on blank lines and on sentence
 * endings that are followed by whitespace, so decimals like "3.5" stay intact.
 */
function splitIntoBeats(text: string): string[] {
  const beats: string[] = [];
  for (const block of text.split(/\n+/)) {
    // Split on sentence punctuation only when whitespace follows, so a
    // decimal like "3.5" survives intact. The capture group keeps the
    // punctuation attached to the sentence it ended.
    const pieces = block.split(/([.!?])\s+/);
    for (let i = 0; i < pieces.length; i += 2) {
      const beat = `${pieces[i] ?? ''}${pieces[i + 1] ?? ''}`.trim();
      if (beat) beats.push(beat);
    }
  }
  return beats;
}

function ChalkView({ text, reducedMotion }: { text: string; reducedMotion: boolean }) {
  const beats = useMemo(() => splitIntoBeats(text), [text]);
  return (
    <div className="space-y-2.5">
      {beats.map((beat, i) => (
        <motion.p
          key={i}
          initial={reducedMotion ? false : { opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={reducedMotion
            ? { duration: 0 }
            : { delay: i * 0.5, duration: 0.4, ease: 'easeOut' }}
          className="text-white/95 text-lg leading-relaxed font-medium [text-shadow:0_0_14px_rgba(167,139,250,0.25)]"
        >
          {withExpressions(beat)}
        </motion.p>
      ))}
    </div>
  );
}

function QuizView({
  el, onAnswer, onSkip, onUnskip, onAskHelp,
}: {
  el: Extract<BoardElement, { kind: 'quiz' }>;
  onAnswer: (elementId: string, option: QuizOption) => void;
  onSkip: (elementId: string) => void;
  onUnskip: (elementId: string) => void;
  onAskHelp: () => void;
}) {
  const quiz = el.quiz;
  const isSpanish = quiz.language_code?.toLowerCase().startsWith('es') === true;
  const locked = !!el.answered || !!el.skipped;
  return (
    <div className="space-y-3">
      <p className="text-[11px] font-black tracking-widest text-accent-gold uppercase">
        {isSpanish ? '📝 En el tablero — comprobación' : '📝 On the board — checkpoint'}
      </p>
      <p className="text-white text-base font-medium">{quiz.question}</p>
      <div className="grid gap-2 sm:grid-cols-2">
        {(quiz.options ?? []).map((opt) => {
          const chosen = el.answered === opt.label;
          return (
            <button
              key={opt.id}
              disabled={locked}
              onClick={() => onAnswer(el.id, opt)}
              className={cn(
                'flex items-center justify-between px-4 py-3 rounded-xl text-sm text-left border transition-all',
                chosen && el.wasCorrect === true && 'bg-green-500/15 border-green-500/40 text-white',
                chosen && el.wasCorrect === false && 'bg-red-500/15 border-red-500/40 text-white',
                chosen && el.wasCorrect === undefined && 'bg-lyo-500/15 border-lyo-400/40 text-white',
                !locked && 'bg-white/5 border-white/15 text-white/85 hover:bg-lyo-500/15 hover:border-lyo-500/40',
                !chosen && locked && 'bg-white/[0.03] border-white/5 text-white/30',
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
      {!el.answered && !el.skipped && (
        <div className="flex items-center gap-3 pt-1">
          <button
            type="button"
            onClick={() => onSkip(el.id)}
            className="text-xs font-semibold text-white/50 hover:text-white/80 transition-colors"
          >
            {isSpanish ? 'No lo sé — omitir' : <>I don&apos;t know — skip</>}
          </button>
          <span className="text-white/20">·</span>
          <button
            type="button"
            onClick={onAskHelp}
            className="inline-flex items-center gap-1 text-xs font-semibold text-lyo-300 hover:text-lyo-200 transition-colors"
          >
            <HelpCircle className="w-3.5 h-3.5" /> {isSpanish ? 'Pedir ayuda' : 'Ask for help'}
          </button>
        </div>
      )}
      {el.skipped && (
        <div className="flex items-center gap-3">
          <p className="text-sm text-white/40 italic">{isSpanish ? 'Omitida.' : 'Skipped.'}</p>
          <button
            type="button"
            onClick={() => onUnskip(el.id)}
            className="text-xs font-semibold text-lyo-300 hover:text-lyo-200 transition-colors"
          >
            {isSpanish ? 'Intentarla ahora' : 'Try this now'}
          </button>
        </div>
      )}
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
  el, onInputStart, onSubmit, onSkip, onUnskip, onAskHelp,
}: {
  el: Extract<BoardElement, { kind: 'transfer' }>;
  onInputStart: () => void;
  onSubmit: (elementId: string, response: string) => void;
  onSkip: (elementId: string) => void;
  onUnskip: (elementId: string) => void;
  onAskHelp: () => void;
}) {
  const [response, setResponse] = useState(el.response || '');
  const [listening, setListening] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const dictationBaseRef = useRef('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const minWords = el.input.min_words ?? 6;
  const isSpanish = el.input.language_code?.toLowerCase().startsWith('es') === true;
  const wordCount = response.trim().split(/\s+/).filter(Boolean).length;
  const locked = !!el.submitted || !!el.skipped;
  const ready = wordCount >= minWords && !locked;

  useEffect(() => {
    setSpeechSupported(createBrowserSpeechRecognition() !== null);
    return () => recognitionRef.current?.stop();
  }, []);

  useEffect(() => {
    const node = textareaRef.current;
    if (!node) return;
    node.style.height = 'auto';
    node.style.height = `${node.scrollHeight}px`;
  }, [response]);

  const toggleDictation = () => {
    if (listening) {
      recognitionRef.current?.stop();
      return;
    }
    const recognition = createBrowserSpeechRecognition();
    if (!recognition) return;
    onInputStart();
    recognitionRef.current = recognition;
    dictationBaseRef.current = response ? response.replace(/\s*$/, ' ') : '';
    recognition.lang = el.input.language_code === 'auto'
      ? navigator.language || 'en-US'
      : el.input.language_code || navigator.language || 'en-US';
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.onresult = (event) => {
      let transcript = '';
      for (let index = 0; index < event.results.length; index += 1) {
        transcript += event.results[index][0].transcript;
      }
      setResponse((dictationBaseRef.current + transcript).slice(0, 1200));
    };
    recognition.onend = () => setListening(false);
    recognition.onerror = () => setListening(false);
    try {
      recognition.start();
      setListening(true);
    } catch {
      setListening(false);
    }
  };

  return (
    <div className="space-y-3 rounded-xl border border-lyo-400/25 bg-lyo-500/10 p-4">
      <p className="text-[11px] font-black tracking-widest text-lyo-200 uppercase">
        {isSpanish ? '✍️ Demuestra que puedes usarlo' : '✍️ Show you can use it'}
      </p>
      <label htmlFor={`transfer-${el.id}`} className="block text-white text-base font-medium">
        {el.input.question || (isSpanish ? '¿Cómo usarías esta idea?' : 'How would you use this idea?')}
      </label>
      <textarea
        ref={textareaRef}
        id={`transfer-${el.id}`}
        value={response}
        disabled={locked}
        rows={3}
        maxLength={Math.max(200, (el.input.max_words ?? 120) * 10)}
        onFocus={onInputStart}
        onChange={(event) => {
          onInputStart();
          setResponse(event.target.value);
        }}
        placeholder={el.input.placeholder || (isSpanish ? 'Explica tu razonamiento…' : 'Explain your reasoning…')}
        className="w-full min-h-[5.5rem] max-h-72 resize-none overflow-y-auto rounded-xl border border-white/15 bg-black/25 px-3 py-2 text-sm leading-relaxed text-white placeholder:text-white/30 focus:outline-none focus:ring-2 focus:ring-lyo-400/60 disabled:opacity-60"
      />
      {el.skipped ? (
        <div className="flex items-center gap-3">
          <p className="text-sm text-white/40 italic">{isSpanish ? 'Omitida.' : 'Skipped.'}</p>
          <button
            type="button"
            onClick={() => onUnskip(el.id)}
            className="text-xs font-semibold text-lyo-300 hover:text-lyo-200 transition-colors"
          >
            {isSpanish ? 'Intentarla ahora' : 'Try this now'}
          </button>
        </div>
      ) : (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-3">
            <span className={cn('text-xs', ready ? 'text-green-300' : 'text-white/45')}>
              {wordCount}/{minWords} {isSpanish ? 'palabras como mínimo' : 'minimum words'}
            </span>
            {speechSupported && !el.submitted && (
              <button
                type="button"
                onClick={toggleDictation}
                aria-label={listening ? 'Stop dictation' : 'Dictate your application'}
                className={cn(
                  'rounded-lg border p-2 transition-colors',
                  listening
                    ? 'border-red-400/50 bg-red-500/15 text-red-200'
                    : 'border-white/15 bg-white/5 text-white/65 hover:text-white',
                )}
              >
                <Mic className="h-4 w-4" />
              </button>
            )}
            {!el.submitted && (
              <>
                <button
                  type="button"
                  onClick={() => onSkip(el.id)}
                  className="text-xs font-semibold text-white/50 hover:text-white/80 transition-colors"
                >
                  {isSpanish ? 'No lo sé — omitir' : <>I don&apos;t know — skip</>}
                </button>
                <button
                  type="button"
                  onClick={onAskHelp}
                  className="inline-flex items-center gap-1 text-xs font-semibold text-lyo-300 hover:text-lyo-200 transition-colors"
                >
                  <HelpCircle className="w-3.5 h-3.5" /> {isSpanish ? 'Pedir ayuda' : 'Ask for help'}
                </button>
              </>
            )}
          </div>
          <button
            type="button"
            disabled={!ready}
            onClick={() => onSubmit(el.id, response)}
            className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Send className="h-4 w-4" />
            {el.submitted
              ? (isSpanish ? 'Enviada' : 'Submitted')
              : (isSpanish ? 'Enviar aplicación' : 'Submit application')}
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Dispatcher ───────────────────────────────────────────────────────────────

export function BoardElementView({
  el, onQuizAnswer, onTransferSubmit, onLearnerInputStart,
  onSkipQuestion, onUnskipQuestion, onAskHelp, reducedMotion = false,
}: {
  el: BoardElement;
  onQuizAnswer: (elementId: string, option: QuizOption) => void;
  onTransferSubmit: (elementId: string, response: string) => void;
  onLearnerInputStart: () => void;
  onSkipQuestion: (elementId: string) => void;
  onUnskipQuestion: (elementId: string) => void;
  onAskHelp: () => void;
  reducedMotion?: boolean;
}) {
  return (
    <motion.div
      initial={reducedMotion ? false : { opacity: 0, y: 10, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: reducedMotion ? 0 : 0.45, ease: 'easeOut' }}
      className="board-element"
    >
      {el.kind === 'chalk' && <ChalkView text={el.text} reducedMotion={reducedMotion} />}

      {el.kind === 'highlight' && <HighlightView term={el.term} />}

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

      {el.kind === 'quiz' && (
        <QuizView
          el={el}
          onAnswer={onQuizAnswer}
          onSkip={onSkipQuestion}
          onUnskip={onUnskipQuestion}
          onAskHelp={onAskHelp}
        />
      )}

      {el.kind === 'transfer' && (
        <TransferView
          el={el}
          onSubmit={onTransferSubmit}
          onInputStart={onLearnerInputStart}
          onSkip={onSkipQuestion}
          onUnskip={onUnskipQuestion}
          onAskHelp={onAskHelp}
        />
      )}

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
