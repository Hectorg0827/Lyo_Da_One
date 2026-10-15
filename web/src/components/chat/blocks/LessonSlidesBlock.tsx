'use client';

import { useCallback, useMemo, useState } from 'react';
import {
  AnimatePresence,
  motion,
  useMotionValue,
  useReducedMotion,
  useTransform,
  type PanInfo,
} from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import { ChevronLeft, ChevronRight, Presentation } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ChatBlock } from '@/types';
import {
  markdownComponents,
  MARKDOWN_MATH_PLUGINS,
  normalizeLatexDelimiters,
} from '../markdown-config';

interface Slide {
  title: string;
  body: string;
}

/** Past this much drag, or this much flick, the release counts as a swipe. */
const SWIPE_DISTANCE = 72;
const SWIPE_VELOCITY = 450;

/** The deck's spring, so slides and flashcards move like one system. */
const SPRING = { type: 'spring', stiffness: 420, damping: 36, mass: 0.8 } as const;

const slide = {
  enter: (direction: number) => ({ x: direction > 0 ? 320 : -320, opacity: 0, scale: 0.96 }),
  center: { x: 0, opacity: 1, scale: 1 },
  exit: (direction: number) => ({ x: direction > 0 ? -320 : 320, opacity: 0, scale: 0.96 }),
};

/**
 * A lesson presented a slide at a time.
 *
 * The same gestures as the flashcard deck — drag, flick, arrows, and the
 * keyboard through the buttons — because a learner who has swiped one should
 * not have to work out the other. No flip: a slide has one face, and hiding
 * half of an explanation behind a tap would be a puzzle, not a lesson.
 */
export default function LessonSlidesBlock({ block }: { block: ChatBlock }) {
  const reduceMotion = useReducedMotion();
  const content = (block.content ?? {}) as Record<string, unknown>;
  const title = typeof content.title === 'string' ? content.title : 'Slides';

  const slides = useMemo<Slide[]>(() => {
    const rows = Array.isArray(content.slides) ? content.slides : [];
    return rows
      .map((row) => (row ?? {}) as Record<string, unknown>)
      .map((row) => ({
        title: typeof row.title === 'string' ? row.title : '',
        body: typeof row.body === 'string' ? row.body : '',
      }))
      .filter((row) => row.title || row.body);
  }, [content.slides]);

  const [index, setIndex] = useState(0);
  const [direction, setDirection] = useState(1);

  const dragX = useMotionValue(0);
  const dragTilt = useTransform(dragX, [-220, 0, 220], [-5, 0, 5]);
  const dragFade = useTransform(dragX, [-220, 0, 220], [0.5, 1, 0.5]);

  const go = useCallback(
    (delta: number) => {
      const next = index + delta;
      if (next < 0 || next > slides.length - 1) return;
      setDirection(delta);
      setIndex(next);
    },
    [index, slides.length]
  );

  const onDragEnd = useCallback(
    (_event: unknown, info: PanInfo) => {
      const { offset, velocity } = info;
      if (offset.x < -SWIPE_DISTANCE || velocity.x < -SWIPE_VELOCITY) go(1);
      else if (offset.x > SWIPE_DISTANCE || velocity.x > SWIPE_VELOCITY) go(-1);
    },
    [go]
  );

  if (!slides.length) return null;

  const safeIndex = Math.min(index, slides.length - 1);
  const current = slides[safeIndex];
  const transition = reduceMotion ? { duration: 0 } : SPRING;

  return (
    <div className="rounded-2xl border border-lyo-500/20 bg-gradient-to-b from-lyo-500/10 to-transparent p-4">
      <div className="flex items-center gap-2 mb-3">
        <Presentation className="w-4 h-4 text-lyo-300 shrink-0" aria-hidden="true" />
        <div className="text-sm font-semibold text-white/85 min-w-0 truncate">{title}</div>
        <div className="ml-auto shrink-0 text-[11px] text-white/45 tabular-nums">
          {safeIndex + 1} / {slides.length}
        </div>
      </div>

      <div className="flex gap-1 mb-3" aria-hidden="true">
        {slides.map((_, dot) => (
          <span key={dot} className="h-1 flex-1 rounded-full bg-white/10 overflow-hidden">
            <motion.span
              className="block h-full rounded-full bg-lyo-400"
              initial={false}
              animate={{ scaleX: dot <= safeIndex ? 1 : 0 }}
              style={{ transformOrigin: 'left' }}
              transition={reduceMotion ? { duration: 0 } : { duration: 0.35, ease: 'easeOut' }}
            />
          </span>
        ))}
      </div>

      <div className="relative h-[260px] select-none">
        <AnimatePresence initial={false} custom={direction} mode="popLayout">
          <motion.div
            key={safeIndex}
            custom={direction}
            variants={reduceMotion ? undefined : slide}
            initial="enter"
            animate="center"
            exit="exit"
            transition={transition}
            className="absolute inset-0"
          >
            <motion.article
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.2}
              onDragEnd={onDragEnd}
              whileDrag={{ cursor: 'grabbing' }}
              style={reduceMotion ? undefined : { x: dragX, rotate: dragTilt, opacity: dragFade }}
              className={cn(
                'w-full h-full rounded-2xl border border-white/10 bg-[#14122b]',
                'p-5 overflow-y-auto shadow-xl shadow-black/40',
                'cursor-grab active:cursor-grabbing touch-pan-y'
              )}
            >
              {current.title && (
                <h3 className="text-base font-semibold text-white/90 mb-2">{current.title}</h3>
              )}
              <div className="prose-invert prose-sm max-w-none text-white/80">
                <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
                  {normalizeLatexDelimiters(current.body)}
                </ReactMarkdown>
              </div>
            </motion.article>
          </motion.div>
        </AnimatePresence>
      </div>

      <div className="flex items-center gap-2 mt-3">
        <button
          type="button"
          onClick={() => go(-1)}
          disabled={safeIndex === 0}
          className="p-2 rounded-xl border border-white/10 text-white/70 transition-colors hover:bg-white/5 disabled:opacity-25 disabled:cursor-not-allowed"
          aria-label="Previous slide"
        >
          <ChevronLeft className="w-4 h-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          onClick={() => go(1)}
          disabled={safeIndex === slides.length - 1}
          className="p-2 rounded-xl border border-white/10 text-white/70 transition-colors hover:bg-white/5 disabled:opacity-25 disabled:cursor-not-allowed"
          aria-label="Next slide"
        >
          <ChevronRight className="w-4 h-4" aria-hidden="true" />
        </button>
        <span className="ml-auto text-[11px] text-white/40">Swipe to move through</span>
      </div>

      <span className="sr-only" aria-live="polite">
        Slide {safeIndex + 1} of {slides.length}. {current.title}
      </span>
    </div>
  );
}
