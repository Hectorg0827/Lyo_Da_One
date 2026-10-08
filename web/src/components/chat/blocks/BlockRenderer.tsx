'use client';

import ReactMarkdown from 'react-markdown';
import { AlertTriangle, FileText, ShieldCheck } from 'lucide-react';
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
import { MermaidView, ChartView } from '@/components/classroom/BoardElementView';

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

  // The Classroom already has animated, accessible renderers for both.
  // Use that same visual vocabulary in Chat rather than showing source code.
  if (format === 'mermaid') {
    return (
      <figure className="min-w-0 overflow-x-auto rounded-xl border border-white/10 bg-black/20 p-3">
        {title && <figcaption className="mb-2 text-sm text-white/75">{title}</figcaption>}
        <MermaidView source={source} />
      </figure>
    );
  }
  if (format === 'chart') {
    // Chart source is a JSON-encoded, bounded data series. Do not eval LLM
    // output or pass arbitrary objects into the chart renderer.
    try {
      const chart = JSON.parse(source) as {
        chartType?: unknown; labels?: unknown; values?: unknown;
      };
      if (
        (chart.chartType === 'bar' || chart.chartType === 'line') &&
        Array.isArray(chart.labels) && Array.isArray(chart.values) &&
        chart.labels.length > 0 && chart.labels.length <= 12 &&
        chart.labels.length === chart.values.length &&
        chart.labels.every((v) => typeof v === 'string') &&
        chart.values.every((v) => typeof v === 'number' && Number.isFinite(v) && v >= 0)
      ) {
        return (
          <figure className="min-w-0 rounded-xl border border-white/10 bg-black/20 p-3">
            {title && <figcaption className="mb-2 text-sm text-white/75">{title}</figcaption>}
            <ChartView chartType={chart.chartType} labels={chart.labels as string[]} values={chart.values as number[]} />
          </figure>
        );
      }
    } catch { /* Preserve readable fallback when chart data is invalid. */ }
  }
  return (
    <pre className="text-white/70 font-mono text-xs whitespace-pre-wrap overflow-x-auto p-3 rounded-xl bg-black/30 border border-white/10">
      {source}
    </pre>
  );
}

/** Image blocks must be real media, not a link presented as visual learning. */
function MediaBlock({ block }: { block: ChatBlock }) {
  const url = typeof block.content?.url === 'string' ? block.content.url : '';
  const alt = typeof block.content?.alt === 'string' ? block.content.alt : '';
  const caption = typeof block.content?.caption === 'string' ? block.content.caption : '';
  const sourceUrl = typeof block.metadata?.source_url === 'string' &&
    /^https:\/\/commons\\.wikimedia\\.org\//i.test(block.metadata.source_url)
      ? block.metadata.source_url : null;
  if (block.subtype !== 'image' || !/^https:\/\//i.test(url)) {
    return <GenericBlock block={block} />;
  }
  return (
    <figure className="overflow-hidden rounded-xl border border-white/10 bg-black/20">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={url} alt={alt || caption || 'Educational illustration'}
        loading="lazy" className="max-h-80 w-full object-contain" />
      {caption && <figcaption className="px-3 py-2 text-xs text-white/70">
        {sourceUrl ? <a href={sourceUrl} target="_blank" rel="noreferrer" className="underline">{caption}</a> : caption}
      </figcaption>}
    </figure>
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
          case 'media':
            return <MediaBlock key={block.id} block={block} />;
          case 'quiz':
            return <CheckBlock key={block.id} block={block} message={message} />;
          case 'interactive':
            if (block.subtype === 'explorable') {
              return <ExplorableBlock key={block.id} block={block} />;
            }
            if (block.subtype === 'sourceNavigator') {
              return <SourceNavigatorBlock key={block.id} block={block} />;
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
