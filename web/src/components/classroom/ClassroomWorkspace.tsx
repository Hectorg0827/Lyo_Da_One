'use client';

import { useMemo, type ComponentProps } from 'react';
import { PenLine, Bookmark, Pencil, MessageCircle } from 'lucide-react';
import { workspaceGroups } from '@/lib/board-presentation.mjs';
import type { BoardElement } from '@/stores/classroom-store';
import { BoardElementView } from './BoardElementView';

type ElementActions = Omit<ComponentProps<typeof BoardElementView>, 'el' | 'compactText'>;

export function ClassroomWorkspace({ elements, ...actions }: { elements: BoardElement[] } & ElementActions) {
  const groups = useMemo(() => workspaceGroups(elements), [elements]);
  const render = (items: BoardElement[], compactText = false) => items.map(el => (
    <BoardElementView key={el.id} el={el} compactText={compactText} {...actions} />
  ));
  const hasVisual = groups.board.some(el => el.kind !== 'summary');
  return (
    <div className="space-y-5" data-classroom-workspace>
      {groups.recovery.length > 0 && <section aria-label="Lesson recovery" className="space-y-3">{render(groups.recovery)}</section>}
      {groups.board.length > 0 && (
        <section aria-label="Teaching workspace" className="space-y-3">
          <h2 className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.14em] text-lyo-300"><PenLine className="h-4 w-4" /> Teaching workspace</h2>
          {render(groups.board, hasVisual)}
        </section>
      )}
      {groups.feedback.length > 0 && <section aria-label="Feedback" className="space-y-3"><h2 className="flex items-center gap-2 text-xs font-semibold text-lyo-300"><MessageCircle className="h-4 w-4" /> Feedback</h2>{render(groups.feedback)}</section>}
      {groups.reference.length > 0 && <section aria-label="Keep in view" className="space-y-3 rounded-xl border border-[var(--border)] bg-[var(--background)] p-3"><h2 className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wider text-[var(--text-secondary)]"><Bookmark className="h-4 w-4 text-accent-gold" /> Keep in view</h2>{render(groups.reference)}</section>}
      {groups.practice.length > 0 && <section aria-label="Your turn" className="space-y-3 border-t border-lyo-400/25 pt-4"><h2 className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.14em] text-lyo-300"><Pencil className="h-4 w-4" /> Your turn</h2>{render(groups.practice)}</section>}
      {groups.details.length > 0 && <details className="rounded-xl border border-[var(--border)] p-3 text-sm text-[var(--text-secondary)]"><summary className="cursor-pointer font-medium">Lesson details &amp; sources</summary><div className="mt-3 space-y-3">{render(groups.details)}</div></details>}
    </div>
  );
}
