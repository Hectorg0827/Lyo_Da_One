'use client';

import { motion, useReducedMotion } from 'framer-motion';
import MascotAvatar from '@/components/chat/MascotAvatar';

export default function SurfaceLoading({
  label = 'Opening Lyo…',
}: {
  label?: string;
}) {
  const reduceMotion = useReducedMotion() === true;

  return (
    <div className="flex h-full min-h-[320px] w-full items-center justify-center px-6">
      <div className="flex w-full max-w-sm flex-col items-center text-center">
        <motion.div
          initial={reduceMotion ? false : { opacity: 0, scale: 0.92, y: 8 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
          className="relative mb-5 flex h-20 w-20 items-center justify-center"
        >
          <motion.div
            className="absolute inset-0 rounded-full bg-gradient-to-br from-lyo-500/35 via-accent-purple/30 to-accent-pink/25 blur-xl"
            animate={reduceMotion ? undefined : { scale: [0.92, 1.08, 0.92], opacity: [0.45, 0.8, 0.45] }}
            transition={reduceMotion ? undefined : { duration: 2.2, repeat: Infinity, ease: 'easeInOut' }}
          />
          <MascotAvatar idle={!reduceMotion} size={62} />
        </motion.div>

        <p className="text-sm font-semibold text-white/80">{label}</p>
        <div className="mt-4 w-full space-y-2" aria-hidden="true">
          {[0.86, 0.68, 0.78].map((width, index) => (
            <motion.div
              key={width}
              className="mx-auto h-2 rounded-full bg-white/[0.07]"
              style={{ width: `${width * 100}%` }}
              animate={reduceMotion ? undefined : { opacity: [0.35, 0.9, 0.35] }}
              transition={reduceMotion ? undefined : { duration: 1.4, repeat: Infinity, delay: index * 0.12 }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
