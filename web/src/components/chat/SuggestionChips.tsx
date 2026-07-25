'use client';

import { motion } from 'framer-motion';
import { Sparkles, PlusCircle, HelpCircle, BookOpen } from 'lucide-react';
import { useChatStore } from '@/stores/chat-store';

// Mirrors iOS LyoAIViewModel.fallbackGreetingChips + LyoSuggestionChip style
// (white/10 fill, radius 20, white/20 hairline).
const CHIPS = [
  { icon: Sparkles, label: 'Teach me something new' },
  { icon: PlusCircle, label: 'Create a course for me' },
  { icon: HelpCircle, label: 'Quiz me on a topic' },
  { icon: BookOpen, label: 'Help me study for an exam' },
];

export default function SuggestionChips() {
  const { sendMessage } = useChatStore();

  return (
    <div className="flex w-full gap-2 overflow-x-auto no-scrollbar px-4 pb-1 justify-start sm:justify-center">
      {CHIPS.map(({ icon: Icon, label }, i) => (
        <motion.button
          key={label}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 + i * 0.07, duration: 0.35, ease: 'easeOut' }}
          onClick={() => sendMessage(label)}
          className="flex items-center gap-1.5 shrink-0 px-4 py-2 rounded-[20px] text-sm font-medium
            bg-white/10 border border-white/20 text-white
            hover:bg-white/15 active:scale-95 transition-all duration-200 cursor-pointer"
        >
          <Icon className="w-4 h-4 opacity-80" />
          {label}
        </motion.button>
      ))}
    </div>
  );
}
