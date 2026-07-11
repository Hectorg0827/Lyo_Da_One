'use client';

import { useRef, useState, useCallback, KeyboardEvent } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowUp, Paperclip, Mic } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';

const MAX_CHARS = 4000;
const MAX_ROWS = 6;
const LINE_HEIGHT = 24; // px per row

export default function ChatInputBar() {
  const { sendMessage, isGenerating } = useChatStore();
  const [value, setValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const adjustHeight = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    const maxHeight = MAX_ROWS * LINE_HEIGHT + 16; // 16px = padding
    el.style.height = `${Math.min(el.scrollHeight, maxHeight)}px`;
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    if (e.target.value.length > MAX_CHARS) return;
    setValue(e.target.value);
    adjustHeight();
  };

  const handleSubmit = async () => {
    const trimmed = value.trim();
    if (!trimmed || isGenerating) return;
    setValue('');
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
    await sendMessage(trimmed);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const charCount = value.length;
  const showCount = charCount > MAX_CHARS * 0.75;
  const canSend = value.trim().length > 0 && !isGenerating;

  return (
    <div className="relative px-3 py-3 md:px-6 md:py-4 border-t border-white/5 bg-black/20 backdrop-blur-md">
      <div
        className={cn(
          'flex items-end gap-2 rounded-2xl border px-3 py-2.5 transition-all duration-200',
          'bg-white/5 backdrop-blur-sm',
          value.length > 0
            ? 'border-lyo-500/40 shadow-[0_0_0_1px_rgba(92,124,250,0.1)]'
            : 'border-white/10'
        )}
      >
        {/* Attachment */}
        <button
          type="button"
          className="p-1.5 rounded-lg text-white/30 hover:text-white/70 hover:bg-white/10 transition-all duration-200 shrink-0 mb-0.5"
          title="Attach file"
        >
          <Paperclip className="w-4 h-4" />
        </button>

        {/* Textarea */}
        <textarea
          ref={textareaRef}
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          placeholder={isGenerating ? 'LYO is thinking…' : 'Ask LYO anything…'}
          disabled={isGenerating}
          rows={1}
          className={cn(
            'flex-1 resize-none bg-transparent text-sm text-white placeholder-white/30',
            'focus:outline-none leading-6 py-0.5 max-h-36 scrollbar-thin scrollbar-thumb-white/10',
            'disabled:opacity-50 disabled:cursor-not-allowed'
          )}
          style={{ lineHeight: `${LINE_HEIGHT}px` }}
        />

        {/* Right controls */}
        <div className="flex items-end gap-1.5 shrink-0 mb-0.5">
          {/* Character count */}
          <AnimatePresence>
            {showCount && (
              <motion.span
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                className={cn(
                  'text-[11px] font-mono self-end mb-0.5',
                  charCount > MAX_CHARS * 0.95 ? 'text-red-400' : 'text-white/30'
                )}
              >
                {MAX_CHARS - charCount}
              </motion.span>
            )}
          </AnimatePresence>

          {/* Voice */}
          <button
            type="button"
            className="p-1.5 rounded-lg text-white/30 hover:text-white/70 hover:bg-white/10 transition-all duration-200"
            title="Voice input"
          >
            <Mic className="w-4 h-4" />
          </button>

          {/* Send */}
          <motion.button
            type="button"
            onClick={handleSubmit}
            disabled={!canSend}
            whileTap={canSend ? { scale: 0.9 } : {}}
            className={cn(
              'p-2 rounded-xl transition-all duration-200',
              canSend
                ? 'bg-gradient-to-br from-lyo-500 to-accent-purple text-white shadow-lg shadow-lyo-900/40 hover:opacity-90'
                : 'bg-white/5 text-white/20 cursor-not-allowed'
            )}
            title="Send message"
          >
            <ArrowUp className="w-4 h-4" />
          </motion.button>
        </div>
      </div>

      {/* Hint */}
      <p className="text-center text-[11px] text-white/20 mt-2">
        LYO can make mistakes. Press{' '}
        <kbd className="px-1 py-0.5 rounded bg-white/10 font-mono text-[10px]">Enter</kbd> to send,{' '}
        <kbd className="px-1 py-0.5 rounded bg-white/10 font-mono text-[10px]">Shift+Enter</kbd> for newline.
      </p>
    </div>
  );
}
