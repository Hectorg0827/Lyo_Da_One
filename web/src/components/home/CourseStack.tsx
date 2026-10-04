'use client';

import { type ReactNode, useMemo, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { ChevronDown, ChevronUp, Clock, Play, RotateCcw, Check, Layers } from 'lucide-react';
import type { StackItem } from '@/lib/stack';
import CourseArtwork from '@/components/home/CourseArtwork';
import {
  ACTION_REVIEW,
  BLURB_DESCRIPTION,
  BLURB_NONE,
  FILTERS,
  FILTER_ALL,
  PROGRESS_MEASURED,
  actionFor,
  actionLabel,
  blurbFor,
  countForFilter,
  DECK_CARD_GAP,
  DECK_NEXT_CARD_PEEK,
  deckLayers,
  deckMoreLabel,
  deckStaggerMilliseconds,
  isFinished,
  matchesFilter,
  progressFor,
} from '@/lib/focus-presentation.mjs';

/**
 * Every saved course, once.
 *
 * Saved courses are one list — the backend's stack items (see lib/stack.ts).
 * This page used to show the top of that list as a big hero card and the rest
 * as a row of small ones, which made one collection look like two features.
 * Now it is one stack, newest first, with chips to narrow it.
 *
 * Tapping a card turns it over for the description the backend already sends
 * and this page previously dropped. The action stays on the front, so
 * resuming a course is still one click and never behind an animation.
 *
 * The list arrives as a deck: one card with the rest stacked under it, which
 * opens into a sideways row on a click. Shut, its Resume link already works,
 * so a learner coming back to a course is never made to open an animation
 * first — only the card body's click is taken over.
 *
 * Open, each card gives up room so the next one's edge is visible. A card the
 * full width of the screen would put every course after the first behind a
 * swipe nothing signals, which is what the row of small cards this replaced
 * already did wrong.
 */

function formatTouched(dateStr?: string | null): string | null {
  if (!dateStr) return null;
  const then = new Date(dateStr).getTime();
  if (!Number.isFinite(then)) return null;
  const minutes = Math.round((Date.now() - then) / 60000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days === 1) return 'Yesterday';
  if (days < 30) return `${days} days ago`;
  const months = Math.round(days / 30);
  return months === 1 ? 'Last month' : `${months} months ago`;
}

export default function CourseStack({
  items,
  renderMenu,
}: {
  items: StackItem[];
  /** The share / post-to-community menu, kept from the previous cards. */
  renderMenu?: (item: StackItem) => ReactNode;
}) {
  const [filter, setFilter] = useState<string>(FILTER_ALL);
  const [expanded, setExpanded] = useState(false);

  const visible = useMemo(
    () => items.filter((item) => matchesFilter(item, filter)),
    [items, filter],
  );

  const layers = deckLayers(visible.length);
  const deepestPeek = layers.length > 0 ? layers[layers.length - 1].offset : 0;
  const more = deckMoreLabel(visible.length);

  if (items.length === 0) {
    return (
      <Link
        href="/discover"
        className="glass-card flex flex-col items-center gap-2 p-6 text-center transition-all duration-200 hover:bg-white/[0.07]"
      >
        <Layers size={28} className="text-secondary" />
        <p className="text-sm font-semibold text-primary">No courses in your Stacks yet</p>
        <p className="text-xs text-secondary">
          Start a course and it&apos;ll show up here — and on any other device you sign into.
        </p>
      </Link>
    );
  }

  return (
    <div className="space-y-3">
      <div className="no-scrollbar -mx-4 flex gap-1.5 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
        {FILTERS.map((option) => {
          const count = countForFilter(items, option.id);
          const active = filter === option.id;
          return (
            <button
              key={option.id}
              type="button"
              onClick={() => setFilter(option.id)}
              aria-pressed={active}
              className={[
                'shrink-0 rounded-full px-3 py-1.5 text-[11px] font-semibold tabular-nums transition-colors duration-200',
                active
                  ? 'border border-[#A78BFA]/45 bg-[#8B5CF6]/25 text-white'
                  : 'border border-white/[0.07] bg-white/[0.045] text-white/60 hover:text-white',
              ].join(' ')}
            >
              {option.label} {count}
            </button>
          );
        })}
      </div>

      {visible.length === 0 ? (
        <p className="rounded-2xl border border-white/[0.065] bg-white/[0.025] py-7 text-center text-xs text-white/45">
          No courses in this filter.
        </p>
      ) : (
        <div className="space-y-3">
          {expanded ? (
            /* Open, the deck is a sideways row that snaps card to card.
               Cards arrive one after another rather than all at once, which
               is what makes it read as opening instead of simply appearing.
               The delays and the widths are shared with iOS and Android. */
            <div
              className="no-scrollbar -mx-4 flex snap-x snap-mandatory overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0"
              style={{ gap: DECK_CARD_GAP }}
            >
              {visible.map((item, index) => (
                <motion.div
                  key={item.id}
                  className="shrink-0 snap-start"
                  style={{ width: `calc(100% - ${DECK_NEXT_CARD_PEEK + DECK_CARD_GAP}px)` }}
                  initial={{ opacity: 0, scale: 0.96, x: 28 }}
                  animate={{ opacity: 1, scale: 1, x: 0 }}
                  transition={{
                    type: 'spring',
                    stiffness: 320,
                    damping: 30,
                    delay: deckStaggerMilliseconds(index) / 1000,
                  }}
                >
                  <CourseCard item={item} menu={renderMenu?.(item)} />
                </motion.div>
              ))}
            </div>
          ) : (
            /* Shut, the top card is live — artwork, progress and a working
               Resume link. Only the card body's click is taken over, so a
               learner coming back to a course never has to open the deck
               first. */
            <div className="relative" style={{ paddingBottom: deepestPeek }}>
              {layers.map((layer) => (
                /* Blank cards, deliberately: they stand for courses the
                   learner has, and a title drawn at 90% scale and half
                   opacity would be a label nobody can read. */
                <div
                  key={layer.depth}
                  aria-hidden
                  className="absolute inset-x-0 h-[206px] rounded-[21px] border border-white/[0.11] bg-[#1C2436]"
                  style={{
                    top: layer.offset,
                    opacity: layer.opacity,
                    transform: `scaleX(${layer.scale})`,
                    transformOrigin: 'top center',
                  }}
                />
              ))}

              <div className="relative z-10">
                <CourseCard
                  item={visible[0]}
                  menu={renderMenu?.(visible[0])}
                  onBodyClick={layers.length === 0 ? undefined : () => setExpanded(true)}
                />
              </div>
            </div>
          )}

          {more && (
            /* Shut, this says how many courses are waiting — the real number
               from the list, not the two cards drawn behind the top one. */
            <button
              type="button"
              onClick={() => setExpanded(!expanded)}
              aria-expanded={expanded}
              className="flex w-full items-center justify-center gap-1.5 rounded-full border border-white/[0.08] bg-white/[0.05] py-2.5 font-rounded text-[12px] font-semibold tabular-nums text-white/70 transition-colors duration-200 hover:bg-white/[0.09] hover:text-white"
            >
              <Layers size={12} />
              {expanded ? 'Stack them back up' : more}
              {expanded ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function CourseCard({
  item,
  menu,
  onBodyClick,
}: {
  item: StackItem;
  menu?: ReactNode;
  /**
   * Takes over the card body's click, for the top card of a closed deck.
   *
   * When the deck is shut, clicking the card sitting on top of it should open
   * the deck, not turn that one card over. The Resume link and the flip
   * button are untouched either way, so a closed deck never costs a learner
   * a click on the way to studying.
   */
  onBodyClick?: () => void;
}) {
  const [flipped, setFlipped] = useState(false);
  const openBack = onBodyClick ?? (() => setFlipped(true));

  const href = `/courses/${item.content_id || item.id}`;
  const action = actionFor(item);
  const finished = isFinished(item);
  const blurb = blurbFor(item);
  const progress = progressFor(item);
  const touched = formatTouched(item.updated_at);

  return (
    <div className="[perspective:1400px]">
      <motion.div
        className="relative h-[206px] [transform-style:preserve-3d]"
        animate={{ rotateY: flipped ? 180 : 0 }}
        transition={{ type: 'spring', stiffness: 260, damping: 26 }}
      >
        {/* ── Front ── */}
        <div
          className="absolute inset-0 overflow-hidden rounded-[21px] border border-white/10 shadow-[0_18px_32px_-16px_rgba(0,0,0,0.95)] [backface-visibility:hidden]"
          onClick={openBack}
          role="button"
          tabIndex={flipped ? -1 : 0}
          aria-label={
            onBodyClick ? `${item.title} — open the stack` : `${item.title} — show description`
          }
          onKeyDown={(event) => {
            if (event.key === 'Enter' || event.key === ' ') {
              event.preventDefault();
              openBack();
            }
          }}
        >
          <CourseArtwork title={item.title} className="absolute inset-0 h-full w-full" />
          {/* The scrim carries the title, so it is weighted to the lower
              half rather than spread evenly: the staff and orbit motifs draw
              pale lines exactly where the text sits. */}
          <div className="absolute inset-0 bg-[linear-gradient(to_bottom,rgba(5,7,13,0.06)_0%,rgba(5,7,13,0.52)_44%,rgba(5,7,13,0.94)_100%)]" />

          {finished && (
            <span className="absolute left-3.5 top-3.5 inline-flex items-center gap-1 rounded-md border border-[#10B981]/45 bg-[#10B981]/20 px-2 py-1 text-[9px] font-bold uppercase tracking-[0.11em] text-[#BDF5DA]">
              <Check size={9} strokeWidth={3} />
              Finished
            </span>
          )}

          <div
            className="absolute right-3 top-3 flex items-center gap-1.5"
            onClick={(event) => event.stopPropagation()}
          >
            {menu}
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                setFlipped(true);
              }}
              aria-label="Flip card"
              className="grid h-[29px] w-[29px] place-items-center rounded-full border border-white/[0.15] bg-black/40 text-white backdrop-blur-md transition-colors hover:bg-black/70"
            >
              <RotateCcw size={13} />
            </button>
          </div>

          <div className="absolute inset-x-0 bottom-0 flex flex-col gap-2.5 p-4">
            <h3 className="font-rounded text-[16.5px] font-bold leading-[1.18] tracking-[-0.028em] text-white line-clamp-2">
              {item.title}
            </h3>

            <div className="flex items-center gap-1.5 text-[10.5px] font-medium text-white/55 tabular-nums">
              {touched && (
                <>
                  <Clock size={11} />
                  <span>{touched}</span>
                </>
              )}
            </div>

            {progress.kind === PROGRESS_MEASURED ? (
              <div className="flex items-center gap-2">
                <div className="h-1 flex-1 overflow-hidden rounded-full bg-white/20">
                  <div
                    className="h-full rounded-full transition-all duration-700"
                    style={{
                      width: `${progress.percent}%`,
                      backgroundColor: finished ? '#3ED68E' : '#B59CFF',
                    }}
                  />
                </div>
                <span className="shrink-0 text-[10px] font-bold text-white/70 tabular-nums">
                  {finished
                    ? 'Complete'
                    : item.status === 'not_started' && progress.percent === 0
                      ? 'Not started'
                      : `${progress.percent}%`}
                </span>
              </div>
            ) : (
              /* No figure arrived. An empty bar would claim the learner is at
                 the start of the course, which is a different thing. */
              <p className="text-[10px] font-semibold text-white/45">Progress not recorded yet</p>
            )}

            <div className="flex items-center gap-2">
              <Link
                href={href}
                onClick={(event) => event.stopPropagation()}
                className="inline-flex items-center gap-1.5 rounded-full bg-white px-4 py-2 font-rounded text-[12.5px] font-bold text-[#0A0D16] shadow-[0_6px_16px_-6px_rgba(0,0,0,0.8)] transition-transform duration-200 hover:scale-[1.03]"
              >
                <Play size={12} className="fill-current" />
                {actionLabel(action)}
              </Link>
            </div>
          </div>
        </div>

        {/* ── Back ── */}
        <div
          className="absolute inset-0 overflow-hidden rounded-[21px] border border-white/10 bg-[#141A2A] shadow-[0_18px_32px_-16px_rgba(0,0,0,0.95)] [backface-visibility:hidden] [transform:rotateY(180deg)]"
          onClick={() => setFlipped(false)}
          role="button"
          tabIndex={flipped ? 0 : -1}
          aria-label="Back of card — flip to return"
          onKeyDown={(event) => {
            if (event.key === 'Enter' || event.key === ' ') {
              event.preventDefault();
              setFlipped(false);
            }
          }}
        >
          <CourseArtwork title={item.title} className="absolute inset-0 h-full w-full opacity-[0.16]" />

          <button
            type="button"
            onClick={(event) => {
              event.stopPropagation();
              setFlipped(false);
            }}
            aria-label="Flip back"
            className="absolute right-3 top-3 z-10 grid h-[29px] w-[29px] place-items-center rounded-full border border-white/[0.15] bg-black/40 text-white backdrop-blur-md transition-colors hover:bg-black/70"
          >
            <RotateCcw size={13} className="-scale-x-100" />
          </button>

          <div className="relative flex h-full flex-col gap-2 p-4">
            <p className="text-[9.5px] font-bold uppercase tracking-[0.14em] text-[#B59CFF]">
              About this course
            </p>

            {blurb.kind === BLURB_DESCRIPTION ? (
              <p className="text-[12px] leading-[1.52] text-white/[0.78] line-clamp-5">{blurb.text}</p>
            ) : blurb.kind === BLURB_NONE ? (
              <p className="text-[12px] text-white/50">No description was saved with this course.</p>
            ) : (
              <div className="space-y-1">
                <p className="text-[10.5px] font-semibold text-white/40">Where it stands</p>
                <p className="text-[13px] font-semibold text-white/[0.84]">{blurb.text}</p>
              </div>
            )}

            <div className="mt-auto">
              <Link
                href={href}
                onClick={(event) => event.stopPropagation()}
                className="inline-flex items-center gap-1.5 rounded-full border border-white/[0.16] bg-white/[0.11] px-4 py-2 font-rounded text-[12.5px] font-bold text-white transition-colors hover:bg-white/20"
              >
                <Play size={12} className="fill-current" />
                {actionLabel(action === ACTION_REVIEW ? ACTION_REVIEW : action)}
              </Link>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
