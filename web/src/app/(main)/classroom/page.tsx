'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft, ChevronLeft, ChevronRight, HelpCircle, Zap, Send,
  NotebookPen, Volume2, VolumeX, AudioLines, X, Hand, Sparkles,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useClassroomStore } from '@/stores/classroom-store';
import { BoardElementView } from '@/components/classroom/BoardElementView';

// ─── The cast ─────────────────────────────────────────────────────────────────

const CAST: { name: string; emoji: string; accent: string }[] = [
  { name: 'Teacher', emoji: '🧑‍🏫', accent: 'ring-accent-purple text-accent-purple' },
  { name: 'Maya', emoji: '👩🏽‍🎓', accent: 'ring-accent-teal text-accent-teal' },
  { name: 'Sam', emoji: '🧑🏻‍🎓', accent: 'ring-accent-orange text-accent-orange' },
  { name: 'Rio', emoji: '🧑🏾‍🎓', accent: 'ring-accent-green text-accent-green' },
  { name: 'Zack', emoji: '👨🏼‍🎓', accent: 'ring-accent-gold text-accent-gold' },
];

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

export default function ClassroomPage() {
  return (
    <Suspense fallback={<div className="h-full" />}>
      <ClassroomStage />
    </Suspense>
  );
}

function ClassroomStage() {
  const router = useRouter();
  const params = useSearchParams();
  const topic = params.get('topic') || 'General Learning';
  const courseId = params.get('courseId') || topic;
  const objective = params.get('objective') || `Understand and apply ${topic}`;
  const difficultyParam = params.get('difficulty');
  const difficulty = difficultyParam === 'beginner'
    || difficultyParam === 'intermediate'
    || difficultyParam === 'advanced'
    ? difficultyParam
    : undefined;
  const connection = { topic, sessionId: courseId, objective, difficulty };

  const {
    status, board, boardHistory, viewingBoard, caption, activeSpeaker, prompt,
    transcript, lyoState, waitingForScene, canContinue, continueLabel,
    progressCurrent, progressTotal, error, soundOn, voiceOn,
    connect, disconnect, answerPrompt, answerQuiz, askQuestion, signal,
    continueLesson, toggleSound, toggleVoice, viewBoard,
  } = useClassroomStore();

  const [question, setQuestion] = useState('');
  const [notebookOpen, setNotebookOpen] = useState(false);
  const [handRaised, setHandRaised] = useState(false);
  const boardEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    connect(connection);
    return () => disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic, courseId, objective, difficulty]);

  useEffect(() => {
    if (viewingBoard === -1) {
      boardEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
    }
  }, [board.length, viewingBoard]);

  const shownBoard = viewingBoard === -1 ? board : boardHistory[viewingBoard] ?? board;
  const totalBoards = boardHistory.length;

  const submitQuestion = () => {
    if (!question.trim()) return;
    askQuestion(question);
    setQuestion('');
    setHandRaised(false);
  };

  return (
    <div className="flex flex-col h-[calc(100dvh-8rem)] md:h-[calc(100dvh-4rem)] max-w-4xl mx-auto">

      {/* ── Top bar ── */}
      <div className="flex items-center gap-2 px-4 py-2">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-lg text-white/50 hover:text-white hover:bg-white/5 transition-colors"
          title="Leave classroom"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div className="min-w-0">
          <h1 className="text-sm font-bold text-white truncate">{topic}</h1>
          <p className="text-[11px] text-lyo-200/80 truncate" title={objective}>
            Goal: {objective}
          </p>
          <p className="text-[10px] text-white/45">
            {status === 'live' ? <span className="text-green-400">● class in session</span>
              : status === 'connecting' ? 'walking to class…' : status}
            <span className="ml-2">
              {progressCurrent}/{progressTotal} checkpoints mastered
            </span>
          </p>
        </div>
        <div className="ml-auto flex items-center gap-1">
          <button
            onClick={toggleVoice}
            title={voiceOn ? 'Mute voices' : 'Hear the class speak'}
            className={cn('p-2 rounded-lg transition-colors',
              voiceOn ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5')}
          >
            <AudioLines className="w-4 h-4" />
          </button>
          <button
            onClick={toggleSound}
            title={soundOn ? 'Mute classroom sounds' : 'Classroom sounds on'}
            className={cn('p-2 rounded-lg transition-colors',
              soundOn ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5')}
          >
            {soundOn ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
          </button>
          <button
            onClick={() => setNotebookOpen(true)}
            title="Your notebook (transcript)"
            className="p-2 rounded-lg text-white/40 hover:text-white hover:bg-white/5 transition-colors"
          >
            <NotebookPen className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* ── THE BOARD — the main attraction ── */}
      <div className="relative flex-1 min-h-0 mx-4">
        <div className={cn(
          'h-full rounded-2xl border-[3px] border-[#3a3323] overflow-hidden',
          'bg-[radial-gradient(ellipse_at_top,#17203f_0%,#0d142e_55%,#0a0f24_100%)]',
          'shadow-[inset_0_0_60px_rgba(0,0,0,0.55),0_10px_40px_rgba(0,0,0,0.4)]',
        )}>
          {/* chalk tray */}
          <div className="absolute bottom-0 inset-x-6 h-1.5 rounded-t bg-[#3a3323]/80 z-10" />

          <div className="h-full overflow-y-auto px-6 py-5 space-y-5">
            {shownBoard.length === 0 && !waitingForScene && (
              <div className="h-full flex items-center justify-center text-white/20 text-sm italic">
                a clean board…
              </div>
            )}
            {shownBoard.map((el) => (
              <BoardElementView key={el.id} el={el} onQuizAnswer={answerQuiz} />
            ))}
            {waitingForScene && viewingBoard === -1 && (
              <div className="flex items-center gap-2 text-white/35 text-sm py-3">
                <motion.span animate={{ opacity: [0.3, 1, 0.3] }} transition={{ duration: 1.3, repeat: Infinity }}>
                  <Sparkles className="w-4 h-4" />
                </motion.span>
                the teacher is preparing…
              </div>
            )}
            {status === 'error' && (
              <div className="text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
                {error ?? 'Something went wrong.'}{' '}
                <button className="underline" onClick={() => connect(connection)}>Retry</button>
              </div>
            )}
            <div ref={boardEndRef} />
          </div>
        </div>

        {/* board history flip */}
        {(totalBoards > 0) && (
          <div className="absolute top-2 right-2 flex items-center gap-1 bg-black/50 backdrop-blur rounded-full px-2 py-1 z-20">
            <button
              disabled={viewingBoard === 0}
              onClick={() => viewBoard(viewingBoard === -1 ? totalBoards - 1 : Math.max(viewingBoard - 1, 0))}
              className="p-1 text-white/60 hover:text-white disabled:opacity-25"
              title="Previous board"
            >
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
            <span className="text-[10px] text-white/50 font-mono">
              {viewingBoard === -1 ? 'live' : `${viewingBoard + 1}/${totalBoards}`}
            </span>
            <button
              disabled={viewingBoard === -1}
              onClick={() => viewBoard(viewingBoard >= totalBoards - 1 ? -1 : viewingBoard + 1)}
              className="p-1 text-white/60 hover:text-white disabled:opacity-25"
              title="Forward"
            >
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        )}

        {/* Lyo at their corner desk */}
        <motion.img
          key={lyoState}
          src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
          alt={`Lyo is ${lyoState}`}
          className="absolute -bottom-3 right-3 w-14 h-14 object-contain drop-shadow-[0_4px_12px_rgba(0,0,0,0.6)] z-20"
          initial={{ scale: 0.7 }}
          animate={lyoState === 'celebrating'
            ? { scale: [1, 1.25, 1], rotate: [0, 10, -10, 0], y: [0, -10, 0] }
            : { scale: 1, rotate: 0, y: 0 }}
          transition={{ duration: 0.6 }}
        />
      </div>

      {/* ── Teacher's voice — one live caption line ── */}
      <div className="px-6 pt-3 pb-1 min-h-[3.4rem]">
        <AnimatePresence mode="wait">
          {caption && (
            <motion.p
              key={caption.speaker + caption.text.slice(0, 24)}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              className="text-[15px] leading-snug text-white/90 text-center"
            >
              <span className={cn('font-bold mr-2',
                CAST.find((c) => c.name === caption.speaker)?.accent.split(' ')[1] ?? 'text-lyo-300')}>
                {caption.speaker}:
              </span>
              “{caption.text}”
            </motion.p>
          )}
        </AnimatePresence>
      </div>

      {/* ── Cold-call answer strip ── */}
      <AnimatePresence>
        {prompt && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 8 }}
            className="px-6 py-1.5 flex flex-wrap items-center justify-center gap-2"
          >
            <Hand className="w-4 h-4 text-accent-gold animate-bounce" />
            {prompt.options.map((opt) => (
              <button
                key={opt}
                onClick={() => answerPrompt(opt)}
                className="px-4 py-2 rounded-full text-sm font-semibold bg-accent-gold/15 border border-accent-gold/40 text-white hover:bg-accent-gold/30 transition-colors"
              >
                {opt}
              </button>
            ))}
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── The class, seated ── */}
      <div className="flex items-end justify-center gap-5 px-4 pt-1 pb-2">
        {CAST.map((member, i) => {
          const speaking = activeSpeaker === member.name;
          return (
            <motion.div
              key={member.name}
              className="flex flex-col items-center gap-0.5"
              animate={{ y: speaking ? -4 : 0 }}
            >
              <motion.div
                className={cn(
                  'w-11 h-11 rounded-full flex items-center justify-center text-xl bg-white/[0.06] ring-2 transition-shadow',
                  speaking ? `${member.accent.split(' ')[0]} shadow-[0_0_18px_rgba(139,92,246,0.45)]` : 'ring-white/10',
                )}
                animate={speaking
                  ? { scale: [1, 1.07, 1] }
                  : { y: [0, i % 2 === 0 ? 1.5 : -1.5, 0] }}
                transition={speaking
                  ? { duration: 0.7, repeat: Infinity }
                  : { duration: 3 + i * 0.4, repeat: Infinity, ease: 'easeInOut' }}
              >
                {member.emoji}
              </motion.div>
              <span className={cn('text-[9.5px] font-bold',
                speaking ? member.accent.split(' ')[1] : 'text-white/35')}>
                {member.name}
              </span>
            </motion.div>
          );
        })}
      </div>

      {/* ── Your desk ── */}
      <div className="px-4 pb-3 pt-1 space-y-2">
        {canContinue && (
          <button
            onClick={continueLesson}
            className="w-full py-2.5 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-lyo-600 to-accent-purple hover:opacity-90 active:scale-[0.99] transition-all"
          >
            {continueLabel} →
          </button>
        )}
        <div className="flex items-center gap-2">
          <button
            onClick={() => signal('confused')}
            className="flex items-center gap-1.5 px-3 py-2 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors shrink-0"
          >
            <HelpCircle className="w-3.5 h-3.5" /> Lost
          </button>
          <button
            onClick={() => signal('too_easy')}
            className="flex items-center gap-1.5 px-3 py-2 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors shrink-0"
          >
            <Zap className="w-3.5 h-3.5" /> Too easy
          </button>

          {handRaised ? (
            <div className="flex-1 flex gap-2">
              <input
                autoFocus
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && submitQuestion()}
                placeholder="Ask your question out loud…"
                className="flex-1 bg-white/5 border border-white/10 rounded-full px-4 py-2 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-lyo-500/50"
              />
              <button
                onClick={submitQuestion}
                disabled={!question.trim()}
                className="px-3.5 rounded-full bg-gradient-to-r from-lyo-600 to-accent-purple text-white disabled:opacity-40"
              >
                <Send className="w-3.5 h-3.5" />
              </button>
            </div>
          ) : (
            <button
              onClick={() => setHandRaised(true)}
              className="flex-1 flex items-center justify-center gap-2 py-2 rounded-full text-xs font-semibold text-accent-gold bg-accent-gold/10 border border-accent-gold/25 hover:bg-accent-gold/20 transition-colors"
            >
              <Hand className="w-3.5 h-3.5" /> Raise your hand
            </button>
          )}
        </div>
      </div>

      {/* ── Notebook drawer — the transcript, a byproduct ── */}
      <AnimatePresence>
        {notebookOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/50 z-40"
              onClick={() => setNotebookOpen(false)}
            />
            <motion.div
              initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 28, stiffness: 260 }}
              className="fixed right-0 top-0 bottom-0 w-full max-w-sm bg-[#0d142e] border-l border-white/10 z-50 flex flex-col"
            >
              <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
                <p className="text-sm font-bold text-white flex items-center gap-2">
                  <NotebookPen className="w-4 h-4 text-accent-gold" /> Your notebook
                </p>
                <button onClick={() => setNotebookOpen(false)} className="p-1.5 text-white/50 hover:text-white">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2.5">
                {transcript.length === 0 && (
                  <p className="text-white/30 text-sm italic">Notes will appear as the class goes on.</p>
                )}
                {transcript.map((line) => (
                  <p key={line.id} className="text-[13px] leading-relaxed text-white/80">
                    <span className={cn('font-bold mr-1.5',
                      line.speaker === 'You' ? 'text-accent-gold'
                        : CAST.find((c) => c.name === line.speaker)?.accent.split(' ')[1] ?? 'text-white/60')}>
                      {line.speaker}:
                    </span>
                    {line.text}
                  </p>
                ))}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
