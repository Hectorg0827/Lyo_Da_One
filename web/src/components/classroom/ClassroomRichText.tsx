'use client';

import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import { cn } from '@/lib/utils';

/**
 * The Classroom wire mixes spoken prose and inline LaTeX in questions, choices,
 * teacher prompts, and feedback. Treat all of them as authored rich text.
 *
 * ReactMarkdown escapes raw HTML. Images and links stay non-interactive so an
 * AI-authored checkpoint cannot request arbitrary network content or navigate
 * a learner away from the lesson.
 */
export function ClassroomRichText({ text, className = '' }: { text: string; className?: string }) {
  const normalized = text
    .replace(/\\\\\(([^\n]*?)\\\\\)/g, (_, math: string) => `$${math}$`)
    .replace(/\\\\\[([\s\S]*?)\\\\\]/g, (_, math: string) => `$$\n${math}\n$$`);

  return (
    <div className={cn(
      'min-w-0 whitespace-normal break-words [&_p]:whitespace-pre-wrap [&_p:not(:first-child)]:mt-2',
      '[&_.katex]:text-inherit [&_.katex-display]:max-w-full [&_.katex-display]:overflow-x-auto',
      '[&_code]:whitespace-pre-wrap [&_code]:break-all [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5',
      className,
    )}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm, remarkMath]}
        rehypePlugins={[rehypeKatex]}
        components={{
          img: ({ alt }) => <span>{alt}</span>,
          a: ({ children }) => <span>{children}</span>,
        }}
      >
        {normalized}
      </ReactMarkdown>
    </div>
  );
}
