'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AnimatePresence,
  motion,
  useMotionValue,
  useReducedMotion,
  useTransform,
  type PanInfo,
} from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import { ChevronLeft, ChevronRight, Layers, Loader2, RotateCw } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
import { DECK_BATCH_SIZE, DECK_MAX_CARDS, nextDeckStep } from '@/lib/study-material.mjs';
import type { ChatBlock, ChatMessage } from '@/types';
import {
  markdownComponents,
  MARKDOWN_MATH_PLUGINS,
  normalizeLatexDelimiters,
} from '../markdown-config';

interface DeckCard {
  front: string;
  back: string;
}

/** Past this much drag, or this much flick, the release counts as a swipe. */
const SWIPE_DISTANCE = 72;
const SWIPE_VELOCITY = 450;

/** One spring, used for every card movement, so the deck feels like one object. */
const SPRING = { type: 'spring', stiffness: 420, damping: 36, mass: 0.8 } as const;
const FLIP_SPRING = { type: 'spring', stiffness: 260, damping: 26, mass: 0.9 } as const;

/** A card entering and leaving, in the direction the learner swiped. */
const slide = {
  enter: (direction: number) => ({
    x: direction > 0 ? 320 : -320,
    opacity: 0,
    scale: 0.92,
    rotate: direction > 0 ? 4 : -4,
  }),
  center: { x: 0, opacity: 1, scale: 1, rotate: 0 },
  exit: (direction: number) => ({
    x: direction > 0 ? -320 : 320,
    opacity: 0,
    scale: 0.92,
    rotate: direction > 0 ? -4 : 4,
  }),
};

function Face({ text, muted }: { text: string; muted?: boolean }) {
  return (
    <div
      className={cn(
        'prose-invert prose-sm max-w-none',
        muted ? 'text-white/80' : 'text-white/95'
      )}
    >
      <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
        {normalizeLatexDelimiters(text)}
      </ReactMarkdown>
    </div>
  );
}

/**
 * A flashcard deck the learner works through a batch at a time.
 *
 * Three things make it a deck rather than a list:
 *
 * - **One card at a time.** The answer is hidden until the learner commits to
 *   recalling it; a card that shows both faces is a paragraph with a border.
 * - **Batched.** Reaching the last card asks the model for the next three, so
 *   the deck keeps pace with the learner instead of front-loading forty cards.
 *   A batch is requested on arrival at the final card, not on leaving it, so
 *   the next swipe is usually already paid for.
 * - **Swipeable.** Drag or flick horizontally, or use the arrows and the
 *   keyboard — pointer gestures are an addition to the buttons, never the only
 *   way through, since a deck that needs a touchscreen excludes half its users.
 */
export default function FlashcardDeckBlock({
  block,
  message,
}: {
  block: ChatBlock;
  message: ChatMessage;
}) {
  const extendFlashcardDeck = useChatStore((state) => state.extendFlashcardDeck);
  const reduceMotion = useReducedMotion();

  const content = (block.content ?? {}) as Record<string, unknown>;
  const title = typeof content.title === 'string' ? content.title : 'Study deck';

  const cards = useMemo<DeckCard[]>(() => {
    const rows = Array.isArray(content.cards) ? content.cards : [];
    return rows
      .map((row) => (row ?? {}) as Record<string, unknown>)
      .filter((row) => typeof row.front === 'string' && row.front.length > 0)
      .map((row) => ({
        front: String(row.front),
        back: typeof row.back === 'string' ? row.back : '',
      }));
  }, [content.cards]);

  // Drag position, so the card tilts and dims under the hand instead of
  // sliding flat. Released, framer springs it back to the constraints at 0.
  const dragX = useMotionValue(0);
  const dragTilt = useTransform(dragX, [-220, 0, 220], [-9, 0, 9]);
  const dragFade = useTransform(dragX, [-220, 0, 220], [0.45, 1, 0.45]);

  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(DECK_BATCH_SIZE);
  const [flipped, setFlipped] = useState(false);
  const [direction, setDirection] = useState(1);
  const [loading, setLoading] = useState(false);
  const [exhausted, setExhausted] = useState(false);

  // How many cards the learner may reach right now.
  const visible = Math.min(revealed, cards.length);

  // One in-flight request at a time. A ref, not state, because two effect runs
  // in the same tick would both read a stale `loading` and ask twice.
  const requesting = useRef(false);

  // Unmount, tracked separately from the effect below.
  //
  // Cancelling in that effect's cleanup looked right and was wrong: setting
  // `loading` re-runs the effect, the cleanup fires, and the request still in
  // flight is treated as abandoned — so the spinner never cleared and the deck
  // sat on "Writing 3 more…" forever. Only leaving the page cancels.
  //
  // Re-armed on every mount, not just initialised once: React's StrictMode
  // mounts, unmounts and remounts in development, and a flag only cleared on
  // unmount stays cleared through the second mount — which left every reply
  // treated as abandoned and the spinner up for good.
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const step = nextDeckStep({
    index,
    revealed,
    total: cards.length,
    loading,
    exhausted,
    max: DECK_MAX_CARDS,
  });

  useEffect(() => {
    if (step === 'idle') return;

    // Cards already parsed from the reply cost nothing — just show more.
    if (step === 'reveal') {
      setRevealed((count) => count + DECK_BATCH_SIZE);
      return;
    }
    if (requesting.current) return;

    requesting.current = true;
    setLoading(true);

    extendFlashcardDeck(message.id, block.id)
      .then((added) => {
        if (!mounted.current) return;
        if (added > 0) setRevealed((count) => count + DECK_BATCH_SIZE);
        else setExhausted(true);
      })
      .catch(() => {
        if (mounted.current) setExhausted(true);
      })
      .finally(() => {
        requesting.current = false;
        if (mounted.current) setLoading(false);
      });
  }, [step, extendFlashcardDeck, message.id, block.id]);

  const go = useCallback(
    (delta: number) => {
      const last = Math.min(revealed, cards.length) - 1;
      const next = index + delta;
      // A move past either end changes nothing — in particular it must not
      // turn a flipped card back over.
      if (next < 0 || next > last) return;
      setDirection(delta);
      setFlipped(false);
      setIndex(next);
    },
    [index, revealed, cards.length]
  );

  const onDragEnd = useCallback(
    (_event: unknown, info: PanInfo) => {
      const { offset, velocity } = info;
      if (offset.x < -SWIPE_DISTANCE || velocity.x < -SWIPE_VELOCITY) go(1);
      else if (offset.x > SWIPE_DISTANCE || velocity.x > SWIPE_VELOCITY) go(-1);
    },
    [go]
  );

  if (!cards.length) return null;

  const safeIndex = Math.min(index, Math.max(visible - 1, 0));
  const card = cards[safeIndex];
  const hasPrevious = safeIndex > 0;
  const hasNext = safeIndex < visible - 1;
  const motionTransition = reduceMotion ? { duration: 0 } : SPRING;

  return (
    <div className="rounded-2xl border border-lyo-500/20 bg-gradient-to-b from-lyo-500/10 to-transparent p-4">
      <div className="flex items-center gap-2 mb-3">
        <Layers className="w-4 h-4 text-lyo-300 shrink-0" aria-hidden="true" />
        <div className="text-sm font-semibold text-white/85 min-w-0 truncate">{title}</div>
        <div className="ml-auto shrink-0 text-[11px] text-white/45 tabular-nums">
          {safeIndex + 1} / {visible}
        </div>
      </div>

      {/* Progress: filled so far, then the rest of the batch in reserve. */}
      <div className="flex gap-1 mb-3" aria-hidden="true">
        {Array.from({ length: visible }).map((_, dot) => (
          <motion.span
            key={dot}
            className="h-1 flex-1 rounded-full bg-white/10 overflow-hidden"
            initial={false}
          >
            <motion.span
              className="block h-full rounded-full bg-lyo-400"
              initial={false}
              animate={{ scaleX: dot <= safeIndex ? 1 : 0 }}
              style={{ transformOrigin: 'left' }}
              transition={reduceMotion ? { duration: 0 } : { duration: 0.35, ease: 'easeOut' }}
            />
          </motion.span>
        ))}
      </div>

      {/* Taller than the card itself, to leave room for the deck behind it. */}
      <div className="relative h-[240px] select-none" style={{ perspective: 1400 }}>
        {/* The rest of the deck, sitting behind and below the live card. */}
        {hasNext && (
          <>
            <motion.div
              className="absolute inset-x-0 top-0 h-[216px] rounded-2xl border border-white/5 bg-[#14122b]"
              style={{ transformOrigin: 'top center' }}
              initial={false}
              animate={{ scale: 0.9, y: 42, opacity: 0.4 }}
              transition={motionTransition}
              aria-hidden="true"
            />
            <motion.div
              className="absolute inset-x-0 top-0 h-[216px] rounded-2xl border border-white/10 bg-[#14122b]"
              style={{ transformOrigin: 'top center' }}
              initial={false}
              animate={{ scale: 0.95, y: 21, opacity: 0.65 }}
              transition={motionTransition}
              aria-hidden="true"
            />
          </>
        )}

        <AnimatePresence initial={false} custom={direction} mode="popLayout">
          <motion.div
            key={safeIndex}
            custom={direction}
            variants={reduceMotion ? undefined : slide}
            initial="enter"
            animate="center"
            exit="exit"
            transition={motionTransition}
            className="absolute inset-x-0 top-0 h-[216px]"
          >
            {/* Gesture layer, kept separate from the enter/exit layer above so
                the two never animate the same value at once. */}
            <motion.div
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.2}
              onDragEnd={onDragEnd}
              whileDrag={{ cursor: 'grabbing' }}
              style={reduceMotion ? undefined : { x: dragX, rotate: dragTilt, opacity: dragFade }}
              className="w-full h-full cursor-grab active:cursor-grabbing touch-pan-y"
            >
            <motion.button
              type="button"
              onClick={() => setFlipped((value) => !value)}
              aria-pressed={flipped}
              aria-label={flipped ? 'Show the question' : 'Show the answer'}
              animate={{ rotateY: flipped ? 180 : 0 }}
              transition={reduceMotion ? { duration: 0 } : FLIP_SPRING}
              style={{ transformStyle: 'preserve-3d' }}
              className={cn(
                'relative w-full h-full rounded-2xl text-left',
                'focus:outline-none focus-visible:ring-2 focus-visible:ring-lyo-400/75'
              )}
            >
              {/* Both faces stay mounted: a screen reader and find-in-page
                  should still reach the answer that is turned away. */}
              <span
                className={cn(
                  'absolute inset-0 rounded-2xl border border-white/10 bg-[#14122b]',
                  'p-5 flex flex-col overflow-y-auto shadow-xl shadow-black/40'
                )}
                style={{ backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}
              >
                <span className="text-[10px] uppercase tracking-[0.12em] text-white/35 mb-2">
                  Question
                </span>
                <span className="flex-1 flex items-center">
                  <Face text={card.front} />
                </span>
              </span>

              <span
                className={cn(
                  'absolute inset-0 rounded-2xl border border-lyo-400/25 bg-[#1d1840]',
                  'p-5 flex flex-col overflow-y-auto shadow-xl shadow-black/40'
                )}
                style={{
                  backfaceVisibility: 'hidden',
                  WebkitBackfaceVisibility: 'hidden',
                  transform: 'rotateY(180deg)',
                }}
              >
                <span className="text-[10px] uppercase tracking-[0.12em] text-lyo-200/60 mb-2">
                  Answer
                </span>
                {card.back ? (
                  <Face text={card.back} muted />
                ) : (
                  <span className="text-sm text-white/40">No answer on this card.</span>
                )}
              </span>
              </motion.button>
            </motion.div>
          </motion.div>
        </AnimatePresence>
      </div>

      <div className="flex items-center gap-2 mt-3">
        <button
          type="button"
          onClick={() => go(-1)}
          disabled={!hasPrevious}
          className="p-2 rounded-xl border border-white/10 text-white/70 transition-colors hover:bg-white/5 disabled:opacity-25 disabled:cursor-not-allowed"
          aria-label="Previous card"
        >
          <ChevronLeft className="w-4 h-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          onClick={() => go(1)}
          disabled={!hasNext}
          className="p-2 rounded-xl border border-white/10 text-white/70 transition-colors hover:bg-white/5 disabled:opacity-25 disabled:cursor-not-allowed"
          aria-label="Next card"
        >
          <ChevronRight className="w-4 h-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          onClick={() => setFlipped((value) => !value)}
          className="p-2 rounded-xl border border-white/10 text-white/70 transition-colors hover:bg-white/5"
          aria-label={flipped ? 'Show the question' : 'Show the answer'}
        >
          <RotateCw className="w-4 h-4" aria-hidden="true" />
        </button>

        <div className="ml-auto text-[11px] text-white/40 flex items-center gap-1.5 min-w-0">
          {loading ? (
            <>
              <Loader2 className="w-3 h-3 animate-spin shrink-0" aria-hidden="true" />
              <span className="truncate">Writing {DECK_BATCH_SIZE} more…</span>
            </>
          ) : exhausted && !hasNext ? (
            <span className="truncate">That&apos;s the whole deck</span>
          ) : (
            <span className="truncate">Swipe or tap to flip</span>
          )}
        </div>
      </div>

      {/* The position, for anyone who cannot see the card move. */}
      <span className="sr-only" aria-live="polite">
        Card {safeIndex + 1} of {visible}. Showing the {flipped ? 'answer' : 'question'}.
      </span>
    </div>
  );
}
