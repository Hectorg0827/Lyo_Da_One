'use client';

import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { usePathname } from 'next/navigation';
import { ChevronLeft, ChevronRight, FastForward } from 'lucide-react';
import { useClassroomStore } from '@/stores/classroom-store';

type FlowHosts = {
  rail: HTMLElement | null;
  desk: HTMLElement | null;
};

function isClassroomPath(pathname: string): boolean {
  return pathname === '/classroom' || pathname.startsWith('/classroom/');
}

function findPlaybackRail(): HTMLElement | null {
  const statusSpans = Array.from(document.querySelectorAll('span.font-mono'));
  for (const span of statusSpans) {
    const text = span.textContent?.trim() ?? '';
    if (text !== 'live' && !/^\d+\/\d+$/.test(text)) continue;
    const parent = span.parentElement;
    if (!parent) continue;
    const directButtons = Array.from(parent.children).filter(
      (child) => child instanceof HTMLButtonElement,
    );
    if (directButtons.length >= 2) return parent;
  }
  return null;
}

function findDesk(): HTMLElement | null {
  const getHelp = Array.from(document.querySelectorAll('button')).find(
    (button) => button.textContent?.replace(/\s+/g, ' ').trim() === 'Get help',
  );
  if (!getHelp) return null;

  let node: HTMLElement | null = getHelp.parentElement;
  while (node && node !== document.body) {
    if (node.classList.contains('space-y-2')) return node;
    node = node.parentElement;
  }
  return null;
}

function ensurePortalHost(
  container: HTMLElement,
  attribute: 'data-lyo-flow-rail-host' | 'data-lyo-flow-desk-host',
  before?: Element | null,
): HTMLElement {
  const existing = container.querySelector<HTMLElement>(`[${attribute}]`);
  if (existing) return existing;

  const host = document.createElement('div');
  host.setAttribute(attribute, 'true');
  if (before) container.insertBefore(host, before);
  else container.appendChild(host);
  return host;
}

/**
 * Owns the learner-facing classroom transport controls.
 *
 * The original classroom page renders its transport rail before it knows
 * whether the server has finished a scene, so Back/Skip can look like inert
 * placeholders and the CTA can disappear when a scene arrives without an
 * explicit CTAButton. This layer derives actions from the live classroom
 * state instead:
 *
 * - Skip only exists while narration is actually playing.
 * - Previous only exists when a previous board really exists.
 * - Continue appears after narration has finished and the scene has no
 *   unanswered learner checkpoint, even if a CTAButton was omitted.
 * - While browsing history, Next/Live move through real board snapshots.
 *
 * It uses the same Zustand actions as the classroom page, so these are real
 * transport controls rather than decorative UI.
 */
export default function ClassroomFlowControls() {
  const pathname = usePathname();
  const active = isClassroomPath(pathname);

  const status = useClassroomStore((state) => state.status);
  const board = useClassroomStore((state) => state.board);
  const boardHistory = useClassroomStore((state) => state.boardHistory);
  const viewingBoard = useClassroomStore((state) => state.viewingBoard);
  const waitingForScene = useClassroomStore((state) => state.waitingForScene);
  const isNarrating = useClassroomStore((state) => state.isNarrating);
  const prompt = useClassroomStore((state) => state.prompt);
  const canContinue = useClassroomStore((state) => state.canContinue);
  const continueLabel = useClassroomStore((state) => state.continueLabel);
  const languageCode = useClassroomStore((state) => state.languageCode);
  const skipTurn = useClassroomStore((state) => state.skipTurn);
  const continueLesson = useClassroomStore((state) => state.continueLesson);
  const viewBoard = useClassroomStore((state) => state.viewBoard);

  const [hosts, setHosts] = useState<FlowHosts>({ rail: null, desk: null });

  const pendingCheckpoint = useMemo(
    () => board.some((element) => {
      if (element.kind === 'quiz') return !element.answered && !element.skipped;
      if (element.kind === 'transfer') return !element.submitted && !element.skipped;
      return false;
    }),
    [board],
  );

  const live = status === 'live';
  const atLiveBoard = viewingBoard === -1;
  const hasLessonContent = board.length > 0;

  // CTAButton remains authoritative when present. The second branch is the
  // recovery path for a completed instructional scene that omitted the CTA:
  // if narration is done and there is no question waiting on the learner,
  // `continue` is a valid canonical classroom action on the backend.
  const readyToContinue = live
    && atLiveBoard
    && !waitingForScene
    && !isNarrating
    && !prompt
    && !pendingCheckpoint
    && (canContinue || hasLessonContent);

  const totalHistory = boardHistory.length;
  const canGoPrevious = viewingBoard === -1
    ? totalHistory > 0
    : viewingBoard > 0;

  const secondaryLabel = continueLabel?.trim() || '';
  const spanish = languageCode.toLowerCase().startsWith('es');
  const primaryContinue = spanish ? 'Continuar' : 'Continue';

  useEffect(() => {
    if (!active || typeof document === 'undefined') {
      setHosts({ rail: null, desk: null });
      return;
    }

    document.body.classList.add('lyo-classroom-flow-v2');

    let railHost: HTMLElement | null = null;
    let deskHost: HTMLElement | null = null;

    const mount = () => {
      const rail = findPlaybackRail();
      if (rail) {
        rail.dataset.lyoFlowRail = 'true';
        railHost = ensurePortalHost(rail, 'data-lyo-flow-rail-host');
      }

      const desk = findDesk();
      if (desk) {
        desk.dataset.lyoFlowDesk = 'true';
        const helpRow = Array.from(desk.children).find((child) => (
          child instanceof HTMLElement
          && Array.from(child.querySelectorAll('button')).some(
            (button) => button.textContent?.replace(/\s+/g, ' ').trim() === 'Get help',
          )
        ));
        deskHost = ensurePortalHost(desk, 'data-lyo-flow-desk-host', helpRow ?? null);
      }

      setHosts((current) => (
        current.rail === railHost && current.desk === deskHost
          ? current
          : { rail: railHost, desk: deskHost }
      ));
    };

    mount();
    const observer = new MutationObserver(mount);
    observer.observe(document.body, { childList: true, subtree: true });

    return () => {
      observer.disconnect();
      document.body.classList.remove('lyo-classroom-flow-v2');
      document.querySelectorAll<HTMLElement>('[data-lyo-flow-rail="true"]').forEach((element) => {
        delete element.dataset.lyoFlowRail;
      });
      document.querySelectorAll<HTMLElement>('[data-lyo-flow-desk="true"]').forEach((element) => {
        delete element.dataset.lyoFlowDesk;
      });
      railHost?.remove();
      deskHost?.remove();
    };
  }, [active]);

  const goPrevious = () => {
    if (!canGoPrevious) return;
    if (viewingBoard === -1) viewBoard(totalHistory - 1);
    else viewBoard(viewingBoard - 1);
  };

  const goForward = () => {
    if (viewingBoard !== -1) {
      viewBoard(viewingBoard >= totalHistory - 1 ? -1 : viewingBoard + 1);
      return;
    }
    if (isNarrating) {
      skipTurn();
      return;
    }
    if (readyToContinue) continueLesson();
  };

  if (!active) return null;

  const rail = hosts.rail
    ? createPortal(
        <div className="flex items-center justify-between gap-2 px-2 py-1">
          <div className="w-24">
            {canGoPrevious && (
              <button
                type="button"
                onClick={goPrevious}
                className="flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[10.5px] font-semibold text-white/70 transition-colors hover:bg-white/5 hover:text-white"
                title="Previous lesson board"
              >
                <ChevronLeft className="h-3.5 w-3.5" /> Previous
              </button>
            )}
          </div>

          <span className="text-[10px] font-mono uppercase tracking-[0.12em] text-white/45">
            {viewingBoard === -1 ? 'live' : `${viewingBoard + 1}/${totalHistory}`}
          </span>

          <div className="flex w-24 justify-end">
            {viewingBoard !== -1 ? (
              <button
                type="button"
                onClick={goForward}
                className="flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[10.5px] font-semibold text-white/70 transition-colors hover:bg-white/5 hover:text-white"
              >
                {viewingBoard >= totalHistory - 1 ? 'Live' : 'Next'}
                <ChevronRight className="h-3.5 w-3.5" />
              </button>
            ) : isNarrating ? (
              <button
                type="button"
                onClick={goForward}
                className="flex items-center gap-1 rounded px-1.5 py-0.5 text-[10.5px] font-semibold text-white/70 transition-colors hover:bg-white/5 hover:text-white"
                title="Skip the explanation currently playing"
              >
                Skip <FastForward className="h-3.5 w-3.5" />
              </button>
            ) : readyToContinue ? (
              <button
                type="button"
                onClick={goForward}
                className="flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[10.5px] font-semibold text-lyo-200 transition-colors hover:bg-lyo-500/10 hover:text-white"
              >
                {primaryContinue} <ChevronRight className="h-3.5 w-3.5" />
              </button>
            ) : null}
          </div>
        </div>,
        hosts.rail,
      )
    : null;

  const desk = hosts.desk && readyToContinue
    ? createPortal(
        <button
          type="button"
          onClick={continueLesson}
          className="mb-2 w-full rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2.5 text-white transition-all hover:opacity-90 active:scale-[0.99]"
        >
          <span className="flex items-center justify-center gap-2 text-sm font-semibold">
            {primaryContinue} <ChevronRight className="h-4 w-4" />
          </span>
          {canContinue && secondaryLabel && secondaryLabel.toLowerCase() !== primaryContinue.toLowerCase() && (
            <span className="mt-0.5 block text-[10.5px] text-white/65">
              {secondaryLabel}
            </span>
          )}
        </button>,
        hosts.desk,
      )
    : null;

  return (
    <>
      <style jsx global>{`
        body.lyo-classroom-flow-v2 [data-lyo-flow-rail='true'] > :not([data-lyo-flow-rail-host]) {
          display: none !important;
        }
        body.lyo-classroom-flow-v2 [data-lyo-flow-desk='true'] > button.w-full {
          display: none !important;
        }
      `}</style>
      {rail}
      {desk}
    </>
  );
}
