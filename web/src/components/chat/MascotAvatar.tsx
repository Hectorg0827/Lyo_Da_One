'use client';

import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';

const READING_FRAMES = [
  '/mascot/mascot_reading_1.png',
  '/mascot/mascot_reading_2.png',
  '/mascot/mascot_reading_3.png',
  '/mascot/mascot_reading_4.png',
];

/**
 * Lyo mascot avatar — shared across chat surfaces.
 * Mirrors iOS AnimatedReadingMascotView: cycles the reading frames every 0.2s
 * while `thinking`, otherwise shows the standing mascot.
 *
 * `idle` is for hero/branding placements (auth screens, splash) — a living
 * but non-distracting presence: gentle float + breathing scale, with an
 * occasional brief glance down at the book instead of a blink.
 */
export default function MascotAvatar({
  thinking = false,
  idle = false,
  size = 32,
}: {
  thinking?: boolean;
  idle?: boolean;
  size?: number;
}) {
  const [frame, setFrame] = useState(0);
  const [glancing, setGlancing] = useState(false);

  useEffect(() => {
    if (!thinking) return;
    const timer = setInterval(() => {
      setFrame((f) => (f + 1) % READING_FRAMES.length);
    }, 200);
    return () => clearInterval(timer);
  }, [thinking]);

  // Idle mode: an occasional, brief glance down — alive without being busy.
  const glanceTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (!idle) return;
    let cancelled = false;

    const scheduleGlance = () => {
      const delay = 4000 + Math.random() * 3500;
      glanceTimeout.current = setTimeout(() => {
        if (cancelled) return;
        setGlancing(true);
        setTimeout(() => {
          if (!cancelled) setGlancing(false);
        }, 380);
        scheduleGlance();
      }, delay);
    };
    scheduleGlance();

    return () => {
      cancelled = true;
      if (glanceTimeout.current) clearTimeout(glanceTimeout.current);
    };
  }, [idle]);

  if (thinking) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={READING_FRAMES[frame]}
        alt="Lyo is thinking"
        width={size}
        height={size}
        className="shrink-0 rounded-full object-contain ring-1 ring-white/10"
      />
    );
  }

  if (idle) {
    return (
      <motion.img
        // eslint-disable-next-line @next/next/no-img-element
        src={glancing ? '/mascot/mascot_reading_2.png' : '/mascot/mascot_standing.png'}
        alt="Lyo"
        width={size}
        height={size}
        className="shrink-0 object-contain select-none"
        animate={{
          y: [0, -6, 0],
          scale: [1, 1.015, 1],
        }}
        transition={{
          duration: 4.5,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/mascot/mascot_standing.png"
      alt="Lyo"
      width={size}
      height={size}
      className="shrink-0 object-contain"
    />
  );
}
