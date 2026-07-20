'use client';

import { create } from 'zustand';
import { playSound, type AmbientSound } from '@/lib/classroom-sounds';
import { buildClassroomWsUrl } from '@/lib/classroom-contract.mjs';
import type {
  ClassroomContractConnection,
  ClassroomMode,
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
  evidence_type?: string;
  source_attributions?: string[];
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
  | { id: string; kind: 'chalk'; text: string }
  | { id: string; kind: 'latex'; latex: string }
  | { id: string; kind: 'mermaid'; source: string }
  | { id: string; kind: 'code'; code: string }
  | { id: string; kind: 'image'; url: string | null; caption?: string; query: string; attribution?: string; sourceUrl?: string }
  | { id: string; kind: 'bullets'; items: string[] }
  | { id: string; kind: 'chart'; chartType: 'bar' | 'line'; labels: string[]; values: number[] }
  | { id: string; kind: 'explorable'; expression: string; params: { name: string; min: number; max: number; initial: number; step?: number }[]; xMin?: number; xMax?: number; prompt?: string }
  | { id: string; kind: 'quiz'; quiz: ClassroomComponent; answered?: string; wasCorrect?: boolean; feedback?: string }
  | { id: string; kind: 'transfer'; input: ClassroomComponent; response?: string; submitted?: boolean }
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
  options: string[];
}

export interface Caption {
  speaker: string;
  text: string;
}

type Status = 'idle' | 'connecting' | 'live' | 'ended' | 'error';

export interface ClassroomConnection extends ClassroomContractConnection {
  mode?: ClassroomMode;
}

interface ClassroomStore {
  status: Status;
  topic: string;
  sessionId: string;
  objective: string;

  board: BoardElement[];        // the live board
  boardHistory: BoardElement[][]; // erased boards (flip back through)
  viewingBoard: number;         // -1 = live, else history index

  caption: Caption | null;      // the line being spoken right now
  activeSpeaker: string | null; // who is talking (lights up in the cast row)
  prompt: ActivePrompt | null;  // cold-call awaiting the learner
  transcript: TranscriptItem[]; // full log — the drawer, the byproduct

  lyoState: string;
  waitingForScene: boolean;
  canContinue: boolean;
  progressCurrent: number;
  progressTotal: number;
  continueLabel: string;
  nextActionIntent: string;
  error: string | null;

  soundOn: boolean;
  voiceOn: boolean;
  speechRate: number;

  connect: (connection: ClassroomConnection) => void;
  disconnect: () => void;
  answerPrompt: (option: string) => void;
  answerQuiz: (elementId: string, option: QuizOption) => void;
  answerTransfer: (elementId: string, response: string) => void;
  askQuestion: (text: string) => void;
  signal: (kind: 'confused' | 'too_easy') => void;
  requestHint: (level: HintLevel) => void;
  continueLesson: () => void;
  toggleSound: () => void;
  toggleVoice: () => void;
  setSpeechRate: (rate: number) => void;
  viewBoard: (index: number) => void; // -1 = live
}

// ─── Internals ───────────────────────────────────────────────────────────────

let ws: WebSocket | null = null;
let turnQueue: DirectorTurn[] = [];
let playing = false;
let playTimer: ReturnType<typeof setTimeout> | null = null;
let idCounter = 0;
let pendingErase = false; // erase lazily when the NEW scene's content arrives
const nextId = () => `cf_${++idCounter}`;

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoapp.com';

function wsUrl(connection: ClassroomConnection, token: string | null): string {
  return buildClassroomWsUrl(API_URL, connection, token);
}

function speechDelay(text: string): number {
  return Math.min(Math.max(text.length * 34, 1400), 7000);
}

// Distinct voices for the cast (browser SpeechSynthesis).
const VOICE_PROFILE: Record<string, { pitch: number; rate: number }> = {
  Teacher: { pitch: 0.92, rate: 1.0 },
  Maya: { pitch: 1.2, rate: 1.05 },
  Sam: { pitch: 1.0, rate: 1.12 },
  Rio: { pitch: 1.15, rate: 1.1 },
  Zack: { pitch: 0.85, rate: 0.95 },
  Lyo: { pitch: 1.35, rate: 1.05 },
};

function stopSpeech() {
  if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
    window.speechSynthesis.cancel();
  }
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

  function speakLine(speaker: string, text: string, onDone: () => void) {
    if (!get().voiceOn || typeof window === 'undefined' || !('speechSynthesis' in window)) {
      playTimer = setTimeout(onDone, speechDelay(text));
      return;
    }
    try {
      const utterance = new SpeechSynthesisUtterance(text);
      const profile = VOICE_PROFILE[speaker] ?? VOICE_PROFILE.Teacher;
      utterance.pitch = profile.pitch;
      utterance.rate = profile.rate * get().speechRate;
      let finished = false;
      const done = () => { if (!finished) { finished = true; onDone(); } };
      utterance.onend = done;
      utterance.onerror = done;
      window.speechSynthesis.speak(utterance);
      // Safety net: some browsers drop onend.
      playTimer = setTimeout(done, Math.max(speechDelay(text) * 1.8, 9000));
    } catch {
      playTimer = setTimeout(onDone, speechDelay(text));
    }
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
    sfx('chalk');
    set((s) => ({ board: [...s.board, el], viewingBoard: -1, waitingForScene: false }));
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
  }

  function playNext() {
    if (!playing) return;
    const turn = turnQueue.shift();
    if (!turn) {
      playing = false;
      set({ activeSpeaker: null });
      return;
    }

    switch (turn.type) {
      case 'speech': {
        const text = (turn.text ?? '').trim();
        if (text) {
          const speaker = turn.speaker || 'Teacher';
          set({ caption: { speaker, text }, activeSpeaker: speaker });
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
        set({
          caption: { speaker, text },
          activeSpeaker: speaker,
          prompt: { id: promptId, speaker, text, options: turn.options?.length ? turn.options : ['Yes', 'No'] },
        });
        pushTranscript(speaker, `${text} (asks you)`);
        if (get().voiceOn) speakLine(speaker, text, () => undefined);
        playing = false;
        const beat = (turn.beat_seconds ?? 5) + 8;
        playTimer = setTimeout(() => {
          if (get().prompt?.id === promptId) {
            set({ prompt: null });
            resumePlayer(); // a classmate jumps in, per the director's script
          }
        }, beat * 1000);
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
          playTimer = setTimeout(playNext, 1800);
          return;
        }
        if (action === 'bullets' && turn.items?.length) {
          addBoardElement({ id: nextId(), kind: 'bullets', items: turn.items });
          playTimer = setTimeout(playNext, Math.min(turn.items.length * 700 + 800, 4200));
          return;
        }
        if (action === 'chart' && turn.labels?.length && turn.values?.length) {
          addBoardElement({
            id: nextId(), kind: 'chart',
            chartType: turn.chart_type === 'line' ? 'line' : 'bar',
            labels: turn.labels, values: turn.values,
          });
          playTimer = setTimeout(playNext, 2400);
          return;
        }
        if (action === 'explorable' && turn.expression && turn.params?.length) {
          addBoardElement({
            id: nextId(), kind: 'explorable',
            expression: turn.expression, params: turn.params,
            xMin: turn.x_min, xMax: turn.x_max, prompt: turn.prompt,
          });
          playTimer = setTimeout(playNext, 2000);
          return;
        }
        const content = (turn.content ?? '').trim();
        if (content) {
          addBoardElement(classifyBoardContent(content));
          playTimer = setTimeout(playNext, 2400);
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
    playNext();
  }

  function enqueueTurns(turns: DirectorTurn[]) {
    maybeEraseForNewScene();
    turnQueue.push(...turns);
    set({ waitingForScene: false });
    resumePlayer();
  }

  // ── incoming protocol ──

  function handleComponent(comp: ClassroomComponent) {
    switch (comp.type) {
      case 'TeacherMessage': {
        const text = (comp.text ?? '').trim();
        if (!text) return;
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
        pushTranscript('Teacher', `📝 Recognition check: ${comp.question ?? ''}`);
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
        if (comp.block_type === 'summary' && comp.block) {
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
      case 'ProgressBar':
        set({
          progressCurrent: Math.max(0, comp.current ?? 0),
          progressTotal: Math.max(1, comp.total ?? 1),
        });
        break;
      case 'CTAButton':
        set({
          canContinue: true,
          continueLabel: comp.label || 'Continue',
          nextActionIntent: comp.action_intent || 'continue',
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
        // Mark for erase, but keep the current board up while the teacher
        // "prepares" — it only wipes when the new content arrives.
        pendingErase = true;
        set({ waitingForScene: true, canContinue: false });
        break;
      case 'scene_complete':
        set({ waitingForScene: false });
        break;
      case 'error':
        pushTranscript('System', (msg.message as string) || 'The classroom hit a snag.');
        break;
      default:
        break;
    }
  }

  function sendAction(actionIntent: string, componentId: string, answerData?: Record<string, unknown>) {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    const payload: Record<string, unknown> = {
      event_type: 'user_action',
      session_id: get().sessionId,
      action_intent: actionIntent,
      component_id: componentId,
      timestamp: new Date().toISOString(),
    };
    if (answerData) payload.answer_data = answerData;
    ws.send(JSON.stringify(payload));
  }

  return {
    status: 'idle',
    topic: '',
    sessionId: '',
    objective: '',
    board: [],
    boardHistory: [],
    viewingBoard: -1,
    caption: null,
    activeSpeaker: null,
    prompt: null,
    transcript: [],
    lyoState: 'reading',
    waitingForScene: false,
    canContinue: false,
    progressCurrent: 0,
    progressTotal: 1,
    continueLabel: 'Check understanding',
    nextActionIntent: 'continue',
    error: null,
    soundOn: false,
    voiceOn: false,
    speechRate: 1,

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
      idCounter = 0;
      turnQueue = [];
      pendingErase = false;
      const sessionId = connection.sessionId || connection.topic;
      set({
        status: 'connecting',
        topic: connection.topic,
        sessionId,
        objective: connection.objective || '',
        board: [], boardHistory: [], viewingBoard: -1,
        caption: null, activeSpeaker: null, prompt: null, transcript: [],
        lyoState: 'reading', waitingForScene: true, canContinue: false,
        progressCurrent: 0, progressTotal: 1,
        continueLabel: 'Check understanding', nextActionIntent: 'continue', error: null,
      });

      const socket = new WebSocket(wsUrl({ ...connection, sessionId }, token));
      ws = socket;
      socket.onopen = () => set({ status: 'live' });
      socket.onmessage = (e) => handleMessage(String(e.data));
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
      stopPlayer();
      turnQueue = [];
      if (ws) { try { ws.close(); } catch { /* noop */ } ws = null; }
      set({ status: 'idle' });
    },

    answerPrompt: (option: string) => {
      const prompt = get().prompt;
      if (!prompt) return;
      pushTranscript('You', option);
      set({ prompt: null, lyoState: 'listening' });
      sendAction('user_message', prompt.id, { message: option });
      resumePlayer();
    },

    answerQuiz: (elementId, option) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || el.kind !== 'quiz' || el.answered) return;
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && item.kind === 'quiz'
            ? { ...item, answered: option.label }
            : item),
        lyoState: 'thinking',
        waitingForScene: true,
      }));
      pushTranscript('You', option.label);
      sendAction('submit_answer', el.quiz.component_id, {
        selected_option_id: option.id,
        selected_option_label: option.label,
      });
    },

    answerTransfer: (elementId: string, response: string) => {
      const el = get().board.find((b) => b.id === elementId);
      if (!el || el.kind !== 'transfer' || el.submitted) return;
      const trimmed = response.trim();
      if (!trimmed) return;
      set((state) => ({
        board: state.board.map((item) =>
          item.id === elementId && item.kind === 'transfer'
            ? { ...item, response: trimmed, submitted: true }
            : item),
        waitingForScene: true,
        lyoState: 'thinking',
      }));
      pushTranscript('You', `Application: ${trimmed}`);
      sendAction(el.input.action_intent || 'submit_transfer', el.input.component_id, {
        response: trimmed,
      });
    },

    askQuestion: (text: string) => {
      const trimmed = text.trim();
      if (!trimmed) return;
      stopSpeech(); // barge-in: you raised your hand, the room listens
      pushTranscript('You', `✋ ${trimmed}`);
      set({ waitingForScene: true, lyoState: 'curious', caption: { speaker: 'You', text: trimmed } });
      sendAction('ask_question', 'web_ask', { message: trimmed });
    },

    signal: (kind) => {
      set({ waitingForScene: true, lyoState: kind === 'confused' ? 'thinking' : 'curious' });
      pushTranscript('You', kind === 'confused' ? 'Requested a small nudge' : 'Requested a harder case');
      sendAction(kind === 'confused' ? 'request_hint' : 'skip_ahead', 'web_signal',
        kind === 'confused' ? { hint_level: 'nudge' } : undefined);
    },

    requestHint: (level) => {
      const labels: Record<HintLevel, string> = {
        nudge: 'small nudge',
        principle: 'governing principle',
        worked_step: 'first worked step',
        full_example: 'full worked example',
        prerequisite: 'prerequisite refresher',
      };
      set({ waitingForScene: true, lyoState: 'thinking' });
      pushTranscript('You', `Requested: ${labels[level]}`);
      sendAction('request_hint', 'web_hint', { hint_level: level });
    },

    continueLesson: () => {
      const actionIntent = get().nextActionIntent || 'continue';
      set({
        canContinue: false,
        waitingForScene: true,
        continueLabel: 'Check understanding',
        nextActionIntent: 'continue',
      });
      sendAction(actionIntent, 'web_continue');
    },

    toggleSound: () => set((s) => ({ soundOn: !s.soundOn })),
    toggleVoice: () => {
      const next = !get().voiceOn;
      if (!next) stopSpeech();
      set({ voiceOn: next });
    },
    setSpeechRate: (rate: number) => set({
      speechRate: Math.max(0.75, Math.min(1.25, rate)),
    }),

    viewBoard: (index: number) => set({ viewingBoard: index }),
  };
});
