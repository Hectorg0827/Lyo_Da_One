'use client';

import { Suspense, useEffect, useMemo, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import {
  ArrowLeft, ChevronLeft, ChevronRight, HelpCircle, Zap, Send,
  NotebookPen, Volume2, VolumeX, AudioLines, X, Hand, Sparkles,
  Accessibility, Gauge, Settings2, Timer, Mic,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { CALL_TO_ACTION, invitation } from '@/lib/teach-it.mjs';
import {
  configureDictation,
  createBrowserSpeechRecognition,
  type BrowserSpeechRecognition,
} from '@/lib/browser-speech';
import { createTranscriptAccumulator, tidyTranscript } from '@/lib/speech-transcript.mjs';
import {
  useClassroomStore,
  type ClassroomConnection,
  type ClassroomMode,
  type HintLevel,
} from '@/stores/classroom-store';
import { ClassroomWorkspace } from '@/components/classroom/ClassroomWorkspace';
import { classroomIsPaused, workspaceScrollAnchor } from '@/lib/board-presentation.mjs';
import { upsertCourseOnStart } from '@/lib/stack';
import { SESSION_LENGTHS, normalizeSessionMinutes } from '@/lib/entry-contract.mjs';
import { conceptsShownInClass } from '@/lib/learner-model.mjs';
import EvidenceRecord from '@/components/classroom/EvidenceRecord';
import SurfaceLoading from '@/components/ui/SurfaceLoading';

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
    <Suspense fallback={<SurfaceLoading label="Preparing the classroom…" />}>
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
  const reviewConceptId = params.get('reviewConceptId') || undefined;
  const objective = params.get('objective') || `Understand and apply ${topic}`;
  const recordScope = params.get('recordScope') === 'unit' ? 'unit' : 'topic';
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
  // SESSION_LENGTHS is shared with the front door on purpose. A length the
  // front door offers but the Classroom does not recognise becomes 10 here
  // with nothing on screen saying so, which is a lesson quietly shorter than
  // the one the learner asked for.
  const initialDuration = normalizeSessionMinutes(params.get('duration')) ?? 10;
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
    reviewConceptId,
    objective,
    recordScope,
    difficulty,
    mode,
    durationMinutes,
    reducedMotion: animationsOff,
    language,
  };

  const {
    status, board, boardHistory, recordConcepts, viewingBoard, caption, activeSpeaker, prompt,
    transcript, lyoState, waitingForScene, isNarrating, canContinue, continueLabel,
    progressCurrent, progressTotal, error, soundOn, voiceOn, speechRate, languageCode,
    connect, disconnect, answerPrompt, answerQuiz, answerTransfer, skipQuestion, unskipQuestion,
    askQuestion, signal, takeFloor, requestHint, continueLesson, skipTurn, toggleSound, toggleVoice,
    setSpeechRate, viewBoard, interruptPrompt,
  } = useClassroomStore();
  const lessonConcepts = useMemo(
    () => conceptsShownInClass(board, boardHistory),
    [board, boardHistory],
  );

  const [question, setQuestion] = useState('');
  const [notebookOpen, setNotebookOpen] = useState(false);
  // The notebook holds two things a learner asks for after a lesson: what
  // was said, and what it proved. They are different questions.
  const [notebookTab, setNotebookTab] = useState<'notes' | 'record'>('notes');
  const [handRaised, setHandRaised] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hintMenuOpen, setHintMenuOpen] = useState(false);
  const [listeningTarget, setListeningTarget] = useState<'question' | 'prompt' | null>(null);
  const [promptResponse, setPromptResponse] = useState('');
  const [engagedPromptId, setEngagedPromptId] = useState<string | null>(null);
  const [speechSupported, setSpeechSupported] = useState(false);
  const [visualHeight, setVisualHeight] = useState<number | null>(null);
  const boardScrollRef = useRef<HTMLDivElement>(null);
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const dictationBaseRef = useRef('');
  const transcriptRef = useRef(createTranscriptAccumulator());
  const dictatingRef = useRef(false);

  useEffect(() => {
    connect(connection);
    return () => disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [topic, courseId, lessonId, reviewConceptId, objective, recordScope, difficulty, mode, durationMinutes, animationsOff, language]);

  useEffect(() => {
    setSpeechSupported(createBrowserSpeechRecognition() !== null);
    return () => {
      dictatingRef.current = false;
      recognitionRef.current?.stop();
    };
  }, []);

  useEffect(() => {
    const viewport = window.visualViewport;
    const updateHeight = () => {
      const height = viewport?.height ?? window.innerHeight;
      if (height > 0) setVisualHeight(Math.round(height));
    };
    updateHeight();
    viewport?.addEventListener('resize', updateHeight);
    window.addEventListener('resize', updateHeight);
    return () => {
      viewport?.removeEventListener('resize', updateHeight);
      window.removeEventListener('resize', updateHeight);
    };
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

  const shownBoard = viewingBoard === -1 ? board : boardHistory[viewingBoard] ?? board;
  const totalBoards = boardHistory.length;
  const lessonPaused = classroomIsPaused(board);
  const activeCheckpoint = viewingBoard === -1
    ? [...board].reverse().find((el) =>
      (el.kind === 'quiz' && !el.answered && !el.skipped)
      || (el.kind === 'transfer' && !el.submitted && !el.skipped))
    : undefined;
  const scrollAnchorId = workspaceScrollAnchor(shownBoard);
  const focusElementId = activeCheckpoint?.id ?? scrollAnchorId;

  // Bring the *start* of the new question into view. Scrolling to the bottom
  // clipped the question and left only its last sentence on short phones.
  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      const scroller = boardScrollRef.current;
      if (!scroller || !focusElementId) return;
      const element = Array.from(scroller.querySelectorAll<HTMLElement>('[data-board-element-id]'))
        .find((node) => node.dataset.boardElementId === focusElementId);
      if (!element) return;
      const top = element.getBoundingClientRect().top
        - scroller.getBoundingClientRect().top + scroller.scrollTop - 12;
      scroller.scrollTo({ top, behavior: animationsOff ? 'auto' : 'smooth' });
    });
    return () => cancelAnimationFrame(frame);
    // Answering updates the same card. It must not reposition the board while
    // the learner is reading the feedback; a new board element does reposition it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrollAnchorId, viewingBoard, animationsOff]);

  const pendingCheckpoint = board.some((el) =>
    (el.kind === 'quiz' && !el.answered && !el.skipped)
    || (el.kind === 'transfer' && !el.submitted && !el.skipped));
  // Some scenes omit CTAButton. The server accepts `continue` once the
  // teacher finishes a scene with no unanswered checkpoint.
  const readyToContinue = status === 'live' && viewingBoard === -1
    && !waitingForScene && (!isNarrating || lessonPaused) && !prompt && !pendingCheckpoint
    && (canContinue || board.length > 0);
  const primaryContinue = languageCode.toLowerCase().startsWith('es') ? 'Continuar' : 'Continue';
  const normalizedContinueLabel = continueLabel.trim();
  // The store uses the literal English "Continue" when a CTA omits its label.
  // Treat that value as a sentinel so the UI can keep the language-aware fallback.
  const displayedContinueLabel = canContinue
    && normalizedContinueLabel
    && normalizedContinueLabel.toLowerCase() !== 'continue'
    ? normalizedContinueLabel
    : primaryContinue;

  // History and narration transport are shown only when actionable.
  const canGoBack = viewingBoard === -1 ? totalBoards > 0 : viewingBoard > 0;
  const canGoNext = viewingBoard !== -1 || isNarrating;
  const goBack = () => {
    if (viewingBoard === -1) viewBoard(totalBoards - 1);
    else viewBoard(viewingBoard - 1);
  };
  const goNext = () => {
    if (viewingBoard === -1) {
      if (isNarrating) skipTurn();
      return;
    }
    viewBoard(viewingBoard >= totalBoards - 1 ? -1 : viewingBoard + 1);
  };
  const nextLabel = viewingBoard === -1 ? 'Skip' : 'Next';
  const nextTitle = viewingBoard !== -1
    ? 'Step forward through earlier boards'
    : 'Skip ahead — cuts the current line short';
  // Lyo owns the teacher position beside the transcript. There is no
  // participant rail: the backend has no real peers to put in one, so the
  // only honest number of classmates to draw is none. CAST survives below
  // purely as the speaker to accent-colour map for the transcript.
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

  /**
   * End dictation for good.
   *
   * Clearing the flag before stopping matters: the recognizer restarts itself
   * after a pause, and only this flag tells a deliberate stop from a breath.
   */
  const stopDictation = () => {
    dictatingRef.current = false;
    setListeningTarget(null);
    try { recognitionRef.current?.stop(); } catch { /* already stopped */ }
  };

  const submitQuestion = () => {
    if (!question.trim()) return;
    stopDictation();
    askQuestion(question);
    setQuestion('');
    setHandRaised(false);
  };

  const submitPromptResponse = (response: string) => {
    if (!response.trim()) return;
    if (answerPrompt(response.trim())) {
      setPromptResponse('');
      stopDictation();
    }
  };

  // A dictated question may outlast one recognizer — each ends itself after a
  // pause — so the transcript lives here and is carried across every restart.
  const startDictation = (target: 'question' | 'prompt', continuing = false): boolean => {
    const recognition = createBrowserSpeechRecognition();
    if (!recognition) return false;
    recognitionRef.current = recognition;
    configureDictation(recognition, language === 'auto' ? null : language);
    if (continuing) transcriptRef.current.carryOver();

    recognition.onresult = (event) => {
      if (recognitionRef.current !== recognition) return;
      const { combined } = transcriptRef.current.push(event);
      const base = dictationBaseRef.current;
      const text = (base + tidyTranscript(combined, { capitalize: !base })).slice(0, 1000);
      if (target === 'prompt') setPromptResponse(text);
      else setQuestion(text);
    };
    recognition.onend = () => {
      if (recognitionRef.current !== recognition) return;
      recognitionRef.current = null;
      if (!dictatingRef.current) {
        setListeningTarget(null);
        return;
      }
      window.setTimeout(() => {
        if (!dictatingRef.current) return;
        if (!startDictation(target, true)) {
          dictatingRef.current = false;
          setListeningTarget(null);
        }
      }, 120);
    };
    recognition.onerror = (event) => {
      if (recognitionRef.current !== recognition) return;
      if (event?.error === 'no-speech' || event?.error === 'aborted') return;
      recognitionRef.current = null;
      dictatingRef.current = false;
      setListeningTarget(null);
    };

    try {
      recognition.start();
      return true;
    } catch {
      recognitionRef.current = null;
      return false;
    }
  };

  const toggleDictation = (target: 'question' | 'prompt') => {
    if (listeningTarget) {
      stopDictation();
      return;
    }
    if (!createBrowserSpeechRecognition()) return;
    if (target === 'prompt' && prompt) {
      setEngagedPromptId(prompt.id);
      interruptPrompt();
    } else takeFloor();
    transcriptRef.current.reset();
    const currentValue = target === 'prompt' ? promptResponse : question;
    dictationBaseRef.current = currentValue ? currentValue.replace(/\s*$/, ' ') : '';
    dictatingRef.current = true;
    if (startDictation(target)) setListeningTarget(target);
    else dictatingRef.current = false;
  };

  return (
    <div
      className="relative mx-auto flex h-full min-h-0 max-w-5xl flex-col overflow-hidden pb-[max(0.5rem,env(safe-area-inset-bottom))]"
      style={visualHeight ? { height: visualHeight } : undefined}
    >

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
            {status === 'live' ? lessonPaused
              ? <span className="text-[var(--warning)]">● Paused</span>
              : <span className="text-[var(--success)]">● Live</span>
              : status === 'connecting' ? <span className="text-white/60">Connecting…</span> : <span className="text-white/60">{status}</span>}
          </p>
          {progressTotal > 0 && (
            <div className="mt-1.5 h-1 w-full overflow-hidden rounded-full bg-white/10" aria-label={`${progressCurrent} of ${progressTotal} skills practised`}>
              <div className="h-full rounded-full bg-gradient-to-r from-lyo-500 to-accent-purple transition-[width] duration-500" style={{ width: `${Math.min(100, Math.max(0, progressCurrent / progressTotal * 100))}%` }} />
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
              'hidden sm:inline-flex',
              soundOn ? 'text-lyo-300 bg-lyo-500/15' : 'text-white/40 hover:text-white hover:bg-white/5')}
          >
            {soundOn ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
          </button>
          <button
            onClick={() => setNotebookOpen(true)}
            title="Your notebook (transcript)"
            className="hidden rounded-lg p-2 text-white/40 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex"
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
          className="mx-4 mb-2 grid gap-3 rounded-xl border border-white/10 bg-[var(--surface)] p-3 text-xs text-white/75 sm:grid-cols-3"
        >
          <div className="flex gap-2 sm:hidden">
            <button type="button" onClick={toggleSound}
              className="min-h-11 flex-1 rounded-lg border border-white/15 bg-white/5 px-3 text-white">
              {soundOn ? 'Mute classroom sounds' : 'Turn on classroom sounds'}
            </button>
            <button type="button" onClick={() => { setNotebookOpen(true); setSettingsOpen(false); }}
              className="min-h-11 flex-1 rounded-lg border border-white/15 bg-white/5 px-3 text-white">
              Your notebook
            </button>
          </div>
          <label className="space-y-1">
            <span className="flex items-center gap-1.5 font-semibold text-white">
              <Gauge className="h-3.5 w-3.5" /> Learning mode
            </span>
            <select
              value={mode}
              onChange={(event) => setMode(event.target.value as ClassroomMode)}
              className="w-full rounded-lg border border-white/15 bg-[var(--background)] px-2 py-2 text-white"
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
              className="w-full rounded-lg border border-white/15 bg-[var(--background)] px-2 py-2 text-white"
            >
              {SESSION_LENGTHS.map((minutes) => (
                <option key={minutes} value={minutes}>{minutes} minutes</option>
              ))}
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
                className="rounded border border-white/15 bg-[var(--background)] px-1.5 py-1 text-white"
              >
                <option value={0.75}>0.75×</option>
                <option value={1}>1×</option>
                <option value={1.25}>1.25×</option>
              </select>
            </label>
          </div>
        </div>
      )}

      {/* One teacher, one synchronized transcript. ClassroomCaptionSync owns
          the visual text; this component owns the semantic live region. */}
      <div className={cn(
        'mx-3 mb-3 flex min-h-[92px] shrink-0 items-center gap-3 rounded-2xl border bg-[var(--surface-2)] px-3 py-2 shadow-[0_12px_32px_rgba(2,6,23,0.28)] backdrop-blur-xl sm:mx-4 sm:px-4',
        'border-lyo-400/30',
      )}>
        <motion.img
          key={lyoState}
          src={LYO_STATE_IMG[lyoState] ?? LYO_STATE_IMG.reading}
          alt={`Lyo is ${lyoState}`}
          className="h-12 w-12 shrink-0 object-contain drop-shadow-[0_6px_16px_rgba(0,0,0,0.55)]"
          initial={animationsOff ? false : { scale: 0.7 }}
          animate={animationsOff
            ? { scale: 1, rotate: 0, y: 0 }
            : lyoState === 'celebrating'
              ? { scale: [1, 1.25, 1], rotate: [0, 10, -10, 0], y: [0, -10, 0] }
              : { scale: 1, rotate: 0, y: 0 }}
          transition={{ duration: animationsOff ? 0 : 0.6 }}
        />
        <div className="min-w-0 flex-1 space-y-1">
          <div className="flex items-center justify-between gap-2">
            <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-lyo-300">{activeSpeaker && activeSpeaker !== 'Teacher' ? `${activeSpeaker} speaks` : 'Lyo explains'}</p>
            {caption && <button type="button" onClick={() => { setNotebookTab('notes'); setNotebookOpen(true); }} className="min-h-11 text-[11px] text-[var(--text-secondary)] underline underline-offset-2">Full transcript</button>}
          </div>
          <div data-classroom-caption-target className={cn('relative overflow-hidden', voiceOn ? 'h-10 sm:h-[44px]' : 'h-[72px] sm:h-[84px]')}>
          <span role="status" aria-live="polite" aria-atomic="true" className="sr-only">
            {caption ? `${caption.speaker}: ${caption.text}` : ''}
          </span>
          {!caption && (
            <p className="flex h-full items-center text-sm font-medium text-white/75">
              {waitingForScene || status === 'connecting'
                ? board.some((el) => (el.kind === 'quiz' && el.answered) || (el.kind === 'transfer' && el.submitted))
                  ? 'Lyo is checking your answer…' : 'Lyo is preparing the next step…'
                : pendingCheckpoint || prompt ? 'Your turn — respond to Lyo' : 'Lyo is ready'}
            </p>
          )}
          </div>
        </div>
      </div>

      {/* The board grows with the lesson. Only this area scrolls when a scene
          is longer than the available phone height; the teacher stays visible. */}
      {(shownBoard.length > 0 || !prompt || error) && (
      <div ref={boardScrollRef} className="mx-3 min-h-0 flex-1 overflow-y-auto overscroll-contain pb-2 sm:mx-4">
        <div className={cn(
          'flex min-h-[180px] flex-col rounded-[22px] border border-white/10 overflow-hidden',
          'bg-[var(--surface)]',
          'shadow-[inset_0_1px_0_rgba(255,255,255,0.06),inset_0_0_70px_rgba(2,6,23,0.45),0_18px_50px_rgba(2,6,23,0.42)]',
        )}>
          {(canGoBack || canGoNext || viewingBoard !== -1) && (
            <div className="flex min-h-11 shrink-0 items-center justify-between gap-1 border-b border-white/5 bg-black/25 px-2 py-1">
              <div className="min-w-20">
                {canGoBack && (
                  <button onClick={goBack} title="Previous board"
                    className="flex min-h-10 items-center gap-1 rounded-lg px-2 text-xs font-semibold text-white/75 hover:bg-white/5 hover:text-white">
                    <ChevronLeft className="h-4 w-4" /> Back
                  </button>
                )}
              </div>
              <span className="text-[10px] font-mono text-white/60">
                {viewingBoard === -1 ? 'CURRENT BOARD' : `${viewingBoard + 1}/${totalBoards}`}
              </span>
              <div className="flex min-w-20 justify-end">
                {canGoNext && (
                  <button onClick={goNext} title={nextTitle}
                    className="flex min-h-10 items-center gap-1 rounded-lg px-2 text-xs font-semibold text-white/80 hover:bg-white/5 hover:text-white">
                    {nextLabel} <ChevronRight className="h-4 w-4" />
                  </button>
                )}
              </div>
            </div>
          )}

          <div className="space-y-4 px-4 py-4 sm:space-y-5 sm:px-7 sm:py-6">
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

            {/* A session that ended on its own is a finish, not a fault — and
                it is the moment a learner has something specific to say and
                feels good enough to say it. Discover's hardest problem is
                supply; this is where supply comes from. The topic is already
                known, so the ask names it and the composer opens with the
                title written. Not shown after an error, where nothing was
                finished to teach. */}
            {status === 'ended' && !error && (
              <div className="rounded-xl border border-[#8B5CF6]/30 bg-[#8B5CF6]/10 px-4 py-3">
                <p className="text-sm text-white/85">{invitation(topic)}</p>
                <Link
                  href={`/discover?compose=clip&topic=${encodeURIComponent(topic ?? '')}`}
                  className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-white px-4 py-2 font-rounded text-[13px] font-bold text-[#0A0D16]"
                >
                  {CALL_TO_ACTION}
                </Link>
              </div>
            )}
            {shownBoard.length === 0 && !prompt && status !== 'error' && status !== 'ended' && (
              <div className="flex min-h-[150px] flex-col items-center justify-center gap-3 text-center">
                <Sparkles className="h-6 w-6 text-lyo-300" aria-hidden="true" />
                <div className="space-y-1.5">
                  <p className="text-sm font-semibold text-white/80">
                    {status === 'connecting' ? 'Setting up your class'
                      : transcript.length > 0 ? 'Preparing the next step' : 'Preparing your first question'}
                  </p>
                  <p className="mx-auto max-w-xs text-xs leading-relaxed text-white/70">
                    {topic} · {difficulty ? `${difficulty} level · ` : ''}
                    {durationMinutes} minute session
                  </p>
                </div>
                <div className="flex gap-1.5" aria-hidden>
                  {[0, 1, 2].map((i) => (
                    <motion.span
                      key={i}
                      className="h-1.5 w-1.5 rounded-full bg-lyo-300/70"
                      animate={animationsOff ? undefined : { opacity: [0.25, 1, 0.25] }}
                      transition={{ duration: 1.4, repeat: Infinity, delay: i * 0.18 }}
                    />
                  ))}
                </div>
              </div>
            )}
            <ClassroomWorkspace
                elements={shownBoard}
                awaitingFeedback={waitingForScene}
                onQuizAnswer={answerQuiz}
                onTransferSubmit={answerTransfer}
                onLearnerInputStart={takeFloor}
                onSkipQuestion={skipQuestion}
                onUnskipQuestion={unskipQuestion}
                onAskHelp={() => requestHint('nudge')}
                reducedMotion={animationsOff}
              />
          </div>

          <div className="mx-8 h-px shrink-0 bg-gradient-to-r from-transparent via-lyo-400/30 to-transparent" />
        </div>
      </div>
      )}

      {/* A director prompt can have choices or ask for an open response. */}
      <AnimatePresence>
        {prompt && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 8 }}
            className="mx-3 mt-2 space-y-2 rounded-xl border border-lyo-400/30 bg-lyo-500/10 p-3 sm:mx-4"
          >
            <p className="text-xs font-bold uppercase tracking-wide text-lyo-200">Your turn</p>
            {(engagedPromptId === prompt.id || !voiceOn) && (
              <p className="text-sm font-medium leading-relaxed text-white">{prompt.text}</p>
            )}
            {prompt.options?.length ? (
              <div className="flex flex-wrap gap-2">
                {prompt.options.map((opt) => (
                  <button key={opt} onClick={() => submitPromptResponse(opt)}
                    className="min-h-11 rounded-xl border border-lyo-400/40 bg-lyo-500/15 px-4 py-2 text-sm font-semibold text-white hover:bg-lyo-500/30">
                    {opt}
                  </button>
                ))}
              </div>
            ) : (
              <div className="flex gap-2">
                <input value={promptResponse} onFocus={() => {
                  setEngagedPromptId(prompt.id);
                  interruptPrompt();
                }}
                  onChange={(event) => setPromptResponse(event.target.value)}
                  onKeyDown={(event) => { if (event.key === 'Enter') submitPromptResponse(promptResponse); }}
                  aria-label="Answer Lyo" placeholder="Answer Lyo…"
                  className="min-h-11 min-w-0 flex-1 rounded-xl border border-white/20 bg-white/5 px-3 text-sm text-white placeholder:text-white/55 focus:outline-none focus:border-lyo-400" />
                {speechSupported && (
                  <button type="button" onClick={() => toggleDictation('prompt')}
                    aria-label={listeningTarget === 'prompt' ? 'Stop dictation' : 'Answer aloud'}
                    className={cn('min-h-11 min-w-11 rounded-xl border p-2',
                      listeningTarget === 'prompt' ? 'border-red-400/50 bg-red-500/15 text-red-200' : 'border-white/20 bg-white/5 text-white')}>
                    <Mic className="mx-auto h-5 w-5" />
                  </button>
                )}
                <button type="button" onClick={() => submitPromptResponse(promptResponse)}
                  disabled={!promptResponse.trim()} aria-label="Send answer"
                  className="min-h-11 min-w-11 rounded-xl bg-lyo-600 p-2 text-white disabled:opacity-40">
                  <Send className="mx-auto h-5 w-5" />
                </button>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {/* No seated cast row.
        *
        * The four classmates this used to draw were not real. The backend's
        * `_get_peer_states` returns a single hard-coded stub — its own comment
        * says "AI peers are synthetic — no DB table" — and nothing on the wire
        * can make a peer speak. Drawing them put invented people around a real
        * learner, which is the one thing the product trust gate exists to stop.
        *
        * CAST stays as the speaker to accent-colour map used by the transcript.
        */}

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
        {readyToContinue && (
          <button
            onClick={continueLesson}
            className="min-h-12 w-full rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple py-2.5 text-sm font-semibold text-white shadow-[0_8px_24px_rgba(124,58,237,0.22)] transition-all hover:brightness-110 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40"
          >
            {displayedContinueLabel} →
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
                className="absolute bottom-full left-0 z-30 mb-2 w-56 overflow-hidden rounded-xl border border-white/15 bg-[var(--surface)] p-1 shadow-2xl"
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
              // Purple is interaction; gold is reserved for achievements.
              // Raising your hand is an ordinary control, not something won.
              handRaised
                ? 'border-lyo-500/50 bg-lyo-500/25 text-white'
                : 'border-lyo-500/30 bg-lyo-500/10 text-lyo-200 hover:bg-lyo-500/20',
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
                  onClick={() => toggleDictation('question')}
                  aria-label={listeningTarget === 'question' ? 'Stop dictation' : 'Dictate your question'}
                  className={cn(
                    'px-3 rounded-full border transition-colors',
                    listeningTarget === 'question'
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
              className="fixed inset-0 bg-black/50 z-[60]"
              onClick={() => setNotebookOpen(false)}
            />
            <motion.div
              initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 28, stiffness: 260 }}
              /* Above the mobile nav, which is also z-50 and — being rendered
                 after the page in the layout — otherwise wins the tie and
                 covers the bottom of the drawer on a phone. */
              className="fixed right-0 top-0 bottom-0 z-[61] flex w-full max-w-sm flex-col border-l border-white/10 bg-[#0d142e] pb-[env(safe-area-inset-bottom)]"
            >
              <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
                <p className="text-sm font-bold text-white flex items-center gap-2">
                  <NotebookPen className="w-4 h-4 text-accent-gold" /> Your notebook
                </p>
                <button onClick={() => setNotebookOpen(false)} className="p-1.5 text-white/50 hover:text-white">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div role="tablist" aria-label="Notebook" className="flex gap-1 border-b border-white/10 px-3 pb-2 pt-1">
                {([['notes', 'What was said'], ['record', "What you've shown"]] as const).map(
                  ([value, label]) => (
                    <button
                      key={value}
                      role="tab"
                      aria-selected={notebookTab === value}
                      onClick={() => setNotebookTab(value)}
                      className={cn(
                        'min-h-[36px] rounded-lg px-3 text-[12.5px] font-semibold transition-colors',
                        notebookTab === value
                          ? 'bg-white/10 text-white'
                          : 'text-white/50 hover:bg-white/5 hover:text-white/80',
                      )}
                    >
                      {label}
                    </button>
                  ),
                )}
              </div>
              <div className="flex-1 overflow-y-auto px-4 py-3">
                {notebookTab === 'record' ? (
                  <EvidenceRecord subjects={[topic, objective, ...lessonConcepts, ...recordConcepts]} />
                ) : (
                  <div className="space-y-2.5">
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
                )}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
