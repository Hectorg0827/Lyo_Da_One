'use client';

import { create } from 'zustand';
import { SpeechPreparationCache, playSpeechResponse, boardTransitionDelay } from '@/lib/classroom-audio.mjs';
import { playSound, type AmbientSound } from '@/lib/classroom-sounds';
import {
  CLASSROOM_STALL_NOTICE_MS,
  CLASSROOM_STALL_RECOVERY_MS,
  buildClassroomWsUrl,
  canResumeClassroom,
  classroomCourseKey,
  classroomOpening,
  classroomSceneStart,
  classroomSessionStart,
  classroomSessionStorageKey,
} from '@/lib/classroom-contract.mjs';
import { updateCourseProgress } from '@/lib/stack';
import { conceptsFromClassScene, transcriptLabelFor } from '@/lib/learner-model.mjs';
import { parseTeachingVisual, type TeachingVisual } from '@/lib/teaching-activity.mjs';
import type {
  ClassroomContractConnection,
  ClassroomMode,
  ClassroomOpening,
  ClassroomSavedSession,
  HintLevel,
} from '@/lib/classroom-contract.mjs';

export type { ClassroomMode, HintLevel };

// ─── Wire types (match backend lyo_app/ai_classroom exactly) ─────────────────

export interface QuizOption {
  id: string;
  label: string;
  is_correct?: boolean;
  feedback_correct?: string | null;
  feedback_incorrect?: string | null;
  misconception_tag?: string | null;
  remediation_hint?: string | null;
}

/** The four values lyo_app/ai_classroom/sdui_models.py puts on the wire. */
type EvidenceWireType = 'explanation' | 'application' | 'transfer' | 'retrieval';

export interface ClassroomComponent {
  component_id: string;
  type: string;
  text?: string;
  label?: string;
  student_name?: string;
  question?: string;
  options?: QuizOption[];
  action_intent?: string;
  concept_id?: string | null;
  current?: number;
  total?: number;
  placeholder?: string;
  expected_keywords?: string[];
  min_words?: number;
  max_words?: number;
  min_score?: number;
  /** What the component is asking the learner to demonstrate. The wire
   *  vocabulary is narrower than the product ladder and calls retention
   *  "retrieval" — normalizeEvidenceKind adapts it. */
  evidence_type?: EvidenceWireType;
  source_attributions?: string[];
  language_code?: string;
  audio_url?: string | null;
  title?: string;
  content?: string;
  block_type?: string;
  block?: {
    title?: string;
    content?: string;
    items?: string[];
    source_attributions?: string[];
    retrieval_scheduled?: boolean;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

/** One director turn inside a TeacherMessage's JSON script. */
export interface DirectorTurn {
  type: 'speech' | 'user_prompt' | 'lyo_state' | 'board' | 'ambient' | 'pause' | 'session_end';
  speaker?: string;
  text?: string;
  input?: 'voice' | 'tap';
  options?: string[];
  beat_seconds?: number;
  state?: string;
  action?: 'write' | 'draw' | 'highlight' | 'image' | 'bullets' | 'chart' | 'explorable';
  content?: string;
  seconds?: number;
  sound?: string;
  homework?: string;
  next_hook?: string;
  lyo_state?: string;
  // Phase 2 vocabulary
  query?: string;                       // image search query
  caption?: string;                     // image caption
  items?: string[];                     // bullets
  chart_type?: 'bar' | 'line';
  labels?: string[];
  values?: number[];
  expression?: string;                  // explorable
  params?: { name: string; min: number; max: number; initial: number; step?: number }[];
  x_min?: number;
  x_max?: number;
  prompt?: string;
}

// ─── Board model — the main attraction ───────────────────────────────────────

export type BoardElement =
  /** The cover page: what this class is, before any of it is taught. Written
      by the client from the request it just made, so it is on screen in the
      time it takes to open a socket rather than after a generation. */
  | { id: string; kind: 'opening'; opening: ClassroomOpening }
  | { id: string; kind: 'teaching_visual'; visual: TeachingVisual }
  | { id: string; kind: 'chalk'; text: string; highlightedTerm?: string }
  | { id: string; kind: 'highlight'; term: string }
  | { id: string; kind: 'latex'; latex: string }
  | { id: string; kind: 'mermaid'; source: string }
  | { id: string; kind: 'code'; code: string }
  | { id: string; kind: 'image'; url: string | null; caption?: string; query: string; attribution?: string; sourceUrl?: string }
  | { id: string; kind: 'bullets'; items: string[] }
  | { id: string; kind: 'chart'; chartType: 'bar' | 'line'; labels: string[]; values: number[] }
  | { id: string; kind: 'explorable'; expression: string; params: { name: string; min: number; max: number; initial: number; step?: number }[]; xMin?: number; xMax?: number; prompt?: string }
  | { id: string; kind: 'quiz'; quiz: ClassroomComponent; answered?: string; wasCorrect?: boolean; feedback?: string; skipped?: boolean }
  | { id: string; kind: 'transfer'; input: ClassroomComponent; response?: string; submitted?: boolean; skipped?: boolean }
  | { id: string; kind: 'summary'; title: string; content?: string; items: string[]; retrievalScheduled?: boolean }
  | { id: string; kind: 'source'; labels: string[] }
  | { id: string; kind: 'dismissal'; homework?: string; nextHook?: string };

export interface TranscriptItem {
  id: string;
  speaker: string;
  text: string;
}

export interface ActivePrompt {
  id: string;
  speaker: string;
  text: string;
  /** Only set when the question is genuinely multiple-choice — real,
      question-specific options from the director script. Absent for
      open-ended questions ("what do you think...", "give me an
      example..."), which expect a typed/spoken answer instead. Never
      defaulted to a generic yes/no pair. */
  options?: string[];
}

export interface Caption {
  speaker: string;
  text: string;
}

type Status = 'idle' | 'connecting' | 'live' | 'ended' | 'error';

export interface ClassroomConnection extends ClassroomContractConnection {
  mode?: ClassroomMode;
  courseId?: string;
  lessonId?: string;
  /** The learner asking for the seat they left, rather than a new class.
      Never the default: see classroomSessionStart. */
  resume?: boolean;
  /** Which seat, when it is not simply the last one stored. Starting a
      class overwrites that stored record, so by the time the learner reads
      "pick up where you left off" the storage no longer holds the session
      the offer is about — it has to be carried. */
  resumeSession?: ClassroomSavedSession;
}

/**
 * How far past "the next step is coming" a wait has gone.
 *
 * `slow` is still a wait. `stalled` is the admission that the step is not
 * arriving, and is the only one that puts recovery controls on screen.
 */
export type StallPhase = 'none' | 'slow' | 'stalled';

interface ClassroomStore {
  status: Status;
  topic: string;
  /** The id the live teaching session is keyed by server-side. Not the
      course: a second class on one course is a second session. */
  sessionId: string;
  /** The course this class belongs to, which is what Stacks progress is
      filed under. Kept apart from sessionId so starting a lesson over does
      not start the learner's progress over with it. */
  courseId: string;
  /** True when this class picked up a session the learner had already
      started. The opening says so rather than letting a mid-lesson teacher
      turn be the first thing they read. */
  resumedSession: boolean;
  /** A session the learner could still return to, if they want it. */
  resumable: ClassroomSavedSession | null;
  objective: string;
  languageCode: string;

  board: BoardElement[];        // the live board
  boardHistory: BoardElement[][]; // erased boards (flip back through)
  recordConcepts: string[]; // saved plan identities restored on scene start
  viewingBoard: number;         // -1 = live, else history index

  caption: Caption | null;      // the line being spoken right now
  /**
   * How many words of `caption.text` are currently revealed.
   *
   * One number, owned here, because this used to be two. The page paced a
   * reveal off a duration *estimate* while ClassroomCaptionSync paced one off
   * the *real* audio, and both drew their own absolutely-positioned ticker
   * into the same strip — so two different sentences were painted on top of
   * each other and the teacher became unreadable.
   *
   * The pacer (ClassroomCaptionSync) writes this; the page renders it. There
   * is no second copy to drift.
   */
  revealedCount: number;
  activeSpeaker: string | null; // who is talking (lights up in the cast row)
  prompt: ActivePrompt | null;  // cold-call awaiting the learner
  transcript: TranscriptItem[]; // full log — the drawer, the byproduct

  lyoState: string;
  waitingForScene: boolean;
  // True whenever the auto-paced narration (speech/board/pause turns) is
  // actively playing — i.e. there's something skipTurn() could cut short.
  // False while idle, while a user_prompt/quiz/transfer is waiting on the
  // learner, and while paused. Drives whether the "Skip" control is live.
  isNarrating: boolean;
  canContinue: boolean;
  progressCurrent: number;
  progressTotal: number;
  continueLabel: string;
  nextActionIntent: string;
  nextActionComponentId: string;
  error: string | null;
  /** A problem the classroom reported and recovered from, or is waiting out.
      Distinct from `error`, which means the class itself is over. */
  notice: string | null;
  stallPhase: StallPhase;

  soundOn: boolean;
  setRevealedCount: (count: number) => void;
  voiceOn: boolean;
  speechRate: number;
  isPaused: boolean;        // the single most accessible control: stop the class

  connect: (connection: ClassroomConnection) => void;
  disconnect: () => void;
  answerPrompt: (option: string) => boolean;
  answerQuiz: (elementId: string, option: QuizOption) => void;
  answerTransfer: (elementId: string, response: string) => void;
  skipQuestion: (elementId: string) => void;
  unskipQuestion: (elementId: string) => void;
  askQuestion: (text: string) => void;
  takeFloor: () => void;
  interruptPrompt: () => void;
  signal: (kind: 'confused' | 'too_easy') => void;
  requestHint: (level: HintLevel) => void;
  continueLesson: () => void;
  /** Ask the teacher for the step that never came. Sends `continue`, never a
      second copy of a graded answer — a stalled submission must not be
      marked twice because the network was slow. */
  nudgeTeacher: () => void;
  /** Leave the stuck session behind and teach this topic from the top. */
  restartLesson: () => void;
  /** Return to the session this learner left part-way through. */
  resumeLesson: () => void;
  dismissNotice: () => void;
  updateActivity: (id: string, values: Record<string, unknown>) => boolean;
  /** Cuts the currently-playing narration turn short and immediately
      advances to the next queued one — a video-style "skip ahead" for the
      teacher's auto-paced speech/board/pause turns. A no-op when there's
      nothing playing (waiting on the server, a prompt/quiz needs an
      answer, or the class is paused) — see isNarrating. */
  skipTurn: () => void;
  toggleSound: () => void;
  toggleVoice: () => void;
  togglePause: () => void;
  setSpeechRate: (rate: number) => void;
  viewBoard: (index: number) => void; // -1 = live
}

// ─── Internals ───────────────────────────────────────────────────────────────

let ws: WebSocket | null = null;
let turnQueue: DirectorTurn[] = [];
let playing = false;
let playTimer: ReturnType<typeof setTimeout> | null = null;
let speechAbort: AbortController | null = null;
let speechGeneration = 0;
let authToken: string | null = null;
// Speech requests are started as soon as teacher turns arrive, not when the
// previous line finishes. The cache is deliberately tiny and session-local:
// it exists only to overlap network/TTS latency with time the learner is
// already listening to the current turn.
const prefetchedSpeech = new SpeechPreparationCache(3);
let learnerActionStarted: number | null = null;
let contentLatencyRecorded = false;
let idCounter = 0;
let pendingErase = false; // erase lazily when the NEW scene's content arrives
const nextId = () => `cf_${++idCounter}`;

// ─── Remembering a seat ──────────────────────────────────────────────────────

/**
 * The last live session started for a course, so "pick up where you left
 * off" can mean a specific session rather than whichever one the server
 * still happens to be holding.
 *
 * Browser storage, because the id only has to outlive the tab that made it;
 * an unreadable or absent record simply means this is a first class, which
 * is the behaviour every client had before any of this existed.
 */
function readSavedSession(courseKey: string): ClassroomSavedSession | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(classroomSessionStorageKey(courseKey));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<ClassroomSavedSession>;
    if (!parsed || typeof parsed.id !== 'string' || !parsed.id) return null;
    return {
      id: parsed.id,
      startedAt: Number(parsed.startedAt) || 0,
      generation: Math.max(1, Number(parsed.generation) || 1),
    };
  } catch {
    return null;
  }
}

function writeSavedSession(courseKey: string, saved: ClassroomSavedSession) {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.setItem(classroomSessionStorageKey(courseKey), JSON.stringify(saved));
  } catch { /* a learner with storage blocked simply never resumes */ }
}

// ─── The watchdog ────────────────────────────────────────────────────────────

/**
 * Waiting is the one classroom state with no natural end.
 *
 * Every other state is left by something the learner or the teacher does. A
 * wait for a generated step is left only by that step arriving, so when
 * generation fails the class does not break — it simply stops, with a
 * "preparing the next step…" line that is true forever. This watch is what
 * turns that into something a learner can act on.
 *
 * It ticks rather than arming a timer at each of the dozen places a wait
 * begins: a wait that started without arming its own timer is exactly the
 * wait nobody would notice was never ending.
 */
let stallTicker: ReturnType<typeof setInterval> | null = null;
let waitingSince: number | null = null;
let stallNudged = false;
let lastConnection: ClassroomConnection | null = null;
const STALL_TICK_MS = 1000;

function stopStallWatch() {
  if (stallTicker) clearInterval(stallTicker);
  stallTicker = null;
  waitingSince = null;
  stallNudged = false;
}

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoai.app';
const API_KEY = process.env.NEXT_PUBLIC_API_KEY || '';

function wsUrl(connection: ClassroomConnection, token: string | null): string {
  return buildClassroomWsUrl(API_URL, connection, token);
}

/** Exported so the caption UI can pace its word-by-word reveal against the
    same estimate the player itself uses for text-only/fallback pacing —
    one formula, not two that can drift apart. */
export function speechDelay(text: string): number {
  return Math.min(Math.max(text.length * 34, 1400), 7000);
}

function stopSpeech() {
  speechGeneration += 1;
  speechAbort?.abort();
  speechAbort = null;
  if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
    window.speechSynthesis.cancel();
  }
}

// Non-Latin scripts are decisive, but only in this order: Japanese prose mixes
// kana with kanji, and Korean can carry hanja, so those language-specific
// scripts must be checked before the CJK ideographs they share with Chinese.
const SCRIPT_LANGUAGE_HINTS: { code: string; test: RegExp }[] = [
  { code: 'ja', test: /[぀-ヿ]/ },   // hiragana + katakana
  { code: 'ko', test: /[가-힯]/ },   // hangul syllables
  { code: 'ar', test: /[؀-ۿ]/ },
  { code: 'ru', test: /[Ѐ-ӿ]/ },
  { code: 'hi', test: /[ऀ-ॿ]/ },
  { code: 'zh', test: /[一-鿿]/ },   // shared ideographs — last resort
];

// Latin-script languages share an alphabet and much of their function-word
// vocabulary ("la" is French and Spanish, "para" is Spanish and Portuguese),
// so no single hint is decisive. Score every candidate across the whole sample
// and take the strongest rather than returning on the first pattern that hits.
const LATIN_LANGUAGE_HINTS: { code: string; unique?: RegExp; words: RegExp }[] = [
  { code: 'es', unique: /[¿¡ñ]/g, words: /\b(el|los|las|que|para|con|una|uno|por|cómo|qué|cuál|más|así|pero|también|está)\b/gi },
  { code: 'pt', unique: /[ãõ]/g, words: /\b(não|com|para|uma|isso|então|você|está|são|também|mais)\b/gi },
  { code: 'fr', unique: /[œùêîôë]/g, words: /\b(le|la|les|des|est|une|avec|pour|qui|où|dans|nous|être|cette)\b/gi },
  { code: 'de', unique: /[äöüß]/g, words: /\b(der|die|das|und|nicht|mit|für|eine|ist|auch|sich|wird)\b/gi },
  { code: 'it', words: /\b(il|lo|gli|che|per|con|una|è|questo|come|sono|anche|della)\b/gi },
];

// A language-exclusive character is far stronger evidence than a function word
// that several languages share.
const UNIQUE_CHAR_WEIGHT = 3;
// Below this, the evidence is as likely to be an English coincidence as a real
// signal — fall back to the browser's default voice instead of guessing.
const MIN_LANGUAGE_SCORE = 2;

function scoreLatinLanguage(text: string, hint: { unique?: RegExp; words: RegExp }): number {
  const uniqueHits = hint.unique ? (text.match(hint.unique)?.length ?? 0) : 0;
  const distinctWords = new Set(
    (text.match(hint.words) ?? []).map((word) => word.toLowerCase()),
  ).size;
  return uniqueHits * UNIQUE_CHAR_WEIGHT + distinctWords;
}

/**
 * Best-effort guess at the spoken-language code for `text`, so narration is
 * read in a matching voice instead of always defaulting to English. Returns
 * null (meaning: let the browser's default voice handle it) when the text is
 * too short or shows no language-specific signal.
 */
function detectSpeechLanguage(text: string): string | null {
  const trimmed = text.trim();
  if (trimmed.length < 8) return null;

  for (const { code, test } of SCRIPT_LANGUAGE_HINTS) {
    if (test.test(trimmed)) return code;
  }

  let best: { code: string; score: number } | null = null;
  for (const hint of LATIN_LANGUAGE_HINTS) {
    const score = scoreLatinLanguage(trimmed, hint);
    if (score > (best?.score ?? 0)) best = { code: hint.code, score };
  }
  return best && best.score >= MIN_LANGUAGE_SCORE ? best.code : null;
}

/** Picks an installed SpeechSynthesis voice matching a language code, if any. */
function findVoiceForLanguage(code: string): SpeechSynthesisVoice | undefined {
  return window.speechSynthesis.getVoices()
    .find((voice) => voice.lang.toLowerCase().startsWith(code));
}

/** Classify a board "write"/"draw" payload into the right visual. */
function classifyBoardContent(content: string): BoardElement {
  const id = nextId();
  const trimmed = content.trim();
  const firstLine = trimmed.split('\n')[0].trim().toLowerCase();

  if (/^(graph|flowchart|sequencediagram|classdiagram|statediagram|erdiagram|pie|mindmap|timeline|journey)\b/.test(firstLine)) {
    return { id, kind: 'mermaid', source: trimmed };
  }
  if (/\\(frac|sum|int|theta|alpha|beta|sqrt|cdot|times|pi|infty|approx|le|ge|neq)|\^\{|_\{/.test(trimmed)) {
    return { id, kind: 'latex', latex: trimmed };
  }
  const codeSignals = /(def |function |=> |const |let |var |class |import |return |print\(|console\.|#include|public |;\s*$)/m;
  if (trimmed.includes('\n') && codeSignals.test(trimmed)) {
    return { id, kind: 'code', code: trimmed };
  }
  return { id, kind: 'chalk', text: trimmed };
}

/** Resolve an image query via Wikimedia Commons (free, keyless, CORS-open). */
async function resolveImage(query: string): Promise<{
  url: string;
  attribution: string;
  sourceUrl?: string;
} | null> {
  try {
    const params = new URLSearchParams({
      action: 'query',
      generator: 'search',
      gsrsearch: `filetype:bitmap ${query}`,
      gsrlimit: '1',
      gsrnamespace: '6',
      prop: 'imageinfo|info',
      inprop: 'url',
      iiprop: 'url|extmetadata',
      iiurlwidth: '760',
      format: 'json',
      origin: '*',
    });
    const res = await fetch(`https://commons.wikimedia.org/w/api.php?${params}`);
    const data = await res.json();
    const pages = data?.query?.pages;
    if (!pages) return null;
    const first = Object.values(pages)[0] as {
      title?: string;
      canonicalurl?: string;
      imageinfo?: { thumburl?: string; url?: string }[];
    };
    const info = first?.imageinfo?.[0];
    const url = info?.thumburl || info?.url;
    return url ? {
      url,
      attribution: first.title || 'Wikimedia Commons',
      sourceUrl: first.canonicalurl,
    } : null;
  } catch {
    return null;
  }
}

export const useClassroomStore = create<ClassroomStore>((set, get) => {
  // ── helpers ──

  const sfx = (sound: AmbientSound) => { if (get().soundOn) playSound(sound); };

  function speechCacheKey(text: string, language: string, rate: number) {
    return `${language}|${rate.toFixed(2)}|${text}`;
  }

  async function requestSpeechResponse(
    text: string,
    language: string,
    rate: number,
    signal?: AbortSignal,
  ): Promise<Response | null> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (authToken) headers.Authorization = `Bearer ${authToken}`;
    if (API_KEY) headers['X-API-Key'] = API_KEY;
    const response = await fetch(
      `${API_URL.replace(/\/$/, '')}/api/v1/tts/synthesize/stream`,
      {
        method: 'POST',
        headers,
        signal,
        body: JSON.stringify({
          text,
          voice: 'nova',
          format: 'mp3',
          speed: rate,
          content_type: 'explanation',
          language,
        }),
      },
    );
    if (!response.ok) return null;
    return response;
  }

  function prefetchSpeechLine(text: string) {
    if (!get().voiceOn || typeof window === 'undefined' || !text.trim()) return;
    const language = get().languageCode || 'auto';
    const rate = get().speechRate;
    const key = speechCacheKey(text, language, rate);
    prefetchedSpeech.prepare(key, (signal) => requestSpeechResponse(text, language, rate, signal));
  }

  function recordResponseLatency(phase: 'content' | 'audio') {
    if (learnerActionStarted === null || typeof performance === 'undefined') return;
    if (phase === 'content' && contentLatencyRecorded) return;
    if (phase === 'content') contentLatencyRecorded = true;
    const duration = performance.now() - learnerActionStarted;
    // Numeric timings only; no learner answers, topics, or identifiers.
    try {
      performance.clearMeasures(`classroom.action_to_${phase}`);
      performance.measure(`classroom.action_to_${phase}`, { start: learnerActionStarted, duration });
    } catch { /* Older browser timing APIs must never block the teacher. */ }
    if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('classroom:latency', {
      detail: { phase, durationMs: duration },
    }));
    if (phase === 'audio') learnerActionStarted = null;
  }

  function speakWithLocalizedDeviceVoice(
    text: string,
    language: string,
    generation: number,
    onDone: () => void,
  ) {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
      playTimer = setTimeout(onDone, speechDelay(text));
      return;
    }
    try {
      const utterance = new SpeechSynthesisUtterance(text);
      const detectedLanguage = detectSpeechLanguage(text);
      const resolvedLanguage = language === 'auto'
        ? (detectedLanguage || window.navigator.language || 'en-US')
        : language;
      utterance.lang = resolvedLanguage;
      const family = resolvedLanguage.split('-')[0].toLowerCase();
      utterance.voice = findVoiceForLanguage(family) ?? null;
      utterance.pitch = 1;
      utterance.rate = get().speechRate;
      let finished = false;
      const done = () => {
        if (!finished && generation === speechGeneration) {
          finished = true;
          onDone();
        }
      };
      utterance.onstart = () => recordResponseLatency('audio');
      utterance.onend = done;
      utterance.onerror = done;
      window.speechSynthesis.speak(utterance);
      playTimer = setTimeout(done, Math.max(speechDelay(text) * 1.8, 9000));
    } catch {
      playTimer = setTimeout(onDone, speechDelay(text));
    }
  }

  function speakLine(_speaker: string, text: string, onDone: () => void) {
    if (!get().voiceOn || typeof window === 'undefined') {
      playTimer = setTimeout(onDone, speechDelay(text));
      return;
    }

    const generation = ++speechGeneration;
    const language = get().languageCode || 'auto';
    const rate = get().speechRate;
    const prepared = prefetchedSpeech.take(speechCacheKey(text, language, rate));
    const controller = prepared?.controller || new AbortController();
    speechAbort = controller;
    const response = prepared?.response || requestSpeechResponse(text, language, rate, controller.signal);
    void playSpeechResponse(response, {
      signal: controller.signal,
      onStarted: () => { if (generation === speechGeneration) recordResponseLatency('audio'); },
    }).then(() => {
      if (generation === speechGeneration) onDone();
    }).catch((error: { playbackStarted?: boolean }) => {
      if (controller.signal.aborted || generation !== speechGeneration) return;
      // Never replay a partially spoken sentence after a network failure.
      if (error.playbackStarted) onDone();
      else speakWithLocalizedDeviceVoice(text, language, generation, onDone);
    }).finally(() => {
      controller.abort();
      if (speechAbort === controller) speechAbort = null;
    });
  }

  function pushTranscript(speaker: string, text: string) {
    set((s) => ({ transcript: [...s.transcript, { id: nextId(), speaker, text }] }));
  }

  /** The teacher erases the board only when the next scene's content is
      actually ready — not the moment generation starts, which left learners
      staring at an empty board for the whole LLM round-trip. */
  function maybeEraseForNewScene() {
    if (!pendingErase) return;
    pendingErase = false;
    eraseBoard();
  }

  function addBoardElement(el: BoardElement) {
    maybeEraseForNewScene();
    recordResponseLatency('content');
    sfx('chalk');
    waitingSince = null;
    stallNudged = false;
    set((s) => ({
      board: [...s.board, el], viewingBoard: -1, waitingForScene: false, stallPhase: 'none',
    }));
  }

  /** Wire the current spoken emphasis onto the board: mark the term inline
      in the most recent chalk block if it appears there — e.g. highlighting
      "3x" while the Teacher explains the coefficient — and always drop a
      circled "spotlight" element too, so highlighting still shows up even
      when the term lives inside a diagram/LaTeX block instead of plain
      chalk text. */
  function highlightBoardTerm(term: string) {
    set((s) => {
      const board = [...s.board];
      const lastChalkIndex = board.map((b) => b.kind).lastIndexOf('chalk');
      if (lastChalkIndex !== -1) {
        const el = board[lastChalkIndex];
        if (el.kind === 'chalk' && el.text.toLowerCase().includes(term.toLowerCase())) {
          board[lastChalkIndex] = { ...el, highlightedTerm: term };
        }
      }
      return { board };
    });
    // Auto-clear the inline mark after a few seconds — it reflects what's
    // being discussed right now, not a permanent decoration. A plain timer,
    // not `playTimer`, which drives turn sequencing and must not be
    // hijacked by an unrelated cleanup callback.
    setTimeout(() => {
      set((s) => ({
        board: s.board.map((b) => (
          b.kind === 'chalk' && b.highlightedTerm === term ? { ...b, highlightedTerm: undefined } : b
        )),
      }));
    }, 5000);
    addBoardElement({ id: nextId(), kind: 'highlight', term });
  }

  function addSources(labels?: string[]) {
    const clean = Array.from(
      new Set((labels ?? []).map((label) => label.trim()).filter(Boolean)),
    );
    if (!clean.length) return;
    const alreadyShown = get().board.some(
      (el) => el.kind === 'source' && clean.every((label) => el.labels.includes(label)),
    );
    if (!alreadyShown) addBoardElement({ id: nextId(), kind: 'source', labels: clean });
  }

  function eraseBoard() {
    const { board } = get();
    if (board.length === 0) return;
    set((s) => ({
      boardHistory: [...s.boardHistory, s.board],
      board: [],
      viewingBoard: -1,
    }));
  }

  // ── turn player ──

  function stopPlayer() {
    playing = false;
    if (playTimer) { clearTimeout(playTimer); playTimer = null; }
    stopSpeech();
    set({ isNarrating: false });
  }

  function learnerTakesFloor() {
    stopPlayer();
    turnQueue = [];
    prefetchedSpeech.clear();
    set({ lyoState: 'listening', caption: null, activeSpeaker: null, prompt: null, revealedCount: 0 });
  }

  function playNext() {
    if (!playing || get().isPaused) return;
    const turn = turnQueue.shift();
    if (!turn) {
      playing = false;
      set({ activeSpeaker: null, isNarrating: false });
      return;
    }

    switch (turn.type) {
      case 'speech': {
        const text = (turn.text ?? '').trim();
        if (text) {
          const speaker = turn.speaker || 'Teacher';
          set({ caption: { speaker, text }, activeSpeaker: speaker, revealedCount: 0 });
          pushTranscript(speaker, text);
          speakLine(speaker, text, playNext);
          return;
        }
        break;
      }

      case 'user_prompt': {
        const text = (turn.text ?? '').trim();
        const speaker = turn.speaker || 'Teacher';
        const promptId = nextId();
        // Never default to a generic yes/no pair — that's the exact bug
        // that made "can you give me an example?" show Yes/No buttons.
        // Only set `options` when the director actually sent real,
        // question-specific ones; otherwise the UI renders an open text
        // input instead.
        set({
          caption: { speaker, text },
          activeSpeaker: speaker,
          revealedCount: 0,
          prompt: {
            id: promptId, speaker, text,
            options: turn.options?.length ? turn.options : undefined,
          },
        });
        pushTranscript(speaker, `${text} (asks you)`);
        if (get().voiceOn) speakLine(speaker, text, () => undefined);
        playing = false;
        set({ isNarrating: false });
        // The learner owns this turn. There is intentionally no timer and no
        // AI classmate response while the real learner is silent.
        return;
      }

      case 'lyo_state':
        if (turn.state) set({ lyoState: turn.state });
        break;

      case 'board': {
        const action = turn.action ?? 'write';
        if (action === 'image' && (turn.query || turn.content)) {
          const query = (turn.query || turn.content || '').trim();
          const el: BoardElement = { id: nextId(), kind: 'image', url: null, caption: turn.caption, query };
          addBoardElement(el);
          void resolveImage(query).then((img) => {
            set((s) => ({
              board: img
                ? s.board.map((b) => (
                    b.id === el.id
                      ? { ...b, url: img.url, attribution: img.attribution, sourceUrl: img.sourceUrl }
                      : b
                  ))
                : s.board.filter((b) => b.id !== el.id), // nothing found — erase quietly
            }));
          });
          playTimer = setTimeout(playNext, boardTransitionDelay());
          return;
        }
        if (action === 'bullets' && turn.items?.length) {
          addBoardElement({ id: nextId(), kind: 'bullets', items: turn.items });
          playTimer = setTimeout(playNext, boardTransitionDelay());
          return;
        }
        if (action === 'chart' && turn.labels?.length && turn.values?.length) {
          addBoardElement({
            id: nextId(), kind: 'chart',
            chartType: turn.chart_type === 'line' ? 'line' : 'bar',
            labels: turn.labels, values: turn.values,
          });
          playTimer = setTimeout(playNext, boardTransitionDelay());
          return;
        }
        if (action === 'explorable' && turn.expression && turn.params?.length) {
          addBoardElement({
            id: nextId(), kind: 'explorable',
            expression: turn.expression, params: turn.params,
            xMin: turn.x_min, xMax: turn.x_max, prompt: turn.prompt,
          });
          playTimer = setTimeout(playNext, boardTransitionDelay());
          return;
        }
        if (action === 'highlight') {
          const term = (turn.content ?? '').trim();
          if (term) {
            highlightBoardTerm(term);
            playTimer = setTimeout(playNext, boardTransitionDelay());
            return;
          }
        }
        const content = (turn.content ?? '').trim();
        if (content) {
          addBoardElement(classifyBoardContent(content));
          playTimer = setTimeout(playNext, boardTransitionDelay());
          return;
        }
        break;
      }

      case 'ambient': {
        const sound = (turn.sound || turn.content || '') as AmbientSound;
        if (['bell', 'page_turn', 'chair_scrape', 'soft_laugh'].includes(sound)) sfx(sound);
        break;
      }

      case 'pause':
        playTimer = setTimeout(playNext, Math.min(turn.seconds ?? 1, 5) * 1000);
        return;

      case 'session_end':
        sfx('bell');
        addBoardElement({ id: nextId(), kind: 'dismissal', homework: turn.homework, nextHook: turn.next_hook });
        pushTranscript('Teacher', `🔔 Class dismissed. ${turn.homework ? `Homework: ${turn.homework}` : ''}`);
        set({
          lyoState: turn.lyo_state || 'celebrating',
          canContinue: true,
          // session_end has no CTAButton of its own. Reset the continuation
          // metadata so a prior action such as "Check understanding" cannot
          // become the label or intent for the dismissal button.
          continueLabel: 'Continue',
          nextActionIntent: 'continue',
          nextActionComponentId: 'web_continue',
          caption: null,
          activeSpeaker: null,
        });
        break;

      default:
        break;
    }
    playTimer = setTimeout(playNext, 80);
  }

  function resumePlayer() {
    if (playing) return;
    playing = true;
    set({ isNarrating: true });
    playNext();
  }

  function enqueueTurns(turns: DirectorTurn[]) {
    recordResponseLatency('content');
    // Start the next few voice requests immediately. While line one is
    // playing, lines two and three can finish synthesizing instead of making
    // the learner sit through a fresh network/provider round-trip at every
    // transition.
    turns
      .filter((turn) => (turn.type === 'speech' || turn.type === 'user_prompt') && (turn.text ?? '').trim())
      .slice(0, 3)
      .forEach((turn) => prefetchSpeechLine((turn.text ?? '').trim()));
    turnQueue.push(...turns);
    waitingSince = null;
    stallNudged = false;
    set({ waitingForScene: false, stallPhase: 'none' });
    resumePlayer();
  }

  // ── incoming protocol ──

  function handleComponent(comp: ClassroomComponent) {
    switch (comp.type) {
      case 'TeacherMessage': {
        const text = (comp.text ?? '').trim();
        if (!text) return;
        if (comp.language_code) set({ languageCode: comp.language_code });
        if (text.startsWith('[')) {
          try {
            const turns = JSON.parse(text) as DirectorTurn[];
            if (Array.isArray(turns)) {
              enqueueTurns(turns);
              addSources(comp.source_attributions);
              return;
            }
          } catch { /* plain text below */ }
        }
        enqueueTurns([{ type: 'speech', speaker: 'Teacher', text }]);
        addSources(comp.source_attributions);
        break;
      }
      case 'StudentPrompt':
        enqueueTurns([{ type: 'speech', speaker: comp.student_name || 'Maya', text: comp.text ?? '' }]);
        break;
      case 'QuizCard':
        addBoardElement({ id: nextId(), kind: 'quiz', quiz: comp });
        pushTranscript('Teacher', `📝 Check: ${comp.question ?? ''}`);
        set({ canContinue: false });
        break;
      case 'InputField':
        addBoardElement({ id: nextId(), kind: 'transfer', input: comp });
        pushTranscript('Teacher', `✍️ Application check: ${comp.question ?? ''}`);
        addSources(comp.source_attributions);
        set({ canContinue: false, waitingForScene: false });
        break;
      case 'ExampleBlock':
        addBoardElement({
          id: nextId(),
          kind: 'summary',
          title: comp.title || 'Worked example',
          content: comp.content,
          items: [],
        });
        break;
      case 'LessonBlock':
        if (comp.block_type === 'teaching_visual') {
          const visual = parseTeachingVisual(comp.block);
          if (visual) addBoardElement({ id: comp.component_id, kind: 'teaching_visual', visual });
        } else if (comp.block_type === 'summary' && comp.block) {
          addBoardElement({
            id: nextId(),
            kind: 'summary',
            title: comp.block.title || 'Lesson summary',
            content: comp.block.content,
            items: comp.block.items || [],
            retrievalScheduled: comp.block.retrieval_scheduled === true,
          });
          addSources(comp.block.source_attributions);
        }
        break;
      case 'ProgressBar': {
        const current = Math.max(0, comp.current ?? 0);
        const total = Math.max(1, comp.total ?? 1);
        set({ progressCurrent: current, progressTotal: total });
        // Keep this course's Stacks entry in sync with the backend's own
        // authoritative mastery-progress signal — non-blocking, mirrors
        // Android's ClassroomEngine.syncStackProgress. sessionId equals
        // the real course id once the classroom route passes a real
        // courseId (falls back to topic otherwise, same as upsert).
        void updateCourseProgress(get().courseId || get().sessionId, current / total);
        break;
      }
      case 'CTAButton':
        set({
          canContinue: true,
          continueLabel: comp.label || 'Continue',
          nextActionIntent: comp.action_intent || 'continue',
          nextActionComponentId: comp.component_id,
          waitingForScene: false,
        });
        break;
      default:
        break;
    }
  }

  function handleMessage(raw: string) {
    let msg: Record<string, unknown>;
    try { msg = JSON.parse(raw); } catch { return; }
    const et = (msg.event_type as string) || (msg.type as string) || '';

    switch (et) {
      case 'component_render': {
        const comp = (msg.component ?? (msg.data as Record<string, unknown>)?.component ?? msg.data) as ClassroomComponent | undefined;
        if (comp?.type) handleComponent(comp);
        break;
      }
      case 'scene_start':
      case 'SCENE_START':
      case 'scene_stream': {
        const start = classroomSceneStart(msg);
        set({ recordConcepts: conceptsFromClassScene(start?.scene) });
        // A new scene invalidates every older queued or playing turn.
        stopPlayer();
        prefetchedSpeech.clear();
        turnQueue = [];
        // Mark for erase, but keep the current board up while the teacher
        // "prepares" — it only wipes when the new content arrives.
        pendingErase = true;
        set({
          waitingForScene: true,
          canContinue: false,
          prompt: null,
          caption: null,
          activeSpeaker: null,
        });
        // Only the ad-hoc fast welcome carries its content exclusively in
        // the scene; the ordinary scene_start is followed by component_render.
        for (const component of start?.inlineComponents ?? []) {
          if (component?.type) handleComponent(component as ClassroomComponent);
        }
        break;
      }
      case 'scene_complete':
        set({ waitingForScene: false });
        break;
      case 'error': {
        // The classroom saying something went wrong is not the same as the
        // class being over, so this is a notice rather than a fatal error —
        // but it stops being invisible. It used to land in the transcript
        // drawer alone, where a learner watching a board that had stopped
        // moving would never find it.
        const message = (msg.message as string) || 'The classroom hit a snag.';
        pushTranscript('System', message);
        set({ notice: message });
        break;
      }
      default:
        break;
    }
  }

  /**
   * Returns whether the action actually reached the classroom. Callers must
   * check it before optimistically showing "waiting for the teacher" — a
   * silently dropped action used to leave the board spinning forever.
   */
  const activityUpdates = new Map<string, Record<string, unknown>>();
  let activityTimer: ReturnType<typeof setTimeout> | null = null;
  function flushActivities() {
    if (activityTimer) clearTimeout(activityTimer);
    activityTimer = null;
    const updates = Array.from(activityUpdates);
    activityUpdates.clear();
    for (const [id, values] of updates) {
      if (!sendAction('update_activity', id, values)) reportOffline();
    }
  }

  function sendAction(
    actionIntent: string,
    componentId: string,
    answerData?: Record<string, unknown>,
  ): boolean {
    if (actionIntent !== 'update_activity') flushActivities();
    if (!ws || ws.readyState !== WebSocket.OPEN) return false;
    const payload: Record<string, unknown> = {
      event_type: 'user_action',
      session_id: get().sessionId,
      action_intent: actionIntent,
      component_id: componentId,
      timestamp: new Date().toISOString(),
    };
    if (answerData) payload.answer_data = answerData;
    try {
      ws.send(JSON.stringify(payload));
      if (actionIntent !== 'update_activity') {
        learnerActionStarted = performance.now();
        contentLatencyRecorded = false;
      }
      return true;
    } catch {
      return false;
    }
  }

  /** Surfaces a dropped action instead of hanging the board. */
  function reportOffline() {
    stopStallWatch();
    set({
      waitingForScene: false,
      stallPhase: 'none',
      error: 'That did not reach the classroom — the session is not connected.',
    });
  }

  /**
   * One tick of the wait watchdog.
   *
   * A wait that is merely slow is said out loud and left alone. A wait that
   * passes the recovery threshold is asked after once, with `continue` — the
   * one intent that cannot be mistaken for a second answer — and only if that
   * second wait also runs out does the class admit the step is not coming and
   * put recovery controls in front of the learner.
   */
  function stallTick() {
    const { waitingForScene, status, isPaused, stallPhase } = get();
    if (!waitingForScene || status !== 'live' || isPaused) {
      waitingSince = null;
      stallNudged = false;
      if (stallPhase !== 'none') set({ stallPhase: 'none' });
      return;
    }
    const now = Date.now();
    if (waitingSince === null) {
      waitingSince = now;
      return;
    }
    const waited = now - waitingSince;
    if (waited >= CLASSROOM_STALL_RECOVERY_MS) {
      if (!stallNudged) {
        // One unprompted ask, then the learner decides. Resending the
        // learner's own answer here would risk grading it twice, so the
        // nudge is always `continue`.
        stallNudged = true;
        waitingSince = now;
        if (!sendAction('continue', get().nextActionComponentId || 'web_continue')) {
          set({ stallPhase: 'stalled' });
        } else if (stallPhase !== 'slow') {
          set({ stallPhase: 'slow' });
        }
        return;
      }
      if (stallPhase !== 'stalled') set({ stallPhase: 'stalled' });
      return;
    }
    if (waited >= CLASSROOM_STALL_NOTICE_MS && stallPhase === 'none') {
      set({ stallPhase: 'slow' });
    }
  }

  function startStallWatch() {
    stopStallWatch();
    stallTicker = setInterval(stallTick, STALL_TICK_MS);
  }

  return {
    status: 'idle',
    topic: '',
    sessionId: '',
    courseId: '',
    resumedSession: false,
    resumable: null,
    objective: '',
    languageCode: 'auto',
    board: [],
    boardHistory: [],
    recordConcepts: [],
    viewingBoard: -1,
    caption: null,
    activeSpeaker: null,
    prompt: null,
    transcript: [],
    lyoState: 'reading',
    waitingForScene: false,
    isNarrating: false,
    canContinue: false,
    progressCurrent: 0,
    progressTotal: 0,
    continueLabel: 'Check understanding',
    nextActionIntent: 'continue',
    nextActionComponentId: 'web_continue',
    error: null,
    notice: null,
    stallPhase: 'none',
    soundOn: false,
    revealedCount: 0,
    voiceOn: true,
    speechRate: 1,
    isPaused: false,

    connect: (connection: ClassroomConnection) => {
      get().disconnect();
      const token = typeof window !== 'undefined' ? localStorage.getItem('lyo_token') : null;
      if (!token) {
        set({
          status: 'error',
          error: 'Sign in to start a secure AI classroom.',
          waitingForScene: false,
        });
        return;
      }
      authToken = token;
      idCounter = 0;
      turnQueue = [];
      pendingErase = false;
      lastConnection = connection;

      // Which session this is. An explicitly-requested session id still wins
      // (a caller that already knows its session), otherwise the course
      // decides, and the course's history decides whether this is a new
      // class or the old one carried on.
      const courseKey = classroomCourseKey(connection);
      const saved = connection.resumeSession ?? readSavedSession(courseKey);
      const start = connection.sessionId
        ? { sessionId: connection.sessionId, generation: 1, resumed: false }
        : classroomSessionStart(courseKey, saved, { resume: connection.resume === true });
      const sessionId = start.sessionId;
      writeSavedSession(courseKey, {
        id: sessionId,
        startedAt: Date.now(),
        generation: start.generation,
      });

      // The cover page goes up before the socket does. A learner should
      // never be looking at a blank stage wondering whether the class has
      // begun, and after a resume they should be told that it is the middle
      // of one rather than left to infer it from the teacher's first line.
      const opening = classroomOpening({
        topic: connection.topic,
        objective: connection.objective,
        durationMinutes: connection.durationMinutes,
        difficulty: connection.difficulty,
        mode: connection.mode,
        resumed: start.resumed,
      });

      set({
        status: 'connecting',
        topic: connection.topic,
        sessionId,
        courseId: connection.courseId || '',
        resumedSession: start.resumed,
        // Offer the old seat back only when there is one worth offering and
        // this class is not already sitting in it.
        resumable: !start.resumed && canResumeClassroom(saved) ? saved : null,
        objective: connection.objective || '',
        languageCode: connection.language || 'auto',
        board: [{ id: nextId(), kind: 'opening', opening }],
        boardHistory: [], recordConcepts: [], viewingBoard: -1,
        caption: null, activeSpeaker: null, prompt: null, transcript: [],
        lyoState: 'reading', waitingForScene: true, isNarrating: false, canContinue: false,
        isPaused: false, progressCurrent: 0, progressTotal: 0,
        continueLabel: 'Continue', nextActionIntent: 'continue', nextActionComponentId: 'web_continue',
        error: null, notice: null, stallPhase: 'none',
      });
      startStallWatch();

      const socket = new WebSocket(wsUrl({ ...connection, sessionId }, token));
      ws = socket;
      socket.onopen = () => { if (ws === socket) set({ status: 'live' }); };
      socket.onmessage = (e) => { if (ws === socket) handleMessage(String(e.data)); };
      socket.onerror = () => {
        if (ws === socket) set({ status: 'error', error: 'Connection to the classroom failed.' });
      };
      socket.onclose = () => {
        if (ws === socket) {
          set((s) => ({ status: s.transcript.length > 0 ? 'ended' : s.status === 'error' ? 'error' : 'ended' }));
          ws = null;
        }
      };
    },

    disconnect: () => {
      flushActivities();
      stopPlayer();
      stopStallWatch();
      turnQueue = [];
      authToken = null;
      prefetchedSpeech.clear();
      learnerActionStarted = null;
      if (ws) { try { ws.close(); } catch { /* noop */ } ws = null; }
      set({ status: 'idle' });
    },

    answerPrompt: (option: string) => {
      const prompt = get().prompt;
      if (!prompt) return false;
      // Keep the prompt on screen if it could not be delivered, rather than
      // dismissing a question the classroom never received.
      if (!sendAction('user_message', prompt.id, { message: option })) {
        reportOffline();
        return false;
      }
      learnerTakesFloor();
      pushTranscript('You', option);
      set({ prompt: null, lyoState: 'listening', waitingForScene: true });
      return true;
    },

    answerQuiz: (elementId, option) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || el.kind !== 'quiz' || el.answered) return;
      learnerTakesFloor();
      // Do not lock the card to an answer the classroom never received.
      if (!sendAction('submit_answer', el.quiz.component_id, {
        selected_option_id: option.id,
        selected_option_label: option.label,
      })) {
        reportOffline();
        return;
      }
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && item.kind === 'quiz'
            ? { ...item, answered: option.label }
            : item),
        lyoState: 'thinking',
        waitingForScene: true,
      }));
      pushTranscript('You', option.label);
    },

    answerTransfer: (elementId: string, response: string) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || el.kind !== 'transfer' || el.submitted) return;
      const trimmed = response.trim();
      if (!trimmed) return;
      learnerTakesFloor();
      // Keep the learner's writing editable if it could not be delivered.
      if (!sendAction(el.input.action_intent || 'submit_transfer', el.input.component_id, {
        response: trimmed,
      })) {
        reportOffline();
        return;
      }
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && item.kind === 'transfer'
            ? { ...item, response: trimmed, submitted: true }
            : item),
        waitingForScene: true,
        lyoState: 'thinking',
      }));
      // Name the rung the component actually asked for. Labelling an
      // explanation prompt "Application" misreports the learner's own
      // transcript back to them.
      pushTranscript('You', `${transcriptLabelFor(el.input.evidence_type)}: ${trimmed}`);
    },

    skipQuestion: (elementId: string) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || (el.kind !== 'quiz' && el.kind !== 'transfer')) return;
      if ((el.kind === 'quiz' && el.answered) || (el.kind === 'transfer' && el.submitted) || el.skipped) return;

      learnerTakesFloor();
      const componentId = el.kind === 'quiz' ? el.quiz.component_id : el.input.component_id;
      if (!sendAction('skip_question', componentId, { reason: 'unsure' })) {
        reportOffline();
        return;
      }
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && (item.kind === 'quiz' || item.kind === 'transfer')
            ? { ...item, skipped: true }
            : item),
        canContinue: false,
        waitingForScene: true,
        lyoState: 'thinking',
      }));
      pushTranscript(
        'You',
        get().languageCode.toLowerCase().startsWith('es')
          ? 'Omití esta pregunta para repasarla después'
          : 'Skipped this question for later review',
      );
    },

    unskipQuestion: (elementId: string) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || (el.kind !== 'quiz' && el.kind !== 'transfer') || !el.skipped) return;

      learnerTakesFloor();
      const componentId = el.kind === 'quiz' ? el.quiz.component_id : el.input.component_id;
      if (!sendAction('retry', componentId)) {
        reportOffline();
        return;
      }
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && (item.kind === 'quiz' || item.kind === 'transfer')
            ? { ...item, skipped: false }
            : item),
        waitingForScene: true,
        lyoState: 'thinking',
      }));
      pushTranscript(
        'You',
        get().languageCode.toLowerCase().startsWith('es')
          ? 'Volví a la pregunta omitida'
          : 'Returned to the skipped question',
      );
    },

    askQuestion: (text: string) => {
      const trimmed = text.trim();
      if (!trimmed) return;
      learnerTakesFloor();
      if (!sendAction('ask_question', 'web_ask', { message: trimmed })) {
        reportOffline();
        return;
      }
      pushTranscript('You', `✋ ${trimmed}`);
      // The learner's own line is not spoken by anyone, so it is shown whole
      // rather than paced — there is no audio for a pacer to follow.
      set({
        waitingForScene: true,
        lyoState: 'curious',
        caption: { speaker: 'You', text: trimmed },
        revealedCount: trimmed.split(/\s+/).filter(Boolean).length,
      });
    },

    takeFloor: () => learnerTakesFloor(),

    interruptPrompt: () => {
      // The learner can start speaking or typing before the question finishes.
      // Stop its audio, while keeping the prompt available for submission.
      if (!get().prompt) return;
      stopSpeech();
      set({ caption: null, activeSpeaker: null, revealedCount: 0 });
    },

    signal: (kind) => {
      learnerTakesFloor();
      if (!sendAction(kind === 'confused' ? 'request_hint' : 'skip_ahead', 'web_signal',
        kind === 'confused' ? { hint_level: 'nudge' } : undefined)) {
        reportOffline();
        return;
      }
      set({ waitingForScene: true, lyoState: kind === 'confused' ? 'thinking' : 'curious' });
      pushTranscript('You', kind === 'confused' ? 'Requested a small nudge' : 'Requested a harder case');
    },

    requestHint: (level) => {
      const labels: Record<HintLevel, string> = {
        nudge: 'small nudge',
        principle: 'governing principle',
        worked_step: 'first worked step',
        full_example: 'full worked example',
        prerequisite: 'prerequisite refresher',
      };
      learnerTakesFloor();
      if (!sendAction('request_hint', 'web_hint', { hint_level: level })) {
        reportOffline();
        return;
      }
      set({ waitingForScene: true, lyoState: 'thinking' });
      pushTranscript('You', `Requested: ${labels[level]}`);
    },

    updateActivity: (id, values) => {
      if (!ws || ws.readyState !== WebSocket.OPEN) { reportOffline(); return false; }
      if (!get().board.some(el => el.id === id && el.kind === 'teaching_visual')) return false;
      set(state => ({ board: state.board.map(el => {
        if (el.id !== id || el.kind !== 'teaching_visual') return el;
        const params = values.params as Record<string, number> | undefined;
        const visual = parseTeachingVisual(params
          ? { ...el.visual, params: el.visual.params.map(p => ({ ...p, initial: params[p.name] })) }
          : { ...el.visual, value: values.value });
        return visual ? { ...el, visual } : el;
      }) }));
      activityUpdates.set(id, values);
      if (activityTimer) clearTimeout(activityTimer);
      activityTimer = setTimeout(flushActivities, 200);
      return true;
    },

    continueLesson: () => {
      const actionIntent = get().nextActionIntent || 'continue';
      learnerTakesFloor();
      // Leave the Continue button in place if the action never left the
      // browser — clearing canContinue would strip the only way forward.
      if (!sendAction(actionIntent, get().nextActionComponentId || 'web_continue')) {
        reportOffline();
        return;
      }
      set({
        canContinue: false,
        waitingForScene: true,
        continueLabel: 'Check understanding',
        nextActionIntent: 'continue',
      });
    },

    /**
     * The step did not come; ask for it again.
     *
     * Always `continue`, never the learner's own submission replayed. A
     * resent answer is a second answer as far as the grader is concerned,
     * and a learner who waited out a slow network must not pay for it with
     * a duplicate attempt on their record.
     */
    nudgeTeacher: () => {
      if (!sendAction('continue', get().nextActionComponentId || 'web_continue')) {
        reportOffline();
        return;
      }
      waitingSince = Date.now();
      stallNudged = true;
      set({ waitingForScene: true, stallPhase: 'slow', notice: null, lyoState: 'thinking' });
    },

    /**
     * Leave a stuck session behind.
     *
     * The server holds the learner's place inside the session, so a session
     * that cannot produce its next step cannot be argued out of it — the
     * only real recovery is a different session. Evidence already earned is
     * filed against the concept, not the session, so nothing demonstrated is
     * lost by starting the teaching again.
     */
    restartLesson: () => {
      const connection = lastConnection;
      if (!connection) return;
      get().disconnect();
      get().connect({
        ...connection, sessionId: undefined, resume: false, resumeSession: undefined,
      });
    },

    resumeLesson: () => {
      const connection = lastConnection;
      const saved = get().resumable;
      if (!connection || !saved) return;
      get().disconnect();
      get().connect({
        ...connection, sessionId: undefined, resume: true, resumeSession: saved,
      });
    },

    dismissNotice: () => set({ notice: null }),

    skipTurn: () => {
      // Nothing playing to cut short: idle, paused, or the learner already
      // owns the floor (a prompt/quiz/transfer is waiting on them — those
      // are answered or explicitly skipped, never fast-forwarded past).
      if (!playing || get().isPaused) return;
      if (playTimer) { clearTimeout(playTimer); playTimer = null; }
      // Bumps speechGeneration, so a real TTS request or utterance already
      // in flight for the turn being skipped becomes a no-op instead of
      // firing its onDone (which would otherwise double-advance the queue).
      stopSpeech();
      // Clear the caption/speaker being cut short rather than leaving it in
      // place. Without this, skipping into a board/pause/ambient turn (none
      // of which touch `caption`) left the old line's word-reveal ticker
      // running on the UI side, still typing out content the learner had
      // just jumped past. If the next turn is itself a speech turn it sets
      // its own fresh caption right away, so this only ever shows a blank
      // beat, never a wrong one.
      set({ caption: null, activeSpeaker: null });
      playNext();
    },

    toggleSound: () => set((s) => ({ soundOn: !s.soundOn })),
    toggleVoice: () => {
      const next = !get().voiceOn;
      set({ voiceOn: next });
      if (!next) {
        prefetchedSpeech.clear();
        if (playTimer) { clearTimeout(playTimer); playTimer = null; }
        stopSpeech();
        if (playing) playNext();
      }
    },
    // The single most accessible control: stop the class right where it
    // is. Pausing cancels the turn currently speaking/animating and holds
    // the turn queue — it does not lose anything already on the board or
    // in the transcript. Resuming continues with the NEXT turn (the
    // interrupted line doesn't replay from the top; browser TTS
    // pause/resume-mid-utterance is unreliable enough across engines that
    // a clean stop-and-continue is the more trustworthy behavior).
    togglePause: () => {
      if (get().isPaused) {
        set({ isPaused: false });
        resumePlayer();
      } else {
        stopPlayer();
        set({ isPaused: true, activeSpeaker: null });
      }
    },
    setSpeechRate: (rate: number) => set({
      speechRate: Math.max(0.75, Math.min(1.25, rate)),
    }),

    setRevealedCount: (count: number) => set({ revealedCount: Math.max(0, count) }),

    viewBoard: (index: number) => set({ viewingBoard: index }),
  };
});
