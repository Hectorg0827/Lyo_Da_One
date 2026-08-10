'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  ArrowLeft, ChevronLeft, ChevronRight, HelpCircle, Zap, Send,
  NotebookPen, Volume2, VolumeX, AudioLines, X, Hand, Sparkles,
  Accessibility, Gauge, Settings2, Timer, ArrowRight, SkipForward,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  useClassroomStore,
  type ClassroomConnection,
  type ClassroomMode,
  type HintLevel,
} from '@/stores/classroom-store';
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
  const difficulty: ClassroomConnection['difficulty'] = difficultyParam === 'beginner'
    || difficultyParam === 'intermediate'
    || difficultyParam === 'advanced'
    ? difficultyParam
    : undefined;
  const modeParam = params.get('mode');
  const initialMode: ClassroomMode = modeParam === 'classroom'
    || modeParam === 'challenge'
    || modeParam === 'review'
    ? modeParam
    : 'solo';
  const parsedDuration = Number(params.get('duration'));
  const initialDuration = [5, 10, 20].includes(parsedDuration) ? parsedDuration : 10;
  const [mode, setMode] = useState<ClassroomMode>(initialMode);
  const [durationMinutes, setDurationMinutes] = useState(initialDuration);
  const [reduceMotion, setReduceMotion] = useState(false);
  const systemReducedMotion = useReducedMotion();
  const animationsOff = reduceMotion || systemReducedMotion === true;
  const connection: ClassroomConnection = {
    topic,
    sessionId: courseId,
    objective,
    difficulty,
    mode,
    durationMinutes,
    reducedMotion: animationsOff,
  };

  const {
    status, board, boardHistory, viewingBoard, caption, activeSpeaker, prompt,
    transcript, lyoState, waitingForScene, continueLabel,
    progressCurrent, progressTotal, error, soundOn, voiceOn, speechRate,
    connect, disconnect, answerPrompt, answerQuiz, answerTransfer, askQuestion, signal,
    requestHint, continueLesson, skipLesson, toggleSound, toggleVoice, setSpeechRate, viewBoard,
  } = useClassroomStore();

  const [question, setQuestion] = useState('');
  const [notebookOpen, setNotebookOpen] = useState(false);
  const [handRaised, setHandRaised] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hintMenuOpen, setHintMenuOpen] = useState(false);
  const [choiceNudge, setChoiceNudge] = useState(false);
  const boardEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    connect(connection);
    return () => disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic, courseId, objective, difficulty, mode, durationMinutes, animationsOff]);

  useEffect(() => {
    if (viewingBoard === -1) {
      boardEndRef.current?.scrollIntoView({
        behavior: animationsOff ? 'auto' : 'smooth',
        block: 'end',
      });
    }
  }, [board.length, viewingBoard, animationsOff]);

  const shownBoard = viewingBoard === -1 ? board : boardHistory[viewingBoard] ?? board;
  const totalBoards = boardHistory.length;
  const needsChoice = viewingBoard === -1 && (
    !!prompt || board.some((el) => el.kind === 'quiz' && !el.answered)
  );
  const primaryLabel = needsChoice
    ? 'Choose an answer'
    : waitingForScene
      ? 'Preparing…'
      : continueLabel && !/check understanding/i.test(continueLabel)
        ? continueLabel
        : 'Continue lesson';
  const canGoPreviousBoard = totalBoards > 0 && viewingBoard !== 0;
  const goPreviousBoard = () => {
    if (!canGoPreviousBoard) return;
    viewBoard(viewingBoard === -1 ? totalBoards - 1 : Math.max(viewingBoard - 1, 0));
  };
  const handlePrimary = () => {
    if (needsChoice) {
      setChoiceNudge(true);
      return;
    }
    continueLesson();
  };
  const hintOptions: { level: HintLevel; label: string }[] = [
    { level: 'nudge', label: 'Small nudge' },
    { level: 'principle', label: 'Show the principle' },
    { level: 'worked_step', label: 'Give me the first step' },
    { level: 'full_example', label: 'Show a worked example' },
    { level: 'prerequisite', label: 'Review the prerequisite' },
  ];

  const chooseHint = (level: HintLevel) => {
    requestHint(level);
    setHintMenuOpen(false);
  };

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
          <button
            onClick={() => setSettingsOpen((open) => !open)}
            title="Classroom settings"
            aria-expanded={settingsOpen}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settingsOpen ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5',
            )}
          >
            <Settings2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      {settingsOpen && (
        <div
          role="region"
          aria-label="Classroom settings"
          className="mx-4 mb-2 grid gap-3 rounded-xl border border-white/10 bg-[#111a38] p-3 text-xs text-white/75 sm:grid-cols-3"
        >
          <label className="space-y-1">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Gauge className="h-3.5 w-3.5" /> Learning mode
            </span>
            <select
              value={mode}
              onChange={(event) => setMode(event.target.value as ClassroomMode)}
              className="w-full rounded-lg border border-white/15 bg-[#0a1026] px-2 py-2 text-white"
            >
              <option value="solo">Solo teacher</option>
              <option value="classroom">Classroom discussion</option>
              <option value="challenge">Challenge mode</option>
              <option value="review">Spaced review</option>
            </select>
          </label>
          <label className="space-y-1">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Timer className="h-3.5 w-3.5" /> Session target
            </span>
            <select
              value={durationMinutes}
              onChange={(event) => setDurationMinutes(Number(event.target.value))}
              className="w-full rounded-lg border border-white/15 bg-[#0a1026] px-2 py-2 text-white"
            >
              <option value={5}>5 minutes</option>
              <option value={10}>10 minutes</option>
              <option value={20}>20 minutes</option>
            </select>
          </label>
          <div className="space-y-2">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Accessibility className="h-3.5 w-3.5" /> Accessibility
            </span>
            <label className="flex items-center justify-between gap-2">
              Reduced motion
              <input
                type="checkbox"
                checked={reduceMotion}
                onChange={(event) => setReduceMotion(event.target.checked)}
              />
            </label>
            <label className="flex items-center justify-between gap-2">
              Voice speed
              <select
                value={speechRate}
                onChange={(event) => setSpeechRate(Number(event.target.value))}
                className="rounded border border-white/15 bg-[#0a1026] px-1.5 py-1 text-white"
              >
                <option value={0.75}>0.75×</option>
                <option value={1}>1×</option>
                <option value={1.25}>1.25×</option>
              </select>
            </label>
          </div>
        </div>
      )}

      {/* ── THE BOARD — the main classroom focus ── */}
      <div className="relative flex-1 min-h-0 mx-4">
        <div className={cn(
          'relative flex h-full flex-col rounded-2xl border-[3px] border-[#3a3323] overflow-hidden',
          'bg-[radial-gradient(ellipse_at_top,#17203f_0%,#0d142e_55%,#0a0f24_100%)]',
          'shadow-[inset_0_0_60px_rgba(0,0,0,0.55),0_10px_40px_rgba(0,0,0,0.4)]',
        )}>
          {/* chalk tray */}
          <div className="absolute bottom-0 inset-x-6 h-1.5 rounded-t bg-[#3a3323]/80 z-10" />

          <div className="flex-1 min-h-0 overflow-y-auto px-5 py-4 space-y-5 md:px-6 md:py-5">
            <div className="flex items-center gap-2 text-[10px] font-black tracking-widest text-lyo-300 uppercase">
              <span className="h-1.5 w-1.5 rounded-full bg-lyo-300" />
              LYO Board
              <span className="ml-auto text-white/35">{needsChoice ? 'Practice' : 'Live'}</span>
            </div>
            {shownBoard.length === 0 && !waitingForScene && (
              <div className="h-full flex items-center justify-center text-white/20 text-sm italic">
                a clean board…
              </div>
            )}
            {shownBoard.map((el) => (
              <BoardElementView
                key={el.id}
                el={el}
                onQuizAnswer={answerQuiz}
                onTransferSubmit={answerTransfer}
                reducedMotion={animationsOff}
              />
            ))}
            {prompt && viewingBoard === -1 && (
              <BoardPrompt prompt={prompt} onAnswer={answerPrompt} />
            )}
            {waitingForScene && viewingBoard === -1 && (
              <div className="flex items-center gap-2 text-white/35 text-sm py-3">
                <motion.span
                  animate={animationsOff ? { opacity: 1 } : { opacity: [0.3, 1, 0.3] }}
                  transition={animationsOff ? { duration: 0 } : { duration: 1.3, repeat: Infinity }}
                >
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

          <BoardTeacherCaption caption={caption} activeSpeaker={activeSpeaker} lyoState={lyoState} />
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

      </div>

      {/* ── Your desk ── */}
      <div className="px-4 pb-3 pt-2 space-y-2">
        {choiceNudge && needsChoice && (
          <p className="text-center text-xs font-semibold text-red-300">Choose an answer on the board to continue.</p>
        )}
        <ClassroomTransport
          canGoPrevious={canGoPreviousBoard}
          primaryLabel={primaryLabel}
          primaryDisabled={waitingForScene}
          onPrevious={goPreviousBoard}
          onPrimary={handlePrimary}
          onSkip={skipLesson}
        />
        <div className="flex items-center gap-2">
          <div className="relative shrink-0">
            <button
              onClick={() => setHintMenuOpen((open) => !open)}
              aria-expanded={hintMenuOpen}
              aria-haspopup="menu"
              className="flex items-center gap-1.5 px-3 py-2 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors"
            >
              <HelpCircle className="w-3.5 h-3.5" /> Get help
            </button>
            {hintMenuOpen && (
              <div
                role="menu"
                aria-label="Choose a hint level"
                className="absolute bottom-full left-0 z-30 mb-2 w-56 overflow-hidden rounded-xl border border-white/15 bg-[#111a38] p-1 shadow-2xl"
              >
                {hintOptions.map((option) => (
                  <button
                    key={option.level}
                    role="menuitem"
                    onClick={() => chooseHint(option.level)}
                    className="block w-full rounded-lg px-3 py-2 text-left text-xs text-white/80 hover:bg-white/10 hover:text-white"
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            )}
          </div>
          <button
            onClick={() => signal('too_easy')}
            className="flex items-center gap-1.5 px-3 py-2 rounded-full text-xs font-semibold text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors shrink-0"
          >
            <Zap className="w-3.5 h-3.5" /> Harder case
          </button>

          {handRaised ? (
            <div className="flex-1 flex gap-2">
              <input
                autoFocus
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && submitQuestion()}
                placeholder="Ask the teacher…"
                aria-label="Ask the teacher a question"
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

function BoardTeacherCaption({
  caption,
  activeSpeaker,
  lyoState,
}: {
  caption: { speaker: string; text: string } | null;
  activeSpeaker: string | null;
  lyoState: string;
}) {
  const speaker = caption?.speaker || activeSpeaker || 'Teacher';
  const castMember = CAST.find((member) => member.name === speaker) ?? CAST[0];
  return (
    <div className="relative z-20 border-t border-white/10 bg-black/25 px-3 py-3 backdrop-blur md:px-4">
      <AnimatePresence mode="wait">
        <motion.div
          key={`${speaker}-${caption?.text?.slice(0, 24) ?? lyoState}`}
          role="status"
          aria-live="polite"
          aria-atomic="true"
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          className="flex items-center gap-3"
        >
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-lyo-300/35 bg-white/10 text-xl">
            {castMember.emoji}
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-2 text-xs font-bold text-white">
              <span>{speaker}</span>
              <span className={cn('text-[10px]', castMember.accent.split(' ')[1])}>AI Teacher</span>
            </p>
            <p className="max-h-10 overflow-hidden text-[13px] leading-tight text-white/75">
              {caption?.text || 'The teacher is preparing the next board.'}
            </p>
          </div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
            alt={`Lyo is ${lyoState}`}
            className="hidden h-10 w-10 shrink-0 object-contain drop-shadow-[0_4px_12px_rgba(0,0,0,0.45)] sm:block"
          />
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

function BoardPrompt({
  prompt,
  onAnswer,
}: {
  prompt: { text: string; options: string[] };
  onAnswer: (option: string) => void;
}) {
  return (
    <div className="space-y-3 rounded-xl border border-accent-gold/25 bg-accent-gold/10 p-4">
      <p className="flex items-center gap-2 text-[11px] font-black uppercase tracking-widest text-accent-gold">
        <Hand className="h-3.5 w-3.5" /> Quick choice
      </p>
      <p className="text-base font-semibold text-white">{prompt.text}</p>
      <div className="grid gap-2 sm:grid-cols-2">
        {prompt.options.map((option) => (
          <button
            key={option}
            type="button"
            onClick={() => onAnswer(option)}
            className="rounded-xl border border-white/15 bg-white/5 px-4 py-3 text-left text-sm font-semibold text-white/85 transition-colors hover:border-accent-gold/45 hover:bg-accent-gold/15"
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}

function ClassroomTransport({
  canGoPrevious,
  primaryLabel,
  primaryDisabled,
  onPrevious,
  onPrimary,
  onSkip,
}: {
  canGoPrevious: boolean;
  primaryLabel: string;
  primaryDisabled: boolean;
  onPrevious: () => void;
  onPrimary: () => void;
  onSkip: () => void;
}) {
  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        disabled={!canGoPrevious}
        onClick={onPrevious}
        className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-white/70 transition-colors hover:bg-white/10 disabled:opacity-30"
        title="Previous board"
      >
        <ChevronLeft className="h-4 w-4" />
      </button>
      <button
        type="button"
        disabled={primaryDisabled}
        onClick={onPrimary}
        className="flex h-11 min-w-0 flex-1 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 text-sm font-bold text-white transition-all hover:opacity-90 active:scale-[0.99] disabled:opacity-45"
      >
        <span className="truncate">{primaryLabel}</span>
        <ArrowRight className="h-4 w-4 shrink-0" />
      </button>
      <button
        type="button"
        onClick={onSkip}
        className="flex h-11 shrink-0 items-center justify-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-3 text-xs font-bold text-white/80 transition-colors hover:bg-white/10 sm:w-24"
      >
        <SkipForward className="h-4 w-4" />
        <span>Skip</span>
      </button>
    </div>
  );
}
