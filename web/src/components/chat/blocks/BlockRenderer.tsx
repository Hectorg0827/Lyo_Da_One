'use client';

import { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import {
  AlertTriangle,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  FileText,
  Layers,
  NotebookPen,
  ShieldCheck,
} from 'lucide-react';
import katex from 'katex';
import { cn } from '@/lib/utils';
import type { ChatBlock, ChatMessage } from '@/types';
import {
  markdownComponents,
  MARKDOWN_MATH_PLUGINS,
  normalizeLatexDelimiters,
  unwrapLatexDelimiters,
} from '../markdown-config';
import CheckBlock from './CheckBlock';
import ExplorableBlock from './ExplorableBlock';

const inlineMarkdownComponents = {
  ...markdownComponents,
  p: ({ children }: { children?: React.ReactNode }) => <span>{children}</span>,
};

function InlineMarkdown({ text }: { text: string }) {
  return (
    <ReactMarkdown components={inlineMarkdownComponents} {...MARKDOWN_MATH_PLUGINS}>
      {normalizeLatexDelimiters(text)}
    </ReactMarkdown>
  );
}

/** Prose beat. `subtype` carries which beat of the lesson this is. */
function TextBlock({ block }: { block: ChatBlock }) {
  const text = typeof block.content?.text === 'string' ? block.content.text : '';
  if (!text) return null;

  // The hook opens a lesson and reads as a lead-in, not body copy.
  const isHook = block.subtype === 'hook';

  return (
    <div
      className={cn(
        'prose-invert prose-sm max-w-none',
        isHook && 'text-[15px] text-white/90 font-medium'
      )}
    >
      <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
        {normalizeLatexDelimiters(text)}
      </ReactMarkdown>
    </div>
  );
}

/**
 * A highlighted aside — the "common mistakes" beat.
 *
 * Visually distinct on purpose: pre-empting an error only works if the learner
 * notices it isn't ordinary body text.
 */
function CalloutBlock({ block }: { block: ChatBlock }) {
  const text = typeof block.content?.text === 'string' ? block.content.text : '';
  if (!text) return null;

  const variant = typeof block.content?.style === 'string' ? block.content.style : 'trap';
  const tone =
    variant === 'insight'
      ? 'border-lyo-500/30 bg-lyo-500/10'
      : variant === 'warning'
        ? 'border-amber-500/30 bg-amber-500/10'
        : 'border-rose-500/30 bg-rose-500/10';
  const iconTone =
    variant === 'insight'
      ? 'text-lyo-300'
      : variant === 'warning'
        ? 'text-amber-300'
        : 'text-rose-300';

  return (
    <div className={cn('rounded-2xl border p-4 flex gap-3', tone)}>
      <AlertTriangle className={cn('w-4 h-4 mt-0.5 shrink-0', iconTone)} aria-hidden="true" />
      <div className="prose-invert prose-sm max-w-none text-white/85">
        <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
          {normalizeLatexDelimiters(text)}
        </ReactMarkdown>
      </div>
    </div>
  );
}

/** Rendered display-mode LaTeX, matching the classroom board's treatment. */
function MathBlock({ source }: { source: string }) {
  let html = '';
  const normalizedSource = unwrapLatexDelimiters(source);
  try {
    html = katex.renderToString(normalizedSource, { throwOnError: false, displayMode: true });
  } catch {
    // Never lose the formula: fall back to showing its source.
    return (
      <pre className="text-white/80 font-mono text-sm overflow-x-auto py-1">{source}</pre>
    );
  }
  return (
    <div
      className="text-white text-lg overflow-x-auto py-1 [&_.katex]:text-white"
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}

/** dataViz: a math formula, a reference table, or a diagram source. */
function DataVizBlock({ block }: { block: ChatBlock }) {
  const source = typeof block.content?.source === 'string' ? block.content.source : '';
  const format = typeof block.content?.format === 'string' ? block.content.format : 'text';
  const title = typeof block.content?.title === 'string' ? block.content.title : null;
  if (!source) return null;

  if (format === 'math') return <MathBlock source={source} />;

  // `table` is markdown; `text` is prose. Both render through the shared
  // markdown pipeline — a text-format block must not come out monospaced.
  if (format === 'table' || format === 'text') {
    return (
      <div>
        {title && (
          <div className="text-sm font-medium text-white/70 mb-2">
            <InlineMarkdown text={title} />
          </div>
        )}
        <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
          {normalizeLatexDelimiters(source)}
        </ReactMarkdown>
      </div>
    );
  }

  // Diagram formats (mermaid, chart) have no renderer here yet. Show the
  // source rather than a blank gap, so nothing silently disappears.
  return (
    <pre className="text-white/70 font-mono text-xs overflow-x-auto p-3 rounded-xl bg-black/30 border border-white/10">
      {source}
    </pre>
  );
}

// ── Study material ───────────────────────────────────────────────────────────

/**
 * A flashcard deck the learner can actually work through.
 *
 * Both sides are kept in the DOM so screen readers and find-in-page still
 * reach the answer, but only the current face is shown — a card that reveals
 * its own back is a paragraph with a border, not a flashcard.
 */
function FlashcardDeckBlock({ block }: { block: ChatBlock }) {
  const content = (block.content ?? {}) as Record<string, unknown>;
  const cards = (Array.isArray(content.cards) ? content.cards : [])
    .map((card) => (card ?? {}) as Record<string, unknown>)
    .filter((card) => typeof card.front === 'string' && card.front.length > 0);

  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);

  if (!cards.length) return null;

  const safeIndex = Math.min(index, cards.length - 1);
  const card = cards[safeIndex];
  const front = String(card.front ?? '');
  const back = typeof card.back === 'string' ? card.back : '';
  const title = typeof content.title === 'string' ? content.title : 'Study deck';

  const go = (delta: number) => {
    setIndex((current) => {
      const next = current + delta;
      if (next < 0 || next > cards.length - 1) return current;
      return next;
    });
    setFlipped(false);
  };

  return (
    <div className="rounded-2xl border border-lyo-500/20 bg-lyo-500/5 p-4">
      <div className="flex items-center gap-2 mb-3">
        <Layers className="w-4 h-4 text-lyo-300 shrink-0" aria-hidden="true" />
        <div className="text-sm font-semibold text-white/85 min-w-0 truncate">{title}</div>
        <div className="ml-auto text-[11px] text-white/40 tabular-nums shrink-0">
          {safeIndex + 1} / {cards.length}
        </div>
      </div>

      <button
        type="button"
        onClick={() => setFlipped((value) => !value)}
        aria-pressed={flipped}
        aria-label={flipped ? 'Show the question' : 'Show the answer'}
        className={cn(
          'w-full text-left rounded-xl border border-white/10 bg-black/25 p-4',
          'min-h-[128px] flex flex-col justify-center',
          'hover:border-white/20 hover:bg-black/30 transition-colors',
          'focus:outline-none focus-visible:ring-2 focus-visible:ring-lyo-400/70'
        )}
      >
        <div className="text-[11px] uppercase tracking-wide text-white/35 mb-2">
          {flipped ? 'Answer' : 'Question'}
        </div>
        <div
          className="prose-invert prose-sm max-w-none text-white/90"
          // Keep the hidden face in the DOM: assistive tech and find-in-page
          // should still reach it, even while it is not on screen.
          hidden={flipped}
        >
          <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
            {normalizeLatexDelimiters(front)}
          </ReactMarkdown>
        </div>
        <div className="prose-invert prose-sm max-w-none text-white/80" hidden={!flipped}>
          {back ? (
            <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
              {normalizeLatexDelimiters(back)}
            </ReactMarkdown>
          ) : (
            <span className="text-white/40">No answer on this card.</span>
          )}
        </div>
      </button>

      <div className="flex items-center gap-2 mt-3">
        <button
          type="button"
          onClick={() => go(-1)}
          disabled={safeIndex === 0}
          className="p-1.5 rounded-lg border border-white/10 text-white/70 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-white/5"
          aria-label="Previous card"
        >
          <ChevronLeft className="w-4 h-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          onClick={() => go(1)}
          disabled={safeIndex === cards.length - 1}
          className="p-1.5 rounded-lg border border-white/10 text-white/70 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-white/5"
          aria-label="Next card"
        >
          <ChevronRight className="w-4 h-4" aria-hidden="true" />
        </button>
        <span className="text-[11px] text-white/35 ml-1">Tap the card to flip it</span>
      </div>
    </div>
  );
}

/** A day-by-day revision schedule. */
function StudyPlanBlock({ block }: { block: ChatBlock }) {
  const content = (block.content ?? {}) as Record<string, unknown>;
  const schedule = (Array.isArray(content.schedule) ? content.schedule : [])
    .map((day) => (day ?? {}) as Record<string, unknown>);
  if (!schedule.length) return null;

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="flex items-center gap-2 mb-3">
        <CalendarDays className="w-4 h-4 text-lyo-300 shrink-0" aria-hidden="true" />
        <div className="text-sm font-semibold text-white/85">
          {typeof content.title === 'string' ? content.title : 'Your study plan'}
        </div>
      </div>
      <ol className="space-y-3">
        {schedule.map((day, dayIndex) => {
          const tasks = (Array.isArray(day.tasks) ? day.tasks : [])
            .map((task) => (task ?? {}) as Record<string, unknown>);
          return (
            <li key={dayIndex} className="border-l-2 border-lyo-500/30 pl-3">
              <div className="text-xs font-medium text-white/75">
                Day {typeof day.day === 'number' ? day.day : dayIndex + 1}
                {typeof day.topic === 'string' && day.topic ? ` — ${day.topic}` : ''}
              </div>
              {tasks.length > 0 && (
                <ul className="mt-1.5 space-y-1">
                  {tasks.map((task, taskIndex) => (
                    <li key={taskIndex} className="text-sm text-white/70 flex gap-2">
                      <span className="text-white/25 shrink-0">•</span>
                      <span className="min-w-0">
                        <InlineMarkdown text={String(task.title ?? '')} />
                        {typeof task.minutes === 'number' && (
                          <span className="text-white/35 text-xs"> · {task.minutes} min</span>
                        )}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          );
        })}
      </ol>
    </div>
  );
}

/** Sectioned study notes. */
function StudyNotesBlock({ block }: { block: ChatBlock }) {
  const content = (block.content ?? {}) as Record<string, unknown>;
  const sections = (Array.isArray(content.sections) ? content.sections : [])
    .map((section) => (section ?? {}) as Record<string, unknown>)
    .filter((section) => typeof section.title === 'string' && section.title.length > 0);
  if (!sections.length) return null;

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="flex items-center gap-2 mb-3">
        <NotebookPen className="w-4 h-4 text-lyo-300 shrink-0" aria-hidden="true" />
        <div className="text-sm font-semibold text-white/85">
          {typeof content.title === 'string' ? content.title : 'Study notes'}
        </div>
      </div>
      <div className="space-y-3">
        {sections.map((section, index) => (
          <div key={index}>
            <div className="text-xs font-medium text-white/70 mb-1">
              <InlineMarkdown text={String(section.title ?? '')} />
            </div>
            <div className="prose-invert prose-sm max-w-none text-white/75">
              <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
                {normalizeLatexDelimiters(String(section.body ?? ''))}
              </ReactMarkdown>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SourceNavigatorBlock({ block }: { block: ChatBlock }) {
  const content = (block.content ?? {}) as Record<string, unknown>;
  const items = Array.isArray(content.items) ? content.items : [];
  if (!items.length) return null;

  return (
    <div className="rounded-2xl border border-lyo-500/20 bg-lyo-500/5 p-4">
      <div className="flex items-center gap-2 mb-3">
        <ShieldCheck className="w-4 h-4 text-lyo-300" aria-hidden="true" />
        <div>
          <div className="text-sm font-semibold text-white/85">
            {typeof content.title === 'string' ? content.title : 'Sources used'}
          </div>
          <div className="text-[11px] text-white/40">
            Lyo grounded this answer in the material below.
          </div>
        </div>
      </div>
      <div className="grid gap-2">
        {items.map((item, index) => {
          const source = (item ?? {}) as Record<string, unknown>;
          const label = String(source.label ?? source.title ?? 'Attachment');
          const detail = String(source.detail ?? '');
          const url = typeof source.url === 'string' && source.url ? source.url : null;
          const body = (
            <>
              <FileText className="w-4 h-4 mt-0.5 shrink-0 text-white/45" aria-hidden="true" />
              <div className="min-w-0">
                <div className="text-xs font-medium text-white/80 truncate">{label}</div>
                {detail ? <div className="text-[11px] text-white/40 mt-0.5">{detail}</div> : null}
              </div>
            </>
          );
          return url ? (
            <a
              key={`${label}-${index}`}
              href={url}
              target="_blank"
              rel="noreferrer"
              className="flex items-start gap-2 rounded-xl border border-white/8 bg-black/15 px-3 py-2.5 hover:bg-white/5 hover:border-white/15 transition-colors"
            >
              {body}
            </a>
          ) : (
            <div
              key={`${label}-${index}`}
              className="flex items-start gap-2 rounded-xl border border-white/8 bg-black/15 px-3 py-2.5"
            >
              {body}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/**
 * Best-effort rendering for a declared block type that has no bespoke
 * renderer yet (code, flashcard, media, progress, interactive, masteryMap).
 *
 * These must not be dropped: the prose bubble is suppressed whenever blocks
 * are present, so silently skipping a block loses that content entirely — and
 * a turn carrying only such a block would render an empty bubble. Pull out
 * whatever human-readable strings the payload has rather than showing nothing.
 */
function GenericBlock({ block }: { block: ChatBlock }) {
  const content = (block.content ?? {}) as Record<string, unknown>;
  const str = (key: string) => (typeof content[key] === 'string' ? (content[key] as string) : null);

  const code = str('code');
  if (code) {
    return (
      <pre className="overflow-x-auto p-3 rounded-xl bg-black/40 border border-white/10">
        <code className="text-lyo-300 font-mono text-sm">{code}</code>
      </pre>
    );
  }

  const front = str('front');
  if (front) {
    return (
      <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
        <div className="prose-invert prose-sm max-w-none text-white/90 font-medium">
          <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
            {normalizeLatexDelimiters(front)}
          </ReactMarkdown>
        </div>
        {str('back') && (
          <div className="prose-invert prose-sm max-w-none text-white/60 mt-2">
            <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
              {normalizeLatexDelimiters(str('back')!)}
            </ReactMarkdown>
          </div>
        )}
      </div>
    );
  }

  if (typeof content.completed === 'number' && typeof content.total === 'number') {
    const pct = content.total > 0 ? Math.round((content.completed / content.total) * 100) : 0;
    return (
      <div className="text-xs text-white/60">
        {str('label') ? <InlineMarkdown text={str('label')!} /> : 'Progress'}: {content.completed}/{content.total} ({pct}%)
      </div>
    );
  }

  const items = Array.isArray(content.items) ? content.items : null;
  if (items?.length) {
    return (
      <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
        {str('title') && (
          <div className="text-sm font-medium text-white/70 mb-2">
            <InlineMarkdown text={str('title')!} />
          </div>
        )}
        <ul className="space-y-1.5">
          {items.map((item, i) => {
            const entry = item as Record<string, unknown>;
            const label = String(entry.label ?? entry.title ?? '');
            const detail = entry.detail ? String(entry.detail) : '';
            return (
              <li key={i} className="text-sm text-white/80">
                <span className="font-medium"><InlineMarkdown text={label} /></span>
                {detail ? (
                  <span className="text-white/55"> — <InlineMarkdown text={detail} /></span>
                ) : null}
              </li>
            );
          })}
        </ul>
      </div>
    );
  }

  const url = str('url');
  if (url) {
    return (
      <a href={url} target="_blank" rel="noreferrer" className="text-sm text-lyo-300 underline">
        {str('caption') ?? str('alt') ?? url}
      </a>
    );
  }

  const text = str('text') ?? str('title') ?? str('source');
  if (text) {
    return (
      <div className="prose-invert prose-sm max-w-none">
        <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
          {normalizeLatexDelimiters(text)}
        </ReactMarkdown>
      </div>
    );
  }

  // Genuinely nothing displayable — better an empty gap than raw JSON.
  return null;
}

export default function BlockRenderer({
  blocks,
  message,
}: {
  blocks: ChatBlock[];
  message: ChatMessage;
}) {
  if (!blocks?.length) return null;

  return (
    <div className="flex flex-col gap-3">
      {blocks.map((block) => {
        switch (block.type) {
          case 'text':
            return block.subtype === 'callout' ? (
              <CalloutBlock key={block.id} block={block} />
            ) : (
              <TextBlock key={block.id} block={block} />
            );
          case 'dataViz':
            return <DataVizBlock key={block.id} block={block} />;
          case 'quiz':
            return <CheckBlock key={block.id} block={block} message={message} />;
          case 'flashcard':
            // A deck carries `cards`; a lone card carries `front`/`back` and
            // still goes through GenericBlock's single-card treatment.
            return Array.isArray(block.content?.cards) ? (
              <FlashcardDeckBlock key={block.id} block={block} />
            ) : (
              <GenericBlock key={block.id} block={block} />
            );
          case 'interactive':
            if (block.subtype === 'explorable') {
              return <ExplorableBlock key={block.id} block={block} />;
            }
            if (block.subtype === 'sourceNavigator') {
              return <SourceNavigatorBlock key={block.id} block={block} />;
            }
            if (block.subtype === 'studyPlan') {
              return <StudyPlanBlock key={block.id} block={block} />;
            }
            if (block.subtype === 'studyNotes') {
              return <StudyNotesBlock key={block.id} block={block} />;
            }
            return <GenericBlock key={block.id} block={block} />;
          case 'unknown':
            // Forward compatibility: a type this client genuinely does not
            // know is skipped, never rendered as raw JSON and never thrown on.
            return null;
          default:
            // A DECLARED type without a bespoke renderer still gets shown.
            return <GenericBlock key={block.id} block={block} />;
        }
      })}
    </div>
  );
}
