'use client';

import { useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useChatStore } from '@/stores/chat-store';
import MessageBubble from './MessageBubble';
import ChatInputBar from './ChatInputBar';
import SuggestionChips from './SuggestionChips';

// ─── LYO Animated Orb ────────────────────────────────────────────────────────
function LYOOrb() {
  return (
    <div className="relative w-24 h-24 mx-auto">
      {/* Outer glow rings */}
      <div className="absolute inset-0 rounded-full bg-gradient-to-br from-lyo-400 via-accent-purple to-accent-pink opacity-20 animate-pulse-slow blur-xl scale-150" />
      <div className="absolute inset-1 rounded-full bg-gradient-to-br from-lyo-400 via-accent-purple to-accent-pink opacity-30 animate-pulse blur-md scale-125" />
      {/* Core orb */}
      <div className="relative w-24 h-24 rounded-full bg-gradient-to-br from-lyo-500 via-accent-purple to-accent-pink shadow-2xl shadow-lyo-900/50 animate-float flex items-center justify-center">
        <span className="text-2xl font-bold text-white tracking-tighter">LYO</span>
      </div>
    </div>
  );
}

// ─── Thinking animation ───────────────────────────────────────────────────────
function ThinkingIndicator() {
  return (
    <div className="flex items-end gap-3 w-full">
      {/* Mini orb */}
      <div className="relative shrink-0 w-8 h-8">
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-lyo-500 via-accent-purple to-accent-pink animate-pulse-slow blur-sm opacity-60" />
        <div className="relative w-8 h-8 rounded-full bg-gradient-to-br from-lyo-500 via-accent-purple to-accent-pink flex items-center justify-center">
          <span className="text-[11px] font-bold text-white">LYO</span>
        </div>
      </div>
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
        <span className="ml-2 text-sm text-white/40">LYO is thinking…</span>
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

// ─── Empty state ─────────────────────────────────────────────────────────────
function EmptyState() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
      className="flex flex-col items-center justify-center flex-1 px-4 py-12 text-center"
    >
      <LYOOrb />
      <h1 className="mt-8 text-3xl font-bold text-white tracking-tight">
        Hi, I&apos;m LYO
      </h1>
      <p className="mt-2 text-white/50 max-w-sm text-base leading-relaxed">
        Your AI-powered learning companion. Ask me anything — I&apos;ll create
        personalized courses, quizzes, and flashcards just for you.
      </p>
      <SuggestionChips />
    </motion.div>
  );
}

// ─── Main ChatInterface ───────────────────────────────────────────────────────
export default function ChatInterface() {
  const { getActiveConversation, isGenerating, generationProgress } = useChatStore();
  const conversation = getActiveConversation();
  const messages = conversation?.messages ?? [];
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll when messages change or while generating
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
