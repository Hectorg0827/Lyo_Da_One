'use client';

import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  ArrowLeft, ChevronLeft, ChevronRight, HelpCircle, Zap, Send,
  NotebookPen, Volume2, VolumeX, X, Hand, Sparkles,
  Accessibility, Gauge, Settings2, Timer, Pause, Play,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  useClassroomStore,
  type ClassroomConnection,
  type ClassroomMode,
  type HintLevel,
} from '@/stores/classroom-store';
import { BoardElementView } from '@/components/classroom/BoardElementView';
import MascotAvatar from '@/components/chat/MascotAvatar';

// ─── The cast ─────────────────────────────────────────────────────────────────

// Maya, Sam, and Rio have real illustrated artwork (same character family as
// the Teacher/Lyo). Zara doesn't yet — her purple/star character art hasn't
// been added to the repo as a file (only seen inline in chat, no fetchable
// path), so she stays on emoji until that PNG lands in
// web/public/students/. Drop the file in and add `avatar: '/students/...'`
// here, matching the pattern above.
const CAST: { name: string; emoji: string; accent: string; avatar?: string }[] = [
  { name: 'Teacher', emoji: '🧑‍🏫', accent: 'ring-accent-purple text-accent-purple' },
  { name: 'Maya', emoji: '👩🏽‍🎓', accent: 'ring-accent-teal text-accent-teal', avatar: '/students/student_genius.png' },
  { name: 'Sam', emoji: '🧑🏻‍🎓', accent: 'ring-accent-orange text-accent-orange', avatar: '/students/student_clever.png' },
  { name: 'Rio', emoji: '🧑🏾‍🎓', accent: 'ring-accent-green text-accent-green', avatar: '/students/student_funny.png' },
  { name: 'Zara', emoji: '👩🏼‍🎓', accent: 'ring-accent-gold text-accent-gold' },
];

// The Teacher gets real illustrated artwork instead of an emoji — four
// named variants, mirroring the iOS classroom (ActiveLessonView.swift's
// teacherIndex/actualTeacherName), so the same course consistently shows
// the same teacher instead of a random one every render.
const TEACHER_VARIANTS = [
  { name: 'Mr. Newton', image: '/teacher/lyo_teacher_1.png' },
  { name: 'Dr. Saria', image: '/teacher/lyo_teacher_2.png' },
  { name: 'Prof. Chen', image: '/teacher/lyo_teacher_3.png' },
  { name: 'Mr. Davis', image: '/teacher/lyo_teacher_4.png' },
];

function stableHash(input: string): number {
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    hash = (hash * 31 + input.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

// Reduced-motion fallback only: a single representative static frame per
// state. When motion is allowed, LYO_ANIMATED_STATES below decides whether
// MascotAvatar animates that state as a live flip-book or a gentle idle
// breathe instead of freezing on one of these.
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

// States that used to freeze on a single reading-family frame now get the
// live flip-book instead (MascotAvatar cycles all 4 reading frames every
// 200ms) — a genuinely animated "thinking," not a static cutout. States
// not in this set (listening, celebrating) get MascotAvatar's idle
// breathing/glance animation instead of sitting perfectly still.
const LYO_ANIMATED_STATES = new Set([
  'reading', 'thinking', 'curious', 'surprised', 'confused', 'shy', 'sleeping',
]);

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
  const teacherVariant = TEACHER_VARIANTS[stableHash(courseId) % TEACHER_VARIANTS.length];
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
    transcript, lyoState, waitingForScene, canContinue, continueLabel,
    progressCurrent, progressTotal, error, soundOn, voiceOn, speechRate, isPaused,
    connect, disconnect, answerPrompt, answerQuiz, answerTransfer, askQuestion, signal,
    requestHint, continueLesson, toggleSound, toggleVoice, togglePause, setSpeechRate, viewBoard,
  } = useClassroomStore();

  const [question, setQuestion] = useState('');
  const [promptResponseText, setPromptResponseText] = useState('');
  const [notebookOpen, setNotebookOpen] = useState(false);
  const [handRaised, setHandRaised] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hintMenuOpen, setHintMenuOpen] = useState(false);
  const boardEndRef = useRef<HTMLDivElement>(null);

  // ── Netflix/YouTube-style chrome auto-hide ──
  // Everything except the board, the teacher's caption, and the two
  // mascots hides itself after a few seconds of no interaction, and a
  // single tap on the board brings it back — mirroring YouTube's
  // controls-overlay behavior. A quiz/prompt checkpoint always forces
  // chrome back on and holds it there until answered.
  const [chromeVisible, setChromeVisible] = useState(true);
  const hideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const classroomRootRef = useRef<HTMLDivElement>(null);

  const resetHideTimer = useCallback(() => {
    if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    setChromeVisible(true);
    const keepAlive = isPaused || !!prompt || settingsOpen || notebookOpen || hintMenuOpen;
    if (!keepAlive) {
      hideTimerRef.current = setTimeout(() => setChromeVisible(false), 3000);
    }
  }, [isPaused, prompt, settingsOpen, notebookOpen, hintMenuOpen]);

  useEffect(() => {
    resetHideTimer();
    return () => {
      if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resetHideTimer]);

  // Mobile: default the classroom to a full-bleed, landscape, full-screen
  // "video player" feel. Real orientation lock + fullscreen where the
  // platform supports it (Chrome/Android); everywhere else (notably iOS
  // Safari, which implements neither API) falls back to the CSS rotate
  // trick scoped via `.classroom-landscape-shell` in globals.css.
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (!window.matchMedia('(max-width: 768px)').matches) return;
    const tryLandscape = async () => {
      try {
        const el = classroomRootRef.current;
        if (el && !document.fullscreenElement) await el.requestFullscreen?.();
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        await (screen.orientation as any)?.lock?.('landscape');
      } catch {
        // Unsupported (iOS Safari) or blocked without a user gesture —
        // the CSS fallback in globals.css handles it instead.
      }
    };
    void tryLandscape();
    return () => {
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (screen.orientation as any)?.unlock?.();
        if (document.fullscreenElement) void document.exitFullscreen();
      } catch {
        // Nothing to clean up if it never locked in the first place.
      }
    };
  }, []);

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
  const visibleCast = mode === 'classroom'
    ? CAST
    : CAST.filter((member) => member.name === 'Teacher');
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
    resetHideTimer();
  };

  const submitQuestion = () => {
    if (!question.trim()) return;
    askQuestion(question);
    setQuestion('');
    setHandRaised(false);
    resetHideTimer();
  };

  const submitPromptResponse = (response: string) => {
    const trimmed = response.trim();
    if (!trimmed) return;
    answerPrompt(trimmed);
    setPromptResponseText('');
    resetHideTimer();
  };

  const handleBoardQuizAnswer: typeof answerQuiz = (...args) => {
    answerQuiz(...args);
    resetHideTimer();
  };

  const handleBoardTransferSubmit: typeof answerTransfer = (...args) => {
    answerTransfer(...args);
    resetHideTimer();
  };

  return (
    <div
      ref={classroomRootRef}
      className="classroom-landscape-shell flex flex-col h-dvh w-full md:h-[calc(100dvh-4rem)] md:max-w-4xl md:mx-auto"
    >

      {/* ── Top bar — chrome, auto-hides like a video player's controls ── */}
      <AnimatePresence>
        {chromeVisible && (
          <motion.div
            initial={animationsOff ? false : { opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={animationsOff ? { opacity: 0 } : { opacity: 0, y: -8 }}
            transition={{ duration: animationsOff ? 0 : 0.2 }}
            className="flex items-center gap-2 px-4 py-2"
          >
            <button
              onClick={() => router.back()}
              className="p-2 rounded-lg text-white/50 hover:text-white hover:bg-white/5 transition-colors"
              title="Leave classroom"
              aria-label="Leave classroom"
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
              {/* The single most accessible control — leftmost, largest visual
                  weight, unambiguous icon + state color, matching "Pause
                  teacher" being the most important thing a learner can reach. */}
              <button
                onClick={() => { togglePause(); resetHideTimer(); }}
                title={isPaused ? 'Resume class' : 'Pause class'}
                aria-label={isPaused ? 'Resume class' : 'Pause class'}
                className={cn('p-2.5 rounded-lg transition-colors',
                  isPaused
                    ? 'text-accent-gold bg-accent-gold/15 ring-1 ring-accent-gold/40'
                    : 'text-white/70 hover:text-white hover:bg-white/5')}
              >
                {isPaused ? <Play className="w-4 h-4" /> : <Pause className="w-4 h-4" />}
              </button>
              {/* One combined control for both audio streams (narration +
                  ambient sound effects) instead of two separate speaker-ish
                  icons that read as duplicates of each other. */}
              <button
                onClick={() => {
                  const nextOn = !(voiceOn || soundOn);
                  if (voiceOn !== nextOn) toggleVoice();
                  if (soundOn !== nextOn) toggleSound();
                  resetHideTimer();
                }}
                title={voiceOn || soundOn ? 'Mute classroom sound' : 'Turn on classroom sound'}
                aria-label={voiceOn || soundOn ? 'Mute classroom sound' : 'Turn on classroom sound'}
                className={cn('p-2 rounded-lg transition-colors',
                  voiceOn || soundOn ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5')}
              >
                {voiceOn || soundOn ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
              </button>
              <button
                onClick={() => { setNotebookOpen(true); resetHideTimer(); }}
                title="Your notebook (transcript)"
                aria-label="Open your notebook"
                className="p-2 rounded-lg text-white/40 hover:text-white hover:bg-white/5 transition-colors"
              >
                <NotebookPen className="w-4 h-4" />
              </button>
              <button
                onClick={() => { setSettingsOpen((open) => !open); resetHideTimer(); }}
                title="Classroom settings"
                aria-label="Classroom settings"
                aria-expanded={settingsOpen}
                className={cn(
                  'p-2 rounded-lg transition-colors',
                  settingsOpen ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5',
                )}
              >
                <Settings2 className="w-4 h-4" />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {settingsOpen && (
        <div
          role="region"
          aria-label="Classroom settings"
          className="mx-4 mb-2 grid gap-3 rounded-xl border border-white/10 bg-[#111a38] p-3 text-xs text-white/75 sm:grid-cols-3"
        >
          {/* Dark pill groups instead of native <select> — a native select
              opens the OS's own picker on mobile, which is bright/white and
              breaks the classroom's theme entirely. */}
          <div className="space-y-1.5">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Gauge className="h-3.5 w-3.5" /> Learning mode
            </span>
            <div className="flex flex-wrap gap-1.5" role="group" aria-label="Learning mode">
              {(
                [
                  { value: 'solo', label: 'Solo' },
                  { value: 'classroom', label: 'Classroom' },
                  { value: 'challenge', label: 'Challenge' },
                  { value: 'review', label: 'Review' },
                ] as { value: ClassroomMode; label: string }[]
              ).map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => setMode(opt.value)}
                  aria-pressed={mode === opt.value}
                  className={cn(
                    'px-2.5 py-1.5 rounded-lg text-[11px] font-semibold border transition-colors',
                    mode === opt.value
                      ? 'bg-lyo-500/25 border-lyo-400/50 text-white'
                      : 'bg-white/5 border-white/10 text-white/60 hover:bg-white/10 hover:text-white',
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>
          <div className="space-y-1.5">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Timer className="h-3.5 w-3.5" /> Session target
            </span>
            <div className="flex flex-wrap gap-1.5" role="group" aria-label="Session target">
              {[5, 10, 20].map((mins) => (
                <button
                  key={mins}
                  type="button"
                  onClick={() => setDurationMinutes(mins)}
                  aria-pressed={durationMinutes === mins}
                  className={cn(
                    'px-2.5 py-1.5 rounded-lg text-[11px] font-semibold border transition-colors',
                    durationMinutes === mins
                      ? 'bg-lyo-500/25 border-lyo-400/50 text-white'
                      : 'bg-white/5 border-white/10 text-white/60 hover:bg-white/10 hover:text-white',
                  )}
                >
                  {mins} min
                </button>
              ))}
            </div>
          </div>
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
            <div className="flex items-center justify-between gap-2">
              <span>Voice speed</span>
              <div className="flex gap-1" role="group" aria-label="Voice speed">
                {[0.75, 1, 1.25].map((rate) => (
                  <button
                    key={rate}
                    type="button"
                    onClick={() => setSpeechRate(rate)}
                    aria-pressed={speechRate === rate}
                    className={cn(
                      'px-2 py-1 rounded text-[10px] font-semibold border transition-colors',
                      speechRate === rate
                        ? 'bg-lyo-500/25 border-lyo-400/50 text-white'
                        : 'bg-white/5 border-white/10 text-white/50 hover:bg-white/10 hover:text-white',
                    )}
                  >
                    {rate}×
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── THE BOARD — the main attraction, always on screen ── */}
      <div className="relative flex-1 min-h-0 mx-4">
        <div className={cn(
          'h-full rounded-2xl border-[3px] border-[#3a3323] overflow-hidden',
          'bg-[radial-gradient(ellipse_at_top,#17203f_0%,#0d142e_55%,#0a0f24_100%)]',
          'shadow-[inset_0_0_60px_rgba(0,0,0,0.55),0_10px_40px_rgba(0,0,0,0.4)]',
        )}>
          {/* chalk tray */}
          <div className="absolute bottom-0 inset-x-6 h-1.5 rounded-t bg-[#3a3323]/80 z-10" />

          {/* pb-20 reserves the corner where Lyo sits (see below) so the
              last board element — often a Submit/Send button pinned to the
              bottom-right, e.g. TransferView's "Submit application" — never
              renders underneath the mascot. */}
          {/* Tap-to-toggle chrome, YouTube-style: a tap that lands on the
              scroll container itself (empty board space — not a quiz
              button, not a scroll drag on a child) toggles the chrome. */}
          <div
            className="h-full overflow-y-auto px-6 pt-5 pb-20 space-y-5"
            onClick={(e) => {
              if (e.target !== e.currentTarget) return;
              if (chromeVisible) {
                if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
                setChromeVisible(false);
              } else {
                resetHideTimer();
              }
            }}
          >
            {shownBoard.length === 0 && !waitingForScene && (
              <div className="h-full flex items-center justify-center text-white/20 text-sm italic">
                a clean board…
              </div>
            )}
            {shownBoard.map((el) => (
              <BoardElementView
                key={el.id}
                el={el}
                onQuizAnswer={handleBoardQuizAnswer}
                onTransferSubmit={handleBoardTransferSubmit}
                reducedMotion={animationsOff}
              />
            ))}
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
              // mr-14 keeps this banner's box clear of Lyo's corner —
              // scroll-to-bottom can otherwise pull it up alongside the
              // mascot even with the container's own bottom padding.
              <div className="text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 mr-14">
                {error ?? 'Something went wrong.'}{' '}
                <button className="underline" onClick={() => connect(connection)}>Retry</button>
              </div>
            )}
            <div ref={boardEndRef} />
          </div>
        </div>

        {/* board history flip — chrome, auto-hides */}
        {(totalBoards > 0 && chromeVisible) && (
          <div className="absolute top-2 right-2 flex items-center gap-1 bg-black/50 backdrop-blur rounded-full px-2 py-1 z-20">
            <button
              disabled={viewingBoard === 0}
              onClick={() => { viewBoard(viewingBoard === -1 ? totalBoards - 1 : Math.max(viewingBoard - 1, 0)); resetHideTimer(); }}
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
              onClick={() => { viewBoard(viewingBoard >= totalBoards - 1 ? -1 : viewingBoard + 1); resetHideTimer(); }}
              className="p-1 text-white/60 hover:text-white disabled:opacity-25"
              title="Forward"
            >
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        )}

        {/* Lyo at their corner desk. pointer-events-none so a purely
            decorative mascot can never intercept a tap meant for board
            content underneath it — belt-and-suspenders alongside the
            scroll area's reserved bottom padding above. */}
        <motion.div
          key={lyoState}
          className="absolute -bottom-3 right-3 w-14 h-14 drop-shadow-[0_4px_12px_rgba(0,0,0,0.6)] z-20 pointer-events-none"
          initial={animationsOff ? false : { scale: 0.7 }}
          animate={animationsOff
            ? { scale: 1, rotate: 0, y: 0 }
            : lyoState === 'celebrating'
              ? { scale: [1, 1.25, 1], rotate: [0, 10, -10, 0], y: [0, -10, 0] }
              : { scale: 1, rotate: 0, y: 0 }}
          transition={{ duration: animationsOff ? 0 : 0.6 }}
        >
          {animationsOff ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
              alt={`Lyo is ${lyoState}`}
              className="w-14 h-14 object-contain"
            />
          ) : (
            <MascotAvatar
              thinking={LYO_ANIMATED_STATES.has(lyoState)}
              idle={!LYO_ANIMATED_STATES.has(lyoState)}
              size={56}
              alt={`Lyo is ${lyoState}`}
            />
          )}
        </motion.div>
      </div>

      {/* ── Teacher's voice — permanent, never hides with the rest of the
          chrome. The Teacher's illustrated avatar sits here as a small
          badge so it stays on screen even once the cast row (which is
          where it normally lives) auto-hides. ── */}
      <div className="px-6 pt-3 pb-1 min-h-[3.4rem] flex items-center gap-3">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={teacherVariant.image}
          alt={teacherVariant.name}
          className="w-9 h-9 rounded-full object-cover shrink-0 ring-2 ring-white/10"
        />
        <AnimatePresence mode="wait">
          {caption && (
            <motion.p
              role="status"
              aria-live="polite"
              aria-atomic="true"
              key={caption.speaker + caption.text.slice(0, 24)}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              className="text-[15px] leading-snug text-white/90 text-left flex-1"
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

      {/* ── Cold-call answer strip ──
          Real, question-specific options render as chips. An open-ended
          question (no options — "what do you think...", "give me an
          example...") gets a text field instead of a fabricated yes/no
          pair, plus a low-friction "I'm not sure" escape hatch. */}
      <AnimatePresence>
        {prompt && (
          prompt.options?.length ? (
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
                  onClick={() => { answerPrompt(opt); resetHideTimer(); }}
                  className="px-4 py-2 rounded-full text-sm font-semibold bg-accent-gold/15 border border-accent-gold/40 text-white hover:bg-accent-gold/30 transition-colors"
                >
                  {opt}
                </button>
              ))}
            </motion.div>
          ) : (
            <motion.div
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 8 }}
              className="px-6 py-1.5 space-y-2"
            >
              <div className="flex items-center gap-2">
                <Hand className="w-4 h-4 text-accent-gold shrink-0 animate-bounce" />
                <input
                  autoFocus
                  value={promptResponseText}
                  onChange={(e) => setPromptResponseText(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && submitPromptResponse(promptResponseText)}
                  placeholder="Explain in your own words…"
                  aria-label="Answer the teacher's question"
                  className="flex-1 min-w-0 bg-white/5 border border-white/10 rounded-full px-4 py-2 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-accent-gold/50"
                />
                <button
                  onClick={() => submitPromptResponse(promptResponseText)}
                  disabled={!promptResponseText.trim()}
                  className="p-2 rounded-full bg-gradient-to-r from-lyo-600 to-accent-purple text-white disabled:opacity-40 shrink-0"
                  aria-label="Send answer"
                >
                  <Send className="w-3.5 h-3.5" />
                </button>
              </div>
              <div className="flex justify-center">
                <button
                  onClick={() => submitPromptResponse("I'm not sure")}
                  className="px-3 py-1.5 rounded-full text-xs font-semibold text-white/60 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white transition-colors"
                >
                  I&apos;m not sure
                </button>
              </div>
            </motion.div>
          )
        )}
      </AnimatePresence>

      {/* ── The class, seated — chrome, auto-hides ── */}
      <AnimatePresence>
        {chromeVisible && (
          <motion.div
            initial={animationsOff ? false : { opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={animationsOff ? { opacity: 0 } : { opacity: 0, height: 0 }}
            transition={{ duration: animationsOff ? 0 : 0.2 }}
            className="flex items-end justify-center gap-5 px-4 pt-1 pb-2 overflow-hidden"
          >
            {visibleCast.map((member, i) => {
              const speaking = activeSpeaker === member.name;
              const isTeacher = member.name === 'Teacher';
              const displayName = isTeacher ? teacherVariant.name : member.name;
              const avatarSrc = isTeacher ? teacherVariant.image : member.avatar;
              return (
                <motion.div
                  key={member.name}
                  className="flex flex-col items-center gap-0.5"
                  animate={{ y: speaking ? -4 : 0 }}
                >
                  <motion.div
                    className={cn(
                      'w-11 h-11 rounded-full flex items-center justify-center text-xl bg-white/[0.06] ring-2 transition-shadow overflow-hidden',
                      speaking ? `${member.accent.split(' ')[0]} shadow-[0_0_18px_rgba(139,92,246,0.45)]` : 'ring-white/10',
                    )}
                    animate={speaking
                      ? { scale: [1, 1.07, 1] }
                      : { y: [0, i % 2 === 0 ? 1.5 : -1.5, 0] }}
                    transition={speaking
                      ? { duration: 0.7, repeat: Infinity }
                      : { duration: 3 + i * 0.4, repeat: Infinity, ease: 'easeInOut' }}
                  >
                    {avatarSrc ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={avatarSrc}
                        alt={displayName}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      member.emoji
                    )}
                  </motion.div>
                  <span className={cn('text-[9.5px] font-bold',
                    speaking ? member.accent.split(' ')[1] : 'text-white/35')}>
                    {displayName}
                  </span>
                </motion.div>
              );
            })}
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Your desk — chrome, auto-hides (a live prompt/quiz forces it
          back via resetHideTimer's `keepAlive` check, so the necessary
          buttons are still reachable at a checkpoint) ── */}
      <AnimatePresence>
        {chromeVisible && (
          <motion.div
            initial={animationsOff ? false : { opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={animationsOff ? { opacity: 0 } : { opacity: 0, height: 0 }}
            transition={{ duration: animationsOff ? 0 : 0.2 }}
            className="px-4 pb-3 pt-1 space-y-2 overflow-hidden"
          >
            {canContinue && (
              <button
                onClick={() => { continueLesson(); resetHideTimer(); }}
                className="w-full py-2.5 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-lyo-600 to-accent-purple hover:opacity-90 active:scale-[0.99] transition-all"
              >
                {continueLabel} →
              </button>
            )}
            <div className="flex items-center gap-2">
              <div className="relative shrink-0">
                <button
                  onClick={() => { setHintMenuOpen((open) => !open); resetHideTimer(); }}
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
                onClick={() => { signal('too_easy'); resetHideTimer(); }}
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
                  onClick={() => { setHandRaised(true); resetHideTimer(); }}
                  className="flex-1 flex items-center justify-center gap-2 py-2 rounded-full text-xs font-semibold text-accent-gold bg-accent-gold/10 border border-accent-gold/25 hover:bg-accent-gold/20 transition-colors"
                >
                  <Hand className="w-3.5 h-3.5" /> Raise your hand
                </button>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

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
