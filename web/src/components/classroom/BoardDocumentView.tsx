'use client';

import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import type { BoardDocument } from '@/lib/board-presentation.mjs';

/** Authored content only; React escapes cells/code and markdown never enables raw HTML. */
export function BoardDocumentView({ document, fallback }: { document?: BoardDocument | null; fallback?: string }) {
  const markdown = (text: string) => (
    <ReactMarkdown remarkPlugins={[remarkGfm, remarkMath]} rehypePlugins={[rehypeKatex]}
      // Images go through the existing TeachingVisual media validation. A
      // markdown image must not turn authored notes into an unvalidated fetch.
      components={{ img: ({ alt }) => <span>{alt}</span> }}>
      {text}
    </ReactMarkdown>
  );
  const contentClass = 'space-y-3 text-sm leading-relaxed text-[var(--text-secondary)] [&_strong]:text-[var(--text-primary)] [&_code]:font-mono [&_code]:text-lyo-300 [&_pre]:overflow-x-auto [&_pre]:rounded-xl [&_pre]:bg-[var(--background)] [&_pre]:p-4 [&_table]:w-full [&_th]:p-2 [&_td]:p-2 [&_th]:text-left [&_td]:border-t [&_td]:border-[var(--border)] [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5';
  if (!document) return <div className={contentClass}>{fallback ? markdown(fallback) : null}</div>;
  return (
    <div className={contentClass}>
      {document.blocks.map((block, index) => {
        if (block.kind === 'code') return (
          <div key={index} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--background)]">
            {block.language && <p className="border-b border-[var(--border)] px-4 py-2 text-[10px] font-semibold uppercase tracking-wider text-lyo-300">{block.language}</p>}
            <pre className="overflow-x-auto p-4 text-[13px] leading-relaxed"><code>{block.text}</code></pre>
          </div>
        );
        if (block.kind === 'text') return <div key={index}>{markdown(block.text)}</div>;
        if (block.kind === 'table') return (
          <div key={index} className="overflow-x-auto rounded-xl border border-[var(--border)]" role="region" aria-label="Lesson table" tabIndex={0}>
            <table>
              <thead className="bg-lyo-500/10 text-[var(--text-primary)]"><tr>{block.headers.map((header, i) => <th scope="col" key={i}>{header}</th>)}</tr></thead>
              <tbody>{block.rows.map((row, i) => <tr key={i}>{row.map((cell, j) => <td key={j}>{cell}</td>)}</tr>)}</tbody>
            </table>
          </div>
        );
        const Tag = block.kind === 'steps' ? 'ol' : 'ul';
        return <Tag key={index} className="space-y-3 marker:font-semibold marker:text-lyo-300">{block.items.map((item, i) => <li key={i} className="pl-1">{markdown(item)}</li>)}</Tag>;
      })}
    </div>
  );
}
