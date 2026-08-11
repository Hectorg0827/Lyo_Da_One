'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { Check, X, TrendingUp } from 'lucide-react';
import { useChatStore } from '@/stores/chat-store';
import { cn, formatSkillLabel } from '@/lib/utils';

/** "linear_equations" -> "Linear equations" */
function formatSkill(skillId: string): string {
  const spaced = formatSkillLabel(skillId);
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
}

/**
 * Session-close recap: what the conversation just left behind showed the
 * learner nailed vs. what's still shaky. Appears once, on the new empty chat
 * that follows it — see chat-store's createConversation, which fetches this
 * only when the previous conversation had at least one graded check.
 */
export default function SessionRecap() {
  const summary = useChatStore((s) => s.sessionSummary);
  const dismiss = useChatStore((s) => s.dismissSessionSummary);

  return (
    <AnimatePresence>
      {summary && (
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -8 }}
          transition={{ duration: 0.25 }}
          className="w-full max-w-md mx-auto mb-4 rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4 text-left"
        >
          <div className="flex items-start justify-between gap-2 mb-3">
            <div className="flex items-center gap-1.5 text-sm font-medium text-white/90">
              <TrendingUp className="w-4 h-4 text-lyo-400" aria-hidden="true" />
              How your last session went
            </div>
            <button
              type="button"
              onClick={dismiss}
              aria-label="Dismiss session recap"
              className="text-white/40 hover:text-white/70 transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          {summary.nailed.length > 0 && (
            <div className="mb-2.5">
              <p className="text-xs font-medium text-emerald-300/90 mb-1.5">Nailed it</p>
              <ul className="flex flex-col gap-1">
                {summary.nailed.map((skill) => (
                  <li key={skill.skill_id} className="flex items-center gap-1.5 text-sm text-white/80">
                    <Check className="w-3.5 h-3.5 shrink-0 text-emerald-400" aria-hidden="true" />
                    {formatSkill(skill.skill_id)}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {summary.shaky.length > 0 && (
            <div>
              <p className="text-xs font-medium text-amber-300/90 mb-1.5">Still shaky</p>
              <ul className="flex flex-col gap-1.5">
                {summary.shaky.map((skill) => (
                  <li key={skill.skill_id} className="text-sm text-white/80">
                    <div className="flex items-center gap-1.5">
                      <span className={cn('w-1.5 h-1.5 rounded-full shrink-0 bg-amber-400')} />
                      {formatSkill(skill.skill_id)}
                    </div>
                    {skill.misconception && (
                      <p className="ml-3 text-xs text-white/50">{skill.misconception}</p>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
