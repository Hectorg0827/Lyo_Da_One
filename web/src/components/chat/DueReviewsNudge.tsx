'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { RotateCcw } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useChatStore } from '@/stores/chat-store';
import { reviewEntryHref } from '@/lib/entry-contract.mjs';
import { formatSkillLabel as formatSkill } from '@/lib/utils';

/**
 * The return half of the spaced-repetition loop: skills a past check flagged
 * as shaky, whose SM-2 schedule now says they're due for another look.
 * Tapping one enters the same canonical Classroom review flow as Home. The
 * exact concept id travels with it; the server generates a fresh open
 * retrieval check and only a schedule-validated concept can earn retention.
 */
export default function DueReviewsNudge() {
  const router = useRouter();
  const dueReviews = useChatStore((s) => s.dueReviews);
  const dismissDueReview = useChatStore((s) => s.dismissDueReview);

  if (dueReviews.length === 0) return null;

  return (
    <div className="flex w-full gap-2 overflow-x-auto no-scrollbar px-4 pb-1 justify-start sm:justify-center">
      <AnimatePresence>
        {dueReviews.map((item, i) => (
          <motion.button
            key={item.skill_id}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9 }}
            transition={{ delay: 0.1 + i * 0.06, duration: 0.3, ease: 'easeOut' }}
            onClick={() => {
              const label = item.skill_name?.trim() || formatSkill(item.skill_id);
              const href = reviewEntryHref(label, item.skill_id);
              if (!href) return;
              dismissDueReview(item.skill_id);
              router.push(href);
            }}
            className="flex items-center gap-1.5 shrink-0 px-4 py-2 rounded-[20px] text-sm font-medium
              bg-amber-500/10 border border-amber-400/30 text-amber-100
              hover:bg-amber-500/15 active:scale-95 transition-all duration-200 cursor-pointer"
            title={item.last_misconception ?? undefined}
          >
            <RotateCcw className="w-3.5 h-3.5 opacity-80" aria-hidden="true" />
            Review: {item.skill_name?.trim() || formatSkill(item.skill_id)}
            {item.days_overdue > 0 && (
              <span className="text-amber-100/60 text-xs">· {item.days_overdue}d</span>
            )}
          </motion.button>
        ))}
      </AnimatePresence>
    </div>
  );
}
