'use client';

import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { usePathname } from 'next/navigation';
import { useClassroomStore } from '@/stores/classroom-store';

const SPEAKER_TONE: Record<string, string> = {
  Teacher: 'text-accent-purple',
  Maya: 'text-accent-teal',
  Sam: 'text-accent-orange',
  Rio: 'text-accent-green',
  Zack: 'text-accent-gold',
  You: 'text-lyo-300',
};

type SpokenState = {
  generation: number;
  speaker: string;
  lineText: string;
  phrases: string[];
  outcome?: 'completed' | 'cancelled' | 'unavailable';
};

type SegmentDetail = {
  generation?: number;
  speaker?: string;
  text?: string;
  index?: number;
};

type LineEndDetail = {
  generation?: number;
  speaker?: string;
  outcome?: 'completed' | 'cancelled' | 'unavailable';
};

/**
 * One visual caption for the current classroom speaker. Speech is synthesized
 * and played in separate phrases, so an MP3's duration cannot honestly be
 * mapped to the words in the *entire* line. The store dispatches an event when
 * each phrase begins playing; we reveal that phrase at its real start instead
 * of pretending to have word timestamps that the audio provider never sent.
 *
 * The full, searchable lesson transcript remains in the Classroom notebook.
 * The page separately exposes the complete line to assistive technologies.
 */
export default function ClassroomCaptionSync() {
  const pathname = usePathname();
  const active = pathname === '/classroom' || pathname.startsWith('/classroom/');
  const caption = useClassroomStore((state) => state.caption);
  const voiceOn = useClassroomStore((state) => state.voiceOn);
  const [target, setTarget] = useState<HTMLElement | null>(null);
  const [spoken, setSpoken] = useState<SpokenState | null>(null);
  const captionRef = useRef(caption);
  const voiceOnRef = useRef(voiceOn);
  const activeRef = useRef(active);
  const latestGenerationRef = useRef(-1);
  const scrollerRef = useRef<HTMLDivElement | null>(null);
  const followingRef = useRef(true);
  const [hasMoreBelow, setHasMoreBelow] = useState(false);

  captionRef.current = caption;
  voiceOnRef.current = voiceOn;
  activeRef.current = active;

  // Each lesson turn, including a turn that repeats the same words, is a new
  // caption. Do not carry the last phrase into a new teacher response.
  useEffect(() => {
    setSpoken(null);
    followingRef.current = true;
    if (scrollerRef.current) scrollerRef.current.scrollTop = 0;
  }, [caption, voiceOn]);

  useEffect(() => {
    if (!active || typeof document === 'undefined') {
      setTarget(null);
      return;
    }
    const findTarget = () => {
      const mount = document.querySelector<HTMLElement>('[data-classroom-caption-target]');
      setTarget((current) => current === mount ? current : mount);
    };
    findTarget();
    const observer = new MutationObserver(findTarget);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [active]);

  useEffect(() => {
    if (!active || typeof window === 'undefined') return;

    const onSegment = (event: Event) => {
      const detail = (event as CustomEvent<SegmentDetail>).detail;
      const current = captionRef.current;
      if (!activeRef.current || !voiceOnRef.current || !current || current.speaker === 'You') return;
      if (typeof detail?.text !== 'string' || !detail.text.trim() || detail.speaker !== current.speaker) return;
      const generation = Number(detail.generation);
      if (!Number.isFinite(generation) || generation < latestGenerationRef.current) return;
      latestGenerationRef.current = generation;
      setSpoken((previous) => {
        const phrases = previous?.generation === generation && previous.speaker === detail.speaker
          && detail.index !== 0 ? previous.phrases : [];
        // A two-phrase roll-up keeps recent speech in the tiny caption area;
        // older words are still available via the full transcript.
        return {
          generation,
          speaker: detail.speaker!,
          lineText: current.text,
          phrases: [...phrases, detail.text!.trim()].slice(-2),
        };
      });
    };

    const onLineEnd = (event: Event) => {
      const detail = (event as CustomEvent<LineEndDetail>).detail;
      const generation = Number(detail?.generation);
      if (!Number.isFinite(generation) || generation < latestGenerationRef.current) return;
      if (!detail?.speaker || detail.speaker !== captionRef.current?.speaker) return;
      latestGenerationRef.current = generation;
      setSpoken((previous) => {
        const matching = previous?.generation === generation && previous.speaker === detail.speaker;
        return {
          generation,
          speaker: detail.speaker!,
          lineText: captionRef.current?.text ?? '',
          phrases: matching ? previous.phrases : [],
          outcome: detail.outcome ?? 'completed',
        };
      });
    };

    window.addEventListener('classroom:spoken-segment', onSegment);
    window.addEventListener('classroom:spoken-line-end', onLineEnd);
    return () => {
      window.removeEventListener('classroom:spoken-segment', onSegment);
      window.removeEventListener('classroom:spoken-line-end', onLineEnd);
    };
  }, [active]);

  const spokenCaption = spoken && spoken.speaker === caption?.speaker && spoken.lineText === caption?.text
    ? spoken : null;
  const visualText = !voiceOn || caption?.speaker === 'You' || spokenCaption?.outcome === 'unavailable'
    ? (caption?.text ?? '')
    : spokenCaption?.outcome === 'cancelled'
      ? ''
      : (spokenCaption?.phrases.join(' ') ?? '');

  // Voice-on captions follow the newly started speech phrase. Silent reading
  // opens at the beginning and allows scrolling through the complete line.
  useEffect(() => {
    const scroller = scrollerRef.current;
    if (!scroller) return;
    if (voiceOn && followingRef.current) scroller.scrollTop = scroller.scrollHeight;
    else if (!voiceOn) scroller.scrollTop = 0;
    setHasMoreBelow(scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight > 4);
  }, [visualText, target, voiceOn]);

  useEffect(() => {
    const scroller = scrollerRef.current;
    if (!scroller || typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(() => {
      if (voiceOn && followingRef.current) scroller.scrollTop = scroller.scrollHeight;
      setHasMoreBelow(scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight > 4);
    });
    observer.observe(scroller);
    return () => observer.disconnect();
  }, [target, voiceOn]);

  if (!active || !target || !caption) return null;

  return createPortal(
    <div data-lyo-synced-caption="true" aria-hidden="true" className="pointer-events-none absolute inset-0 flex min-w-0 items-center">
      <div className="relative flex w-full min-w-0 items-center">
        <div
          ref={scrollerRef}
          data-lyo-caption-scroller="true"
          onWheel={() => { followingRef.current = false; }}
          onTouchStart={() => { followingRef.current = false; }}
          onPointerDown={() => { followingRef.current = false; }}
          onScroll={(event) => {
            const scroller = event.currentTarget;
            const distance = scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight;
            if (distance <= 4) followingRef.current = true;
            setHasMoreBelow(distance > 4);
          }}
          className={`pointer-events-auto w-full overflow-y-auto overscroll-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden ${voiceOn
            ? 'max-h-10 text-[14px] leading-5 sm:max-h-[44px] sm:text-[15px] sm:leading-[22px]'
            : 'max-h-[72px] text-base leading-6 sm:max-h-[84px] sm:text-lg sm:leading-7'}`}
        >
          {visualText ? (
            <p className="text-white/95">
              <span className={`mr-1.5 font-bold ${SPEAKER_TONE[caption.speaker] ?? 'text-lyo-300'}`}>
                {caption.speaker}:
              </span>
              <span>“{visualText}”</span>
            </p>
          ) : (
            <p className="text-xs italic text-white/60" aria-hidden="true">
              {spokenCaption?.outcome === 'cancelled' ? 'Speech interrupted' : 'Preparing voice…'}
            </p>
          )}
        </div>
        {hasMoreBelow && <span className="pointer-events-none absolute inset-x-0 bottom-0 h-3.5 bg-gradient-to-t from-[#111936] via-[#111936]/70 to-transparent" />}
      </div>
    </div>,
    target,
  );
}
