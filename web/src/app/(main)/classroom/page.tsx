'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft, Send, HelpCircle, Zap, CheckCircle2, XCircle,
  GraduationCap, PenLine, Sparkles,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  useClassroomStore, type FeedItem, type QuizOption,
} from '@/stores/classroom-store';

// ─── Cast styling ─────────────────────────────────────────────────────────────

const SPEAKER_STYLE: Record<string, { color: string; badge: string }> = {
  Teacher: { color: 'text-accent-purple', badge: 'bg-accent-purple/15 border-accent-purple/30' },
  Maya:    { color: 'text-accent-teal',   badge: 'bg-accent-teal/15 border-accent-teal/30' },
  Sam:     { color: 'text-accent-orange', badge: 'bg-accent-orange/15 border-accent-orange/30' },
  Rio:     { color: 'text-accent-green',  badge: 'bg-accent-green/15 border-accent-green/30' },
  Zack:    { color: 'text-accent-gold',   badge: 'bg-accent-gold/15 border-accent-gold/30' },
  Lyo:     { color: 'text-lyo-300',       badge: 'bg-lyo-500/15 border-lyo-500/30' },
  You:     { color: 'text-white',         badge: 'bg-lyo-500/25 border-lyo-400/40' },
};

const speakerStyle = (name?: string) =>
  SPEAKER_STYLE[name ?? 'Teacher'] ?? SPEAKER_STYLE.Teacher;

// Mascot reacts to the director's lyo_state turns.
const LYO_STATE_IMG: Record<string, string> = {
  reading: '/mascot/mascot_reading_1.png',
  thinking: '/mascot/mascot_reading_3.png',
  listening: '/mascot/mascot_standing.png',
  curious: '/mascot/mascot_reading_2.png',
  surprised: '/mascot/mascot_reading_4.png',
  celebrating: '/mascot/mascot_standing.png',
  confused: '/mascot/mascot_reading_3.png',
  shy: '/mascot/mascot_reading_1.png',
  sleeping: '/mascot/mascot_reading_1.png',
};

// ─── Page ────────────────────────────────────────────────────────────────────

export default function ClassroomPage() {
  return (
    <Suspense fallback={<div className="h-full" />}>
      <ClassroomInner />
    </Suspense>
  );
}

function ClassroomInner() {
  const router = useRouter();
  const params = useSearchParams();
  const topic = params.get('topic') || 'General Learning';

  const {
    status, feed, lyoState, boardLines, waitingForScene, canContinue, error,
    connect, disconnect, answerPrompt, answerQuiz, askQuestion, signal, continueLesson,
  } = useClassroomStore();

  const [question, setQuestion] = useState('');
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    connect(topic);
    return () => disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [feed.length, waitingForScene]);

  const submitQuestion = () => {
    if (!question.trim()) return;
    askQuestion(question);
    setQuestion('');
  };

  return (
    <div className="flex flex-col h-[calc(100dvh-8rem)] md:h-[calc(100dvh-4rem)] max-w-3xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-white/5">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-lg text-white/50 hover:text-white hover:bg-white/5 transition-colors"
          title="Leave classroom"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <GraduationCap className="w-5 h-5 text-accent-purple" />
        <div className="min-w-0">
          <h1 className="text-sm font-bold text-white truncate">{topic}</h1>
          <p className="text-[11px] text-white/50">
            {status === 'live' ? (
              <span className="text-green-400">● live classroom</span>
            ) : status === 'connecting' ? 'connecting…' : status}
          </p>
        </div>
        <div className="ml-auto flex items-center gap-2">
          {/* Lyo — reacts to the lesson */}
          <motion.img
            key={lyoState}
            src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
            alt={`Lyo is ${lyoState}`}
            className="w-10 h-10 object-contain"
            initial={{ scale: 0.7, rotate: -6 }}
            animate={lyoState === 'celebrating'
              ? { scale: [1, 1.25, 1], rotate: [0, 8, -8, 0] }
              : { scale: 1, rotate: 0 }}
            transition={{ duration: 0.5 }}
          />
        </div>
      </div>

      {/* Whiteboard */}
      <AnimatePresence>
        {boardLines.length > 0 && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="border-b border-white/5 bg-white/[0.03] overflow-hidden"
          >
            <div className="px-4 py-3 flex items-start gap-2">
              <PenLine className="w-3.5 h-3.5 text-accent-gold mt-1 shrink-0" />
              <pre className="text-[13px] leading-relaxed text-accent-gold/90 font-mono whitespace-pre-wrap overflow-x-auto flex-1">
                {boardLines[boardLines.length - 1]}
              </pre>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Feed */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {feed.map((item) => (
          <FeedRow
            key={item.id}
            item={item}
            onPromptAnswer={(opt) => answerPrompt(item.id, opt)}
            onQuizAnswer={(opt) => answerQuiz(item.id, opt)}
          />
        ))}

        {waitingForScene && (
          <div className="flex items-center gap-2 text-white/40 text-sm py-2">
            <motion.span
              animate={{ opacity: [0.3, 1, 0.3] }}
              transition={{ duration: 1.4, repeat: Infinity }}
            >
              <Sparkles className="w-4 h-4" />
            </motion.span>
            the classroom is thinking…
          </div>
        )}

        {status === 'error' && (
          <div className="text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
            {error ?? 'Something went wrong.'}{' '}
            <button className="underline" onClick={() => connect(topic)}>Retry</button>
          </div>
        )}

        {canContinue && (
          <button
            onClick={continueLesson}
            className="w-full py-3 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-lyo-600 to-accent-purple hover:opacity-90 active:scale-[0.99] transition-all"
          >
            Continue →
          </button>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Adaptive controls */}
      <div className="border-t border-white/5 px-4 py-3 space-y-2">
        <div className="flex gap-2">
          <button
            onClick={() => signal('confused')}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors"
          >
            <HelpCircle className="w-3.5 h-3.5" /> I&apos;m confused
          </button>
          <button
            onClick={() => signal('too_easy')}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors"
          >
            <Zap className="w-3.5 h-3.5" /> Too easy
          </button>
        </div>
        <div className="flex gap-2">
          <input
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && submitQuestion()}
            placeholder="Ask the classroom anything…"
            className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-lyo-500/50"
          />
          <button
            onClick={submitQuestion}
            disabled={!question.trim()}
            className="px-4 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple text-white disabled:opacity-40 transition-opacity"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Feed rows ───────────────────────────────────────────────────────────────

function FeedRow({
  item, onPromptAnswer, onQuizAnswer,
}: {
  item: FeedItem;
  onPromptAnswer: (option: string) => void;
  onQuizAnswer: (option: QuizOption) => void;
}) {
  switch (item.kind) {
    case 'speech': {
      const style = speakerStyle(item.speaker);
      const isYou = item.speaker === 'You';
      const isLyo = item.speaker === 'Lyo';
      return (
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          className={cn('flex flex-col gap-1', isYou && 'items-end')}
        >
          <div className="flex items-center gap-1.5">
            {isLyo && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src="/mascot/mascot_standing.png" alt="Lyo" className="w-4 h-4 object-contain" />
            )}
            <span className={cn('text-[11px] font-bold', style.color)}>{item.speaker}</span>
          </div>
          <div className={cn(
            'max-w-[85%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed text-white/90 border',
            style.badge, isYou ? 'rounded-br-sm' : 'rounded-bl-sm',
          )}>
            {item.text}
          </div>
        </motion.div>
      );
    }

    case 'prompt': {
      const style = speakerStyle(item.speaker);
      return (
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="space-y-2">
          <span className={cn('text-[11px] font-bold', style.color)}>{item.speaker} asks you</span>
          <div className={cn('max-w-[85%] px-4 py-2.5 rounded-2xl rounded-bl-sm text-sm text-white/90 border', style.badge)}>
            {item.text}
          </div>
          <div className="flex flex-wrap gap-2 pl-1">
            {(item.options ?? []).map((opt) => (
              <button
                key={opt}
                disabled={!!item.answered}
                onClick={() => onPromptAnswer(opt)}
                className={cn(
                  'px-4 py-2 rounded-full text-sm font-semibold border transition-all',
                  item.answered === opt
                    ? 'bg-lyo-500/30 border-lyo-400/60 text-white'
                    : item.answered
                      ? 'bg-white/5 border-white/10 text-white/30'
                      : 'bg-white/5 border-white/15 text-white/80 hover:bg-lyo-500/20 hover:border-lyo-500/40',
                )}
              >
                {opt}
              </button>
            ))}
          </div>
        </motion.div>
      );
    }

    case 'quiz': {
      const quiz = item.quiz;
      if (!quiz) return null;
      return (
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-2xl border border-lyo-500/25 bg-lyo-500/[0.07] p-4 space-y-3"
        >
          <p className="text-xs font-bold text-lyo-300 uppercase tracking-wide">Checkpoint</p>
          <p className="text-sm text-white font-medium">{quiz.question}</p>
          <div className="space-y-2">
            {(quiz.options ?? []).map((opt) => {
              const chosen = item.answered === opt.label;
              return (
                <button
                  key={opt.id}
                  disabled={!!item.answered}
                  onClick={() => onQuizAnswer(opt)}
                  className={cn(
                    'w-full flex items-center justify-between px-4 py-2.5 rounded-xl text-sm text-left border transition-all',
                    chosen && item.wasCorrect && 'bg-green-500/15 border-green-500/40 text-white',
                    chosen && !item.wasCorrect && 'bg-red-500/15 border-red-500/40 text-white',
                    !chosen && item.answered && opt.is_correct && 'bg-green-500/10 border-green-500/30 text-white/80',
                    !item.answered && 'bg-white/5 border-white/10 text-white/85 hover:bg-white/10',
                    !chosen && item.answered && !opt.is_correct && 'bg-white/[0.03] border-white/5 text-white/30',
                  )}
                >
                  <span>{opt.label}</span>
                  {chosen && (item.wasCorrect
                    ? <CheckCircle2 className="w-4 h-4 text-green-400 shrink-0" />
                    : <XCircle className="w-4 h-4 text-red-400 shrink-0" />)}
                </button>
              );
            })}
          </div>
        </motion.div>
      );
    }

    case 'session_end':
      return (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="rounded-2xl border border-accent-gold/30 bg-accent-gold/[0.07] p-5 space-y-2"
        >
          <p className="text-sm font-bold text-accent-gold">🔔 Class dismissed</p>
          {item.homework && (
            <p className="text-sm text-white/85"><span className="font-semibold">Homework:</span> {item.homework}</p>
          )}
          {item.nextHook && (
            <p className="text-sm text-white/60 italic">{item.nextHook}</p>
          )}
        </motion.div>
      );

    case 'board':
      return null; // rendered in the sticky whiteboard

    case 'info':
      return <p className="text-xs text-white/40 text-center py-1">{item.text}</p>;

    default:
      return null;
  }
}
