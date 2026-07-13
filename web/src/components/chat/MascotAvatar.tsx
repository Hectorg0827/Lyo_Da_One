'use client';

import { useEffect, useState } from 'react';

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
 */
export default function MascotAvatar({
  thinking = false,
  size = 32,
}: {
  thinking?: boolean;
  size?: number;
}) {
  const [frame, setFrame] = useState(0);

  useEffect(() => {
    if (!thinking) return;
    const timer = setInterval(() => {
      setFrame((f) => (f + 1) % READING_FRAMES.length);
    }, 200);
    return () => clearInterval(timer);
  }, [thinking]);

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
