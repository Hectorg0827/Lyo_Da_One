'use client';

import { motion } from 'framer-motion';
import { useChatStore } from '@/stores/chat-store';

const CHIPS = [
  'Teach me Python basics',
  'Create a course on Machine Learning',
  'Explain quantum computing',
  'Help me prepare for a math exam',
  'What should I learn next?',
  'Summarize the history of AI',
];

export default function SuggestionChips() {
  const { sendMessage } = useChatStore();

  return (
    <div className="flex flex-wrap justify-center gap-2 mt-6 max-w-2xl mx-auto px-4">
      {CHIPS.map((chip, i) => (
        <motion.button
          key={chip}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 + i * 0.07, duration: 0.35, ease: 'easeOut' }}
          onClick={() => sendMessage(chip)}
          className="px-4 py-2 rounded-full text-sm font-medium
            bg-white/5 border border-white/10 text-white/70
            hover:bg-lyo-600/20 hover:border-lyo-400/40 hover:text-white
            active:scale-95 transition-all duration-200 cursor-pointer"
        >
          {chip}
        </motion.button>
      ))}
    </div>
  );
}
