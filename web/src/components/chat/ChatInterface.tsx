'use client';

import { useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useChatStore } from '@/stores/chat-store';
import { useAuthStore } from '@/stores/auth-store';
import MessageBubble from './MessageBubble';
import ChatInputBar from './ChatInputBar';
import SuggestionChips from './SuggestionChips';
import MascotAvatar from './MascotAvatar';

// ─── LYO Mascot hero (matches iOS LyoOverlayView avatarLayer) ────────────────
function LYOOrb() {
  return (
    <div className="relative flex items-center justify-center mt-10">
      {/* Orange radial glow behind the mascot */}
      <div className="absolute w-[280px] h-[280px] rounded-full mascot-glow pointer-events-none" />
      <div className="relative animate-mascot-float flex items-center justify-center">
        <MascotAvatar size={200} />
      </div>
    </div>
  );
}

// ─── Thinking animation (matches iOS reading mascot) ─────────────────────────
function ThinkingIndicator() {
  return (
    <div className="flex items-end gap-3 w-full">
      <MascotAvatar thinking size={32} />
      <div className="px-4 py-3 rounded-2xl rounded-bl-sm bg-white/5 border border-white/10 backdrop-blur-sm flex items-center gap-1.5">
        {[0, 1, 2].map((i) => (
          <motion.span
            key={i}
            className="w-1.5 h-1.5 rounded-full bg-lyo-400"
            animate={{ y: [0, -5, 0], opacity: [0.4, 1, 0.4] }}
            transition={{
              duration: 0.9,
              repeat: Infinity,
              delay: i * 0.18,
              ease: 'easeInOut',
            }}
          />
        ))}
        <span className="ml-2 text-sm text-white/40">Lyo is thinking…</span>
      </div>
    </div>
  );
}

// ─── Generation progress bar ──────────────────────────────────────────────────
function GenerationProgressBar({ progress }: { progress: number }) {
  return (
    <div className="px-4 py-2">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs text-white/40">Generating course…</span>
        <span className="text-xs text-lyo-400 font-medium">{progress}%</span>
      </div>
      <div className="h-1 w-full rounded-full bg-white/10 overflow-hidden">
        <motion.div
          className="h-full rounded-full bg-gradient-to-r from-lyo-500 via-accent-purple to-accent-pink"
          initial={{ width: 0 }}
          animate={{ width: `${progress}%` }}
          transition={{ duration: 0.4, ease: 'easeOut' }}
        />
      </div>
    </div>
  );
}

// ─── Empty state (matches iOS LyoOverlayView greeting) ───────────────────────
function EmptyState() {
  const user = useAuthStore((s) => s.user);
  const firstName = user?.displayName?.trim().split(' ')[0] || 'there';

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
      className="flex flex-col items-center justify-center h-full min-h-full px-4 py-8 text-center"
    >
      <h1 className="font-rounded text-[32px] font-bold leading-tight">
        <span className="hello-gradient-text">Hello, {firstName}!</span>
      </h1>
      <p className="mt-2 text-lg font-medium text-white/80">
        Ready to embark on a learning journey?
      </p>
      <LYOOrb />
      <div className="flex-1 min-h-6" />
      <SuggestionChips />
    </motion.div>
  );
}

// ─── Main ChatInterface ───────────────────────────────────────────────────────
export default function ChatInterface() {
  const { getActiveConversation, isGenerating, generationProgress, hydrate } = useChatStore();
  const conversation = getActiveConversation();
  const messages = conversation?.messages ?? [];
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll when messages change or while generating
  useEffect(() => {
    hydrate();
  }, [hydrate]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length, isGenerating]);

  return (
    <div className="flex flex-col h-full w-full overflow-hidden bg-transparent">
      {/* Message list or empty state */}
      <div className="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-white/10 scrollbar-track-transparent">
        {messages.length === 0 ? (
          <EmptyState />
        ) : (
          <div className="flex flex-col gap-6 px-4 py-6 max-w-3xl mx-auto w-full">
            <AnimatePresence initial={false}>
              {messages.map((msg) => (
                <MessageBubble key={msg.id} message={msg} />
              ))}
            </AnimatePresence>

            {/* Thinking indicator */}
            <AnimatePresence>
              {isGenerating && (
                <motion.div
                  key="thinking"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: 8 }}
                  transition={{ duration: 0.25 }}
                >
                  <ThinkingIndicator />
                </motion.div>
              )}
            </AnimatePresence>

            <div ref={bottomRef} />
          </div>
        )}
      </div>

      {/* Progress bar */}
      <AnimatePresence>
        {isGenerating && generationProgress > 0 && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="shrink-0 border-t border-white/5"
          >
            <GenerationProgressBar progress={generationProgress} />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Input bar */}
      <div className="shrink-0">
        <ChatInputBar />
      </div>
    </div>
  );
}
