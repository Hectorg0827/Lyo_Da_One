'use client';

import remarkMath from 'remark-math';
import remarkGfm from 'remark-gfm';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';

/**
 * Normalize TeX bracket/paren delimiters into the dollar delimiters understood
 * reliably by remark-math. LLMs commonly emit \\(...\\) and \\[...\\], while
 * CommonMark can consume the leading backslashes as escapes before remark-math
 * sees them. Code spans and fenced code are intentionally left untouched so
 * examples containing literal TeX source stay literal.
 */
export function normalizeLatexDelimiters(markdown: string): string {
  const normalizeText = (text: string) =>
    text
      .replace(/\\\[([\s\S]*?)\\\]/g, (_match, body: string) => `\n$$\n${body.trim()}\n$$\n`)
      .replace(/\\\(([\s\S]*?)\\\)/g, (_match, body: string) => `$${body}$`);

  const protectedCode = /(```[\s\S]*?```|~~~[\s\S]*?~~~|`[^`\n]*`)/g;
  let output = '';
  let cursor = 0;
  let match: RegExpExecArray | null;

  while ((match = protectedCode.exec(markdown)) !== null) {
    output += normalizeText(markdown.slice(cursor, match.index));
    output += match[0];
    cursor = match.index + match[0].length;
  }

  output += normalizeText(markdown.slice(cursor));
  return output;
}

/**
 * KaTeX's renderToString expects the TeX body, not surrounding delimiters.
 * Structured math blocks can still arrive wrapped because they are model
 * generated, so unwrap one complete outer pair before rendering.
 */
export function unwrapLatexDelimiters(source: string): string {
  const value = source.trim();

  if (value.startsWith('\\[') && value.endsWith('\\]')) {
    return value.slice(2, -2).trim();
  }
  if (value.startsWith('\\(') && value.endsWith('\\)')) {
    return value.slice(2, -2).trim();
  }
  if (value.startsWith('$$') && value.endsWith('$$') && value.length >= 4) {
    return value.slice(2, -2).trim();
  }
  if (value.startsWith('$') && value.endsWith('$') && value.length >= 2) {
    return value.slice(1, -1).trim();
  }

  return value;
}

/**
 * Shared markdown rendering config for chat.
 *
 * Extracted from MessageBubble so lesson blocks render text identically to a
 * plain assistant turn — one place to change chat typography, and no chance
 * of a block and a bubble disagreeing about how a list or a formula looks.
 *
 * Renders $inline$ and $$block$$ LaTeX via the same KaTeX engine the classroom
 * board uses. Call normalizeLatexDelimiters() before rendering model-produced
 * markdown so \\(...\\) and \\[...\\] are supported consistently too.
 */
export const MARKDOWN_MATH_PLUGINS = {
  // remark-gfm is what makes a reference table actually parse as a table
  // rather than printing its pipe characters verbatim.
  remarkPlugins: [remarkGfm, remarkMath],
  rehypePlugins: [rehypeKatex],
};

export const markdownComponents = {
  // Paragraphs
  p: ({ children }: { children?: React.ReactNode }) => (
    <p className="mb-3 last:mb-0 leading-relaxed">{children}</p>
  ),
  // Headings
  h1: ({ children }: { children?: React.ReactNode }) => (
    <h1 className="text-xl font-bold text-white mb-3 mt-4 first:mt-0">{children}</h1>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <h2 className="text-lg font-semibold text-white mb-2 mt-4 first:mt-0">{children}</h2>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <h3 className="text-base font-semibold text-white/90 mb-2 mt-3 first:mt-0">{children}</h3>
  ),
  // Lists
  ul: ({ children }: { children?: React.ReactNode }) => (
    <ul className="mb-3 space-y-1 pl-4">{children}</ul>
  ),
  ol: ({ children }: { children?: React.ReactNode }) => (
    <ol className="mb-3 space-y-1 pl-4 list-decimal">{children}</ol>
  ),
  li: ({ children }: { children?: React.ReactNode }) => (
    <li className="flex items-start gap-2 text-white/80">
      <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-lyo-400 shrink-0" />
      <span>{children}</span>
    </li>
  ),
  // Bold / italic
  strong: ({ children }: { children?: React.ReactNode }) => (
    <strong className="font-semibold text-white">{children}</strong>
  ),
  em: ({ children }: { children?: React.ReactNode }) => (
    <em className="italic text-white/70">{children}</em>
  ),
  // Code
  code: ({ inline, children }: { inline?: boolean; children?: React.ReactNode }) => {
    if (inline) {
      return (
        <code className="px-1.5 py-0.5 rounded-md bg-white/10 text-lyo-300 font-mono text-[0.85em]">
          {children}
        </code>
      );
    }
    return (
      <code className="block w-full overflow-x-auto p-3 rounded-xl bg-black/40 border border-white/10 text-lyo-300 font-mono text-sm leading-relaxed">
        {children}
      </code>
    );
  },
  pre: ({ children }: { children?: React.ReactNode }) => (
    <pre className="mb-3 rounded-xl overflow-hidden">{children}</pre>
  ),
  // Blockquote
  blockquote: ({ children }: { children?: React.ReactNode }) => (
    <blockquote className="border-l-2 border-lyo-500 pl-3 my-2 text-white/60 italic">
      {children}
    </blockquote>
  ),
  // Tables — reference tables arrive as GitHub-flavored markdown in a
  // dataViz/table block, and need to scroll rather than widen the page.
  table: ({ children }: { children?: React.ReactNode }) => (
    <div className="overflow-x-auto my-3 rounded-xl border border-white/10">
      <table className="w-full text-sm border-collapse">{children}</table>
    </div>
  ),
  thead: ({ children }: { children?: React.ReactNode }) => (
    <thead className="bg-white/5">{children}</thead>
  ),
  th: ({ children }: { children?: React.ReactNode }) => (
    <th className="text-left font-semibold text-white px-3 py-2 border-b border-white/10">
      {children}
    </th>
  ),
  td: ({ children }: { children?: React.ReactNode }) => (
    <td className="px-3 py-2 text-white/80 border-b border-white/5">{children}</td>
  ),
  // HR
  hr: () => <hr className="border-white/10 my-4" />,
};
