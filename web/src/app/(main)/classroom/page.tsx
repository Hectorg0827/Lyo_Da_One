'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  ArrowLeft, ChevronLeft, ChevronRight, HelpCircle, Zap, Send,
  NotebookPen, Volume2, VolumeX, AudioLines, X, Hand, Sparkles,
  Accessibility, Gauge, Settings2, Timer, Mic,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import {
  createBrowserSpeechRecognition,
  type BrowserSpeechRecognition,
} from '@/lib/browser-speech';
import {
  useClassroomStore,
  type ClassroomConnection,
  type ClassroomMode,
  type HintLevel,
} from '@/stores/classroom-store';
import { BoardElementView } from '@/components/classroom/BoardElementView';
import { upsertCourseOnStart } from '@/lib/stack';

// ─── The cast ─────────────────────────────────────────────────────────────────

const CAST: { name: string; emoji: string; accent: string }[] = [
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
  const lessonId = params.get('lessonId') || undefined;
  const objective = params.get('objective') || `Understand and apply ${topic}`;
  const language = params.get('language') || 'auto';
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
    courseId,
    lessonId,
    objective,
    difficulty,
    mode,
    durationMinutes,
    reducedMotion: animationsOff,
    language,
  };

  const {
    status, board, boardHistory, viewingBoard, caption, activeSpeaker, prompt,
    transcript, lyoState, waitingForScene, isNarrating, canContinue, continueLabel,
    progressCurrent, progressTotal, error, soundOn, voiceOn, speechRate,
    connect, disconnect, answerPrompt, answerQuiz, answerTransfer, skipQuestion, unskipQuestion,
    askQuestion, signal, takeFloor, requestHint, continueLesson, skipTurn, toggleSound, toggleVoice,
    setSpeechRate, viewBoard,
  } = useClassroomStore();

  const [question, setQuestion] = useState('');
  const [notebookOpen, setNotebookOpen] = useState(false);
  const [handRaised, setHandRaised] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hintMenuOpen, setHintMenuOpen] = useState(false);
  const [listening, setListening] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
  const boardEndRef = useRef<HTMLDivElement>(null);
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const dictationBaseRef = useRef('');

  useEffect(() => {
    connect(connection);
    return () => disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic, courseId, lessonId, objective, difficulty, mode, durationMinutes, animationsOff, language]);

  useEffect(() => {
    setSpeechSupported(createBrowserSpeechRecognition() !== null);
    return () => recognitionRef.current?.stop();
  }, []);

  // Save this course into the learner's device- and platform-agnostic
  // Stacks list the moment the classroom opens (both the chat-proposal
  // "Start Learning" path and the catalog "/courses/[id]" path land here),
  // mirroring Android's LyoNavHost Routes.CLASSROOM wiring. No-ops silently
  // if the visitor isn't signed in or the sync fails — never blocks class.
  useEffect(() => {
    void upsertCourseOnStart(courseId, topic);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [courseId, topic]);

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

  // Playback rail: Back/Next always render (rather than only once history
  // exists) so the controls are discoverable from the first scene on. Back
  // steps through erased boards; Next either steps forward through that
  // same history, or — once you're caught back up to live — skips the
  // teacher's currently-playing narration turn instead of waiting it out.
  const canGoBack = viewingBoard === -1 ? totalBoards > 0 : viewingBoard > 0;
  const canGoNext = viewingBoard !== -1 || isNarrating;
  const goBack = () => {
    if (viewingBoard === -1) viewBoard(totalBoards - 1);
    else viewBoard(viewingBoard - 1);
  };
  const goNext = () => {
    if (viewingBoard === -1) { if (isNarrating) skipTurn(); return; }
    viewBoard(viewingBoard >= totalBoards - 1 ? -1 : viewingBoard + 1);
  };
  const nextLabel = viewingBoard === -1 ? 'Skip' : 'Next';
  const nextTitle = viewingBoard !== -1
    ? 'Step forward through earlier boards'
    : isNarrating
      ? 'Skip ahead — cuts the current line short'
      : 'Nothing to skip right now';
  // Lyo owns the teacher position beside the transcript. The participant
  // rail is reserved for real classroom-mode peers, avoiding a second
  // representation of the same teacher.
  const visibleCast = mode === 'classroom' ? CAST : [];
  const hintOptions: { level: HintLevel; label: string }[] = [
    { level: 'nudge', label: 'Small nudge' },
    { level: 'principle', label: 'Show the principle' },
    { level: 'worked_step', label: 'Give me the first step' },
    { level: 'full_example', label: 'Show a worked example' },
    { level: 'prerequisite', label: 'Review the prerequisite' },
  ];

  // Every desk control needs an open socket, so gate them on the session
  // actually being live rather than letting the click vanish.
  const live = status === 'live';
  const deskDisabledReason = status === 'connecting'
    ? 'Walking to class — one moment…'
    : status === 'ended'
      ? 'The class session ended. Retry to rejoin.'
      : status === 'error'
        ? 'Not connected to the classroom. Retry to rejoin.'
        : 'The class has not started yet.';

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

  const toggleQuestionDictation = () => {
    if (listening) {
      recognitionRef.current?.stop();
      return;
    }
    const recognition = createBrowserSpeechRecognition();
    if (!recognition) return;
    takeFloor();
    recognitionRef.current = recognition;
    dictationBaseRef.current = question ? question.replace(/\s*$/, ' ') : '';
    recognition.lang = language === 'auto' ? navigator.language || 'en-US' : language;
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.onresult = (event) => {
      let transcript = '';
      for (let index = 0; index < event.results.length; index += 1) {
        transcript += event.results[index][0].transcript;
      }
      setQuestion((dictationBaseRef.current + transcript).slice(0, 1000));
    };
    recognition.onend = () => setListening(false);
    recognition.onerror = () => setListening(false);
    try {
      recognition.start();
      setListening(true);
    } catch {
      setListening(false);
    }
  };

  return (
    <div className="relative mx-auto flex h-[calc(100dvh-8rem)] min-h-[560px] max-w-5xl flex-col overflow-hidden pb-[max(0.25rem,env(safe-area-inset-bottom))] md:h-[calc(100dvh-4rem)]">

      {/* ── Top bar ── */}
      <div className="flex items-start gap-3 px-3 py-2.5 sm:px-4">
        <button
          onClick={() => router.back()}
          aria-label="Leave classroom"
          className="flex min-h-11 min-w-11 items-center justify-center rounded-xl text-white/70 transition-colors hover:bg-white/10 hover:text-white"
          title="Leave classroom"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <div className="min-w-0 flex-1 pt-0.5">
          <div className="flex min-w-0 items-center gap-2">
            <h1 className="truncate text-[15px] font-bold tracking-tight text-white sm:text-base">{topic}</h1>
            <button type="button" title={objective} aria-label={`Learning goal: ${objective}`} className="shrink-0 rounded-full border border-white/15 px-1.5 text-[10px] font-bold text-white/65 hover:bg-white/10 hover:text-white">i</button>
          </div>
          <p className="truncate text-[11px] font-medium text-white/65">
            {lessonId ? `Lesson ${lessonId}` : 'Guided lesson'} · {objective}
          </p>
          <p className="text-[10px] font-semibold uppercase tracking-[0.14em]">
            {status === 'live' ? <span className="text-emerald-300">● Live</span>
              : status === 'connecting' ? <span className="text-white/60">Connecting…</span> : <span className="text-white/60">{status}</span>}
          </p>
          {progressTotal > 0 && (
            <div className="mt-1.5 h-1 w-full overflow-hidden rounded-full bg-white/10" aria-label={`${progressCurrent} of ${progressTotal} skills practised`}>
              <div className="h-full rounded-full bg-gradient-to-r from-teal-400 to-emerald-400 transition-[width] duration-500" style={{ width: `${Math.min(100, Math.max(0, progressCurrent / progressTotal * 100))}%` }} />
            </div>
          )}
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

      {/* ── THE BOARD — the main attraction ──
          Zone discipline: the frame is a column of non-overlapping bands —
          an optional history rail, then the lesson content. Nothing floats
          over the content, so the learner never reads through an element. */}
      <div className="mx-3 min-h-0 flex-1 sm:mx-4">
        <div className={cn(
          'h-full flex flex-col rounded-[22px] border border-white/10 overflow-hidden',
          'bg-[radial-gradient(ellipse_at_top,#1b2850_0%,#101936_48%,#090f24_100%)]',
          'shadow-[inset_0_1px_0_rgba(255,255,255,0.06),inset_0_0_70px_rgba(2,6,23,0.45),0_18px_50px_rgba(2,6,23,0.42)]',
        )}>
          {/* playback rail — its own band, never on top of the lesson.
              Always rendered (not gated on history existing) so Back/Next
              are discoverable from the very first scene. */}
          <div className="flex items-center justify-between gap-1 shrink-0 border-b border-white/5 bg-black/25 px-2 py-1">
            <button
              disabled={!canGoBack}
              onClick={goBack}
              title={canGoBack ? 'Previous board' : 'No earlier boards yet'}
              className="flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10.5px] font-semibold text-white/60 hover:text-white hover:bg-white/5 disabled:opacity-25 disabled:hover:bg-transparent transition-colors"
            >
              <ChevronLeft className="w-3.5 h-3.5" /> Back
            </button>
            <span className="text-[10px] text-white/50 font-mono">
              {viewingBoard === -1 ? 'live' : `${viewingBoard + 1}/${totalBoards}`}
            </span>
            <button
              disabled={!canGoNext}
              onClick={goNext}
              title={nextTitle}
              className="flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10.5px] font-semibold text-white/60 hover:text-white hover:bg-white/5 disabled:opacity-25 disabled:hover:bg-transparent transition-colors"
            >
              {nextLabel} <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="flex-1 min-h-0 overflow-y-auto px-4 py-4 space-y-4 sm:px-7 sm:py-6 sm:space-y-5">
            {/* Pinned to the top: on an empty board the placeholder below fills
                the scroll area, which would push a recovery action out of sight. */}
            {(status === 'error' || status === 'ended' || error) && (
              <div
                role="alert"
                className="text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3"
              >
                {error ?? (status === 'ended'
                  ? 'The class session ended.'
                  : 'Something went wrong.')}{' '}
                <button className="underline" onClick={() => connect(connection)}>Retry</button>
              </div>
            )}
            {shownBoard.length === 0 && !waitingForScene && (
              <div className="flex-1 flex items-center justify-center text-white/20 text-sm italic py-16">
                a clean board…
              </div>
            )}
            {shownBoard.map((el) => (
              <BoardElementView
                key={el.id}
                el={el}
                onQuizAnswer={answerQuiz}
                onTransferSubmit={answerTransfer}
                onLearnerInputStart={takeFloor}
                onSkipQuestion={skipQuestion}
                onUnskipQuestion={unskipQuestion}
                onAskHelp={() => requestHint('nudge')}
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
            <div ref={boardEndRef} />
          </div>

          <div className="mx-8 h-px shrink-0 bg-gradient-to-r from-transparent via-teal-300/30 to-transparent" />
        </div>
      </div>

      {/* One teacher, one synchronized transcript. ClassroomCaptionSync owns
          the visual text; this component owns the semantic live region. */}
      <div className={cn(
        'mx-3 mt-2 flex shrink-0 items-center gap-3 rounded-2xl border bg-[#111936]/90 px-3 py-2 shadow-[0_12px_32px_rgba(2,6,23,0.28)] backdrop-blur-xl transition-[min-height,border-color] sm:mx-4 sm:px-4',
        voiceOn ? 'min-h-16 border-white/10 sm:min-h-[72px]' : 'min-h-24 border-teal-300/20 sm:min-h-28',
      )}>
        <motion.img
          key={lyoState}
          src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
          alt={`Lyo is ${lyoState}`}
          className="h-12 w-12 shrink-0 object-contain drop-shadow-[0_6px_16px_rgba(0,0,0,0.55)] sm:h-14 sm:w-14"
          initial={animationsOff ? false : { scale: 0.7 }}
          animate={animationsOff
            ? { scale: 1, rotate: 0, y: 0 }
            : lyoState === 'celebrating'
              ? { scale: [1, 1.25, 1], rotate: [0, 10, -10, 0], y: [0, -10, 0] }
              : { scale: 1, rotate: 0, y: 0 }}
          transition={{ duration: animationsOff ? 0 : 0.6 }}
        />
        <div data-classroom-caption-target className="relative min-w-0 flex-1 self-stretch overflow-hidden">
          <span role="status" aria-live="polite" aria-atomic="true" className="sr-only">
            {caption ? `${caption.speaker}: ${caption.text}` : ''}
          </span>
        </div>
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
            {(prompt.options ?? []).map((opt) => (
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
      {visibleCast.length > 0 && <div className="flex items-end justify-center gap-5 px-4 pt-2 pb-1">
        {visibleCast.map((member, i) => {
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
                {member.name === 'Teacher' ? 'Lyo' : member.name}
              </span>
            </motion.div>
          );
        })}
      </div>}

      {/* ── Your desk ──
             Everything here needs a live socket. When the class is not in
             session the controls are disabled rather than silently swallowing
             input, and the reason is stated instead of implied. */}
      <div className="space-y-2 px-3 pb-2 pt-2 sm:px-4">
        {!live && (
          <p className="text-[11px] text-white/45 text-center">
            {deskDisabledReason}
          </p>
        )}
        {canContinue && (
          <button
            onClick={continueLesson}
            disabled={!live}
            title={live ? undefined : deskDisabledReason}
            className="min-h-12 w-full rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple py-2.5 text-sm font-semibold text-white shadow-[0_8px_24px_rgba(124,58,237,0.22)] transition-all hover:brightness-110 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40"
          >
            {continueLabel} →
          </button>
        )}
        <div className="grid grid-cols-3 items-stretch gap-2">
          <div className="relative">
            <button
              onClick={() => setHintMenuOpen((open) => !open)}
              disabled={!live}
              title={live ? undefined : deskDisabledReason}
              aria-expanded={hintMenuOpen}
              aria-haspopup="menu"
              className="flex min-h-12 w-full items-center justify-center gap-1.5 rounded-xl border border-white/10 bg-white/[0.06] px-2 py-2 text-xs font-semibold text-white/80 transition-colors hover:bg-white/10 hover:text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              <HelpCircle className="h-4 w-4 text-accent-purple" /> Help
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
            disabled={!live}
            title={live ? undefined : deskDisabledReason}
            className="flex min-h-12 w-full items-center justify-center gap-1.5 rounded-xl border border-white/10 bg-white/[0.06] px-2 py-2 text-xs font-semibold text-white/80 transition-colors hover:border-accent-purple/35 hover:bg-accent-purple/10 hover:text-white disabled:cursor-not-allowed disabled:opacity-40"
          >
            <Zap className="h-4 w-4 text-accent-purple" /> Challenge
          </button>

          <button
            onClick={() => setHandRaised((raised) => !raised)}
            disabled={!live}
            title={live ? undefined : deskDisabledReason}
            aria-expanded={handRaised}
            className={cn(
              'flex min-h-12 w-full items-center justify-center gap-1.5 rounded-xl border px-2 py-2 text-xs font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-40',
              handRaised
                ? 'border-accent-gold/45 bg-accent-gold/20 text-accent-gold'
                : 'border-accent-gold/25 bg-accent-gold/10 text-accent-gold hover:bg-accent-gold/20',
            )}
          >
            <Hand className="h-4 w-4" /> Raise hand
          </button>
          {handRaised && (
            <div className="col-span-3 flex gap-2 pt-1">
              <input
                autoFocus
                value={question}
                onFocus={takeFloor}
                onChange={(e) => {
                  takeFloor();
                  setQuestion(e.target.value);
                }}
                onKeyDown={(e) => e.key === 'Enter' && submitQuestion()}
                placeholder="Ask the teacher…"
                aria-label="Ask the teacher a question"
                disabled={!live}
                className="flex-1 bg-white/5 border border-white/10 rounded-full px-4 py-2 text-sm text-white placeholder:text-white/30 focus:outline-none focus:border-lyo-500/50 disabled:cursor-not-allowed disabled:opacity-40"
              />
              {speechSupported && (
                <button
                  type="button"
                  onClick={toggleQuestionDictation}
                  aria-label={listening ? 'Stop dictation' : 'Dictate your question'}
                  className={cn(
                    'px-3 rounded-full border transition-colors',
                    listening
                      ? 'border-red-400/50 bg-red-500/15 text-red-200'
                      : 'border-white/10 bg-white/5 text-white/60 hover:text-white',
                  )}
                >
                  <Mic className="w-3.5 h-3.5" />
                </button>
              )}
              <button
                onClick={submitQuestion}
                disabled={!live || !question.trim()}
                className="px-3.5 rounded-full bg-gradient-to-r from-lyo-600 to-accent-purple text-white disabled:cursor-not-allowed disabled:opacity-40"
              >
                <Send className="w-3.5 h-3.5" />
              </button>
            </div>
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
