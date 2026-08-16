'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
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

function wordsFor(text: string): string[] {
  return text.trim().split(/\s+/).filter(Boolean);
}

function wordWeight(word: string): number {
  // Speech is not uniform: longer words take longer and punctuation creates
  // a natural pause. Weighting the known transcript this way keeps the visual
  // word reveal much closer to real neural-audio timing than a flat timer.
  const spokenLength = word.replace(/[^\p{L}\p{N}]/gu, '').length;
  let weight = Math.max(0.8, Math.min(2.4, spokenLength / 4.5));
  if (/[,;:]$/.test(word)) weight += 0.65;
  if (/[.!?]$/.test(word)) weight += 1.05;
  return weight;
}

function wordStartTimes(text: string, durationSeconds: number): number[] {
  const words = wordsFor(text);
  if (!words.length) return [];
  const weights = words.map(wordWeight);
  const totalWeight = Math.max(weights.reduce((sum, weight) => sum + weight, 0), 1);
  let elapsedWeight = 0;
  return weights.map((weight) => {
    const start = (elapsedWeight / totalWeight) * durationSeconds;
    elapsedWeight += weight;
    return start;
  });
}

function revealCountAtTime(starts: number[], currentTime: number): number {
  let count = 0;
  while (count < starts.length && currentTime + 0.025 >= starts[count]) count += 1;
  return count;
}

function estimatedSpeechSeconds(text: string, rate: number): number {
  const words = wordsFor(text);
  const weighted = words.reduce((sum, word) => sum + wordWeight(word), 0);
  // ~205 spoken words/minute at 1x, adjusted by the classroom speed setting.
  return Math.max(0.8, (weighted * 60) / (205 * Math.max(rate, 0.5)));
}

function countAtCharIndex(text: string, charIndex: number): number {
  if (!text.trim()) return 0;
  const index = Math.max(0, Math.min(charIndex + 1, text.length));
  return Math.max(1, wordsFor(text.slice(0, index)).length);
}

function isCaptionTarget(element: Element): element is HTMLElement {
  const parent = element.parentElement;
  return Boolean(
    parent
      && parent.classList.contains('relative')
      && parent.classList.contains('overflow-hidden'),
  );
}

/**
 * Synchronizes the classroom's visible caption to the audio that is actually
 * playing, rather than to when the server text arrived.
 *
 * The classroom store intentionally owns TTS playback. This bridge observes
 * that playback at the browser media boundary so it also covers the shared
 * neural MP3 path without duplicating audio requests. Native speech synthesis
 * is handled with real `boundary` events when the browser provides them.
 *
 * The original caption remains in the DOM for its aria-live/screen-reader
 * behavior. Only its visual ticker is replaced by this synchronized layer.
 */
export default function ClassroomCaptionSync() {
  const pathname = usePathname();
  const active = pathname === '/classroom' || pathname.startsWith('/classroom/');
  const caption = useClassroomStore((state) => state.caption);
  const voiceOn = useClassroomStore((state) => state.voiceOn);
  const speechRate = useClassroomStore((state) => state.speechRate);

  const [target, setTarget] = useState<HTMLElement | null>(null);
  const [revealedCount, setRevealedCount] = useState(0);

  const captionRef = useRef(caption);
  const voiceOnRef = useRef(voiceOn);
  const speechRateRef = useRef(speechRate);
  const activeRef = useRef(active);
  const syncGenerationRef = useRef(0);
  const audioFrameRef = useRef<number | null>(null);
  const synthFrameRef = useRef<number | null>(null);

  captionRef.current = caption;
  voiceOnRef.current = voiceOn;
  speechRateRef.current = speechRate;
  activeRef.current = active;

  const words = useMemo(() => wordsFor(caption?.text ?? ''), [caption?.text]);

  const cancelFrames = () => {
    if (audioFrameRef.current !== null) {
      cancelAnimationFrame(audioFrameRef.current);
      audioFrameRef.current = null;
    }
    if (synthFrameRef.current !== null) {
      cancelAnimationFrame(synthFrameRef.current);
      synthFrameRef.current = null;
    }
  };

  // A new line invalidates every callback from the previous spoken line.
  // With voice enabled, nothing is shown until audio actually starts.
  useEffect(() => {
    syncGenerationRef.current += 1;
    cancelFrames();
    if (!caption) {
      setRevealedCount(0);
      return;
    }
    if (!voiceOn || caption.speaker === 'You') {
      setRevealedCount(wordsFor(caption.text).length);
      return;
    }
    setRevealedCount(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [caption?.speaker, caption?.text, voiceOn]);

  // Find the existing visual caption band. The sr-only status element is a
  // semantic anchor and is substantially more stable than styling classes.
  useEffect(() => {
    if (!active || typeof document === 'undefined') {
      setTarget(null);
      return;
    }

    const findTarget = () => {
      const statuses = Array.from(document.querySelectorAll(
        'span[role="status"][aria-live="polite"][aria-atomic="true"]',
      ));
      const status = statuses.find(isCaptionTarget);
      const nextTarget = status?.parentElement ?? null;
      setTarget((current) => current === nextTarget ? current : nextTarget);
    };

    findTarget();
    const observer = new MutationObserver(findTarget);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [active]);

  // Hide only the original visual ticker; its adjacent sr-only full sentence
  // stays untouched for assistive technology. The portal below replaces it.
  useEffect(() => {
    if (!target) return;
    const originalTicker = Array.from(target.children).find(
      (child) => child instanceof HTMLElement && !child.hasAttribute('data-lyo-synced-caption'),
    ) as HTMLElement | undefined;
    if (!originalTicker) return;
    const previousVisibility = originalTicker.style.visibility;
    originalTicker.style.visibility = 'hidden';
    return () => {
      originalTicker.style.visibility = previousVisibility;
    };
  }, [target]);

  // Shared neural voice path: classroom-store plays a generated MP3 through a
  // detached HTMLAudioElement. Track that media element's real currentTime and
  // duration so network-generation latency can never make text run ahead of
  // the voice again.
  useEffect(() => {
    if (!active || typeof window === 'undefined') return;

    const mediaPrototype = HTMLMediaElement.prototype;
    const originalPlay = mediaPrototype.play;

    mediaPrototype.play = function patchedPlay(this: HTMLMediaElement): Promise<void> {
      const currentCaption = captionRef.current;
      const source = this.currentSrc || this.src || '';
      const shouldSync = activeRef.current
        && voiceOnRef.current
        && Boolean(currentCaption?.text)
        && currentCaption?.speaker !== 'You'
        && source.startsWith('blob:')
        && this instanceof HTMLAudioElement;

      if (shouldSync && currentCaption) {
        const text = currentCaption.text;
        const generation = syncGenerationRef.current;
        const totalWords = wordsFor(text).length;
        const media = this;
        let starts: number[] = [];
        let lastDuration = -1;

        const finish = () => {
          if (generation !== syncGenerationRef.current) return;
          if (audioFrameRef.current !== null) {
            cancelAnimationFrame(audioFrameRef.current);
            audioFrameRef.current = null;
          }
          setRevealedCount(totalWords);
        };

        const tick = () => {
          if (generation !== syncGenerationRef.current || captionRef.current?.text !== text) return;
          const duration = Number.isFinite(media.duration) && media.duration > 0
            ? media.duration
            : estimatedSpeechSeconds(text, speechRateRef.current);
          if (Math.abs(duration - lastDuration) > 0.02) {
            starts = wordStartTimes(text, duration);
            lastDuration = duration;
          }
          setRevealedCount(revealCountAtTime(starts, media.currentTime));
          if (!media.ended && !media.paused) {
            audioFrameRef.current = requestAnimationFrame(tick);
          }
        };

        const start = () => {
          if (generation !== syncGenerationRef.current || captionRef.current?.text !== text) return;
          if (audioFrameRef.current !== null) cancelAnimationFrame(audioFrameRef.current);
          setRevealedCount(totalWords > 0 ? 1 : 0);
          audioFrameRef.current = requestAnimationFrame(tick);
        };

        media.addEventListener('playing', start, { once: true });
        media.addEventListener('ended', finish, { once: true });
        media.addEventListener('error', finish, { once: true });
      }

      return originalPlay.call(this);
    };

    return () => {
      mediaPrototype.play = originalPlay;
      if (audioFrameRef.current !== null) {
        cancelAnimationFrame(audioFrameRef.current);
        audioFrameRef.current = null;
      }
    };
  }, [active]);

  // Device-voice emergency fallback: use browser word-boundary events for
  // true word synchronization. Engines that omit boundary events (notably
  // some Samsung/Android combinations) fall back to a paced reveal that starts
  // on the utterance's *actual* start event, never when text first arrives.
  useEffect(() => {
    if (!active || typeof window === 'undefined' || !('speechSynthesis' in window)) return;

    const synth = window.speechSynthesis;
    const originalSpeak = synth.speak;

    synth.speak = ((utterance: SpeechSynthesisUtterance) => {
      const currentCaption = captionRef.current;
      const shouldSync = activeRef.current
        && voiceOnRef.current
        && Boolean(currentCaption?.text)
        && currentCaption?.speaker !== 'You'
        && currentCaption?.text.trim() === utterance.text.trim();

      if (shouldSync && currentCaption) {
        const text = currentCaption.text;
        const totalWords = wordsFor(text).length;
        const generation = syncGenerationRef.current;
        let boundarySeen = false;
        let fallbackStarted = false;
        let startAt = 0;

        const finish = () => {
          if (generation !== syncGenerationRef.current) return;
          if (synthFrameRef.current !== null) {
            cancelAnimationFrame(synthFrameRef.current);
            synthFrameRef.current = null;
          }
          setRevealedCount(totalWords);
        };

        const fallbackTick = () => {
          if (generation !== syncGenerationRef.current || boundarySeen || captionRef.current?.text !== text) return;
          const elapsed = Math.max(0, (performance.now() - startAt) / 1000);
          const duration = estimatedSpeechSeconds(text, speechRateRef.current);
          const starts = wordStartTimes(text, duration);
          setRevealedCount(revealCountAtTime(starts, elapsed));
          if (elapsed < duration) synthFrameRef.current = requestAnimationFrame(fallbackTick);
          else finish();
        };

        utterance.addEventListener('start', () => {
          if (generation !== syncGenerationRef.current) return;
          startAt = performance.now();
          setRevealedCount(totalWords > 0 ? 1 : 0);
          window.setTimeout(() => {
            if (!boundarySeen && !fallbackStarted && generation === syncGenerationRef.current) {
              fallbackStarted = true;
              synthFrameRef.current = requestAnimationFrame(fallbackTick);
            }
          }, 220);
        }, { once: true });

        utterance.addEventListener('boundary', (event: Event) => {
          const boundary = event as SpeechSynthesisEvent;
          if (generation !== syncGenerationRef.current) return;
          boundarySeen = true;
          if (synthFrameRef.current !== null) {
            cancelAnimationFrame(synthFrameRef.current);
            synthFrameRef.current = null;
          }
          setRevealedCount(Math.min(totalWords, countAtCharIndex(text, boundary.charIndex)));
        });
        utterance.addEventListener('end', finish, { once: true });
        utterance.addEventListener('error', finish, { once: true });
      }

      return originalSpeak.call(synth, utterance);
    }) as typeof synth.speak;

    return () => {
      synth.speak = originalSpeak;
      if (synthFrameRef.current !== null) {
        cancelAnimationFrame(synthFrameRef.current);
        synthFrameRef.current = null;
      }
    };
  }, [active]);

  useEffect(() => () => cancelFrames(), []);

  if (!active || !target) return null;

  const visibleWords = words.slice(0, Math.min(revealedCount, words.length));
  return createPortal(
    <div
      data-lyo-synced-caption="true"
      aria-hidden="true"
      className="absolute inset-y-0 right-0 flex items-center gap-1.5 whitespace-nowrap pointer-events-none"
    >
      {caption && (
        <>
          <span className={`font-bold shrink-0 text-[12.5px] ${SPEAKER_TONE[caption.speaker] ?? 'text-lyo-300'}`}>
            {caption.speaker}:
          </span>
          {visibleWords.map((word, index) => (
            <span
              key={`${caption.speaker}-${index}`}
              className="text-[14px] leading-none text-white/90"
            >
              {word}
            </span>
          ))}
        </>
      )}
    </div>,
    target,
  );
}
